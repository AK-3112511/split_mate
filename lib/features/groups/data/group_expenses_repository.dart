import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/settlement.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/firestore_helper.dart';
import '../../../core/utils/image_codec.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/write_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../notifications/domain/notification_model.dart';
import '../../receipts/data/receipts_repository.dart';
import '../domain/group_activity_model.dart';
import '../domain/group_expense_model.dart';
import '../domain/group_model.dart';
import 'group_mirror_service.dart';

/// Real (non-template, non-deleted) expenses and payments, newest first.
final groupExpensesStreamProvider =
    StreamProvider.autoDispose.family<List<GroupExpenseModel>, String>((ref, groupId) {
  if (ref.watch(currentUidProvider) == null) return Stream.value(const []);
  return ref.watch(groupExpensesRepositoryProvider).streamExpenses(groupId);
});

/// Recurring templates (including paused ones).
final groupTemplatesStreamProvider =
    StreamProvider.autoDispose.family<List<GroupExpenseModel>, String>((ref, groupId) {
  if (ref.watch(currentUidProvider) == null) return Stream.value(const []);
  return ref.watch(groupExpensesRepositoryProvider).streamTemplates(groupId);
});

final groupActivityStreamProvider =
    StreamProvider.autoDispose.family<List<GroupActivityModel>, String>((ref, groupId) {
  if (ref.watch(currentUidProvider) == null) return Stream.value(const []);
  return ref.watch(groupExpensesRepositoryProvider).streamActivity(groupId);
});

final groupExpensesRepositoryProvider = Provider<GroupExpensesRepository>((ref) {
  return GroupExpensesRepository(
    ref.watch(firestoreProvider),
    ref.watch(currentUidProvider),
    ref.watch(notificationsRepositoryProvider),
    ref.watch(receiptsRepositoryProvider),
    ref.watch(mirrorServiceProvider),
  );
});

class GroupExpensesRepository {
  final FirebaseFirestore _db;
  final String? _uid;
  final NotificationsRepository _notify;
  final ReceiptsRepository _receipts;
  final MirrorService _mirrors;

  GroupExpensesRepository(this._db, this._uid, this._notify, this._receipts, this._mirrors);

  String get _me {
    final uid = _uid;
    if (uid == null) throw const AppException('Please sign in again.');
    return uid;
  }

  String get _myName => _notify.senderName;

  CollectionReference<Map<String, dynamic>> _expenses(String groupId) =>
      _db.collection('groups').doc(groupId).collection('expenses');

  void _activity(WriteBatch batch, String groupId, String type, String message, {String? expenseId}) {
    batch.set(_db.collection('groups').doc(groupId).collection('activity').doc(), {
      'type': type,
      'actorUid': _me,
      'expenseId': expenseId,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<List<GroupExpenseModel>> streamExpenses(String groupId) {
    return retryOnPermissionDenied(() => _expenses(groupId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => GroupExpenseModel.fromMap(d.data(), d.id))
              .where((e) => !e.isRecurringTemplate)
              .toList();
          list.sort((a, b) {
            final byDate = b.date.compareTo(a.date);
            return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
          });
          return list;
        }));
  }

  Stream<List<GroupExpenseModel>> streamTemplates(String groupId) {
    return retryOnPermissionDenied(() => _expenses(groupId)
        .where('isRecurringTemplate', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => GroupExpenseModel.fromMap(d.data(), d.id))
            .where((e) => !e.isDeleted)
            .toList()));
  }

  Stream<List<GroupActivityModel>> streamActivity(String groupId) {
    return retryOnPermissionDenied(() => _db
        .collection('groups')
        .doc(groupId)
        .collection('activity')
        .orderBy('createdAt', descending: true)
        .limit(150)
        .snapshots()
        .map((s) => s.docs.map((d) => GroupActivityModel.fromMap(d.data(), d.id)).toList()));
  }

  String newExpenseId(String groupId) => _expenses(groupId).doc().id;

  // ── Expenses ──────────────────────────────────────────────────────────────

  Future<WriteOutcome> addExpense({
    required GroupModel group,
    required GroupExpenseModel expense,
    EncodedImage? receipt,
  }) async {
    final batch = _db.batch();
    String? receiptId;
    if (receipt != null) {
      receiptId = _receipts.stage(batch, receipt, groupId: group.groupId, expenseId: expense.expenseId);
    }
    final data = expense.toMap()
      ..['receiptId'] = receiptId
      ..['createdBy'] = _me;
    if (expense.isRecurringTemplate) data['recurrenceVersion'] = 2;
    batch.set(_expenses(group.groupId).doc(expense.expenseId), data);
    if (!expense.isRecurringTemplate) {
      _activity(batch, group.groupId, GroupActivityModel.expenseAdded,
          '$_myName added "${expense.description}" · ${Money.format(expense.amount)}',
          expenseId: expense.expenseId);
    }
    final outcome = await commitWithTimeout(batch.commit());
    if (!expense.isRecurringTemplate) {
      runInBackground(() async {
        await _mirrors.syncOne(group.groupId, group.name, expense);
        await _notify.send(
          recipients: group.members,
          type: NotificationModel.expenseAdded,
          message: '$_myName added "${expense.description}" (${Money.format(expense.amount)}) in ${group.name}',
          groupId: group.groupId,
          groupName: group.name,
          expenseId: expense.expenseId,
          amount: expense.amount,
        );
      }, label: 'expense added side effects');
    }
    return outcome;
  }

  /// Replaces the whole document (so removed members' old shares can't linger,
  /// unlike v1's merge) while keeping identity fields from [previous].
  Future<WriteOutcome> updateExpense({
    required GroupModel group,
    required GroupExpenseModel previous,
    required GroupExpenseModel updated,
    EncodedImage? newReceipt,
    bool removeReceipt = false,
  }) async {
    final batch = _db.batch();
    var receiptId = previous.receiptId;
    if (newReceipt != null || removeReceipt) {
      if (previous.receiptId != null) {
        batch.delete(_receipts.collection(groupId: group.groupId).doc(previous.receiptId));
      }
      receiptId = newReceipt == null
          ? null
          : _receipts.stage(batch, newReceipt, groupId: group.groupId, expenseId: previous.expenseId);
    }
    final data = updated.toMap()
      ..['receiptId'] = receiptId
      ..['createdAt'] = Timestamp.fromDate(previous.createdAt)
      ..['createdBy'] = previous.createdBy ?? _me
      ..['isRecurringTemplate'] = previous.isRecurringTemplate
      ..['generatedFromTemplateId'] = previous.generatedFromTemplateId
      ..['lastGeneratedDate'] =
          previous.lastGeneratedDate != null ? Timestamp.fromDate(previous.lastGeneratedDate!) : null
      ..['isCancelled'] = previous.isCancelled;
    if (previous.isRecurringTemplate) data['recurrenceVersion'] = 2;
    if (newReceipt == null && !removeReceipt && previous.legacyReceipt != null) {
      data['receiptUrl'] = previous.legacyReceipt;
    }
    batch.set(_expenses(group.groupId).doc(previous.expenseId), data);

    final changes = describeChanges(previous, updated);
    if (!previous.isRecurringTemplate) {
      _activity(
        batch,
        group.groupId,
        GroupActivityModel.expenseEdited,
        changes.isEmpty
            ? '$_myName updated "${updated.description}"'
            : '$_myName updated "${updated.description}": ${changes.join(', ')}',
        expenseId: previous.expenseId,
      );
    }
    final outcome = await commitWithTimeout(batch.commit());
    if (!previous.isRecurringTemplate) {
      runInBackground(() async {
        await _mirrors.syncOne(group.groupId, group.name, updated);
        await _notify.send(
          recipients: {...group.members.where((m) => previous.involves(m) || updated.involves(m))},
          type: NotificationModel.expenseEdited,
          message: '$_myName edited "${updated.description}" in ${group.name}',
          groupId: group.groupId,
          groupName: group.name,
          expenseId: previous.expenseId,
          amount: updated.amount,
        );
      }, label: 'expense edited side effects');
    }
    return outcome;
  }

  static List<String> describeChanges(GroupExpenseModel a, GroupExpenseModel b) {
    final out = <String>[];
    if (!Money.equals(a.amount, b.amount)) {
      out.add('amount ${Money.format(a.amount)} → ${Money.format(b.amount)}');
    }
    if (a.description.trim() != b.description.trim()) out.add('renamed from "${a.description.trim()}"');
    if (a.category.trim().toLowerCase() != b.category.trim().toLowerCase()) {
      out.add('category ${a.category} → ${b.category}');
    }
    if (a.payerUid != b.payerUid) out.add('payer changed');
    final aShares = a.shareByUid.map((k, v) => MapEntry(k, Money.toPaise(v)));
    final bShares = b.shareByUid.map((k, v) => MapEntry(k, Money.toPaise(v)));
    final sameSplit = aShares.length == bShares.length &&
        aShares.entries.every((e) => bShares[e.key] == e.value);
    if (!sameSplit) out.add('split changed');
    if (a.date.year != b.date.year || a.date.month != b.date.month || a.date.day != b.date.day) {
      out.add('date changed');
    }
    return out;
  }

  Future<WriteOutcome> deleteExpense({
    required GroupModel group,
    required GroupExpenseModel expense,
  }) async {
    final batch = _db.batch();
    batch.update(_expenses(group.groupId).doc(expense.expenseId), {
      'isDeleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final label = expense.isPayment ? 'a payment of ${Money.format(expense.amount)}' : '"${expense.description}"';
    _activity(batch, group.groupId, GroupActivityModel.expenseDeleted, '$_myName deleted $label',
        expenseId: expense.expenseId);
    final outcome = await commitWithTimeout(batch.commit());
    runInBackground(() async {
      final deleted = GroupExpenseModel.fromMap({...expense.toMap(), 'isDeleted': true}, expense.expenseId);
      await _mirrors.syncOne(group.groupId, group.name, deleted);
      await _notify.send(
        recipients: group.members.where(expense.involves),
        type: NotificationModel.expenseDeleted,
        message: '$_myName deleted $label in ${group.name}',
        groupId: group.groupId,
        groupName: group.name,
        expenseId: expense.expenseId,
        amount: expense.amount,
      );
    }, label: 'expense deleted side effects');
    return outcome;
  }

  // ── Payments ──────────────────────────────────────────────────────────────

  /// Records [fromUid] paying [toUid] in one atomic batch. When this brings the
  /// pair's direct balance to zero, every unsettled split *between exactly
  /// these two people* is marked settled in the same batch (spec §12).
  Future<WriteOutcome> recordPayment({
    required GroupModel group,
    required String fromUid,
    required String toUid,
    required double amount,
    required List<GroupExpenseModel> currentExpenses,
    required String fromName,
    required String toName,
  }) async {
    final paise = Money.toPaise(amount);
    if (paise <= 0) throw const AppException('Enter an amount more than ₹0.');
    if (fromUid == toUid) throw const AppException('Pick two different people.');

    final ref = _expenses(group.groupId).doc();
    final now = DateTime.now();
    final payment = GroupExpenseModel(
      expenseId: ref.id,
      type: GroupExpenseModel.typePayment,
      payerUid: fromUid,
      amount: Money.fromPaise(paise),
      category: 'Payment',
      description: 'Payment',
      splitType: 'custom',
      splits: {toUid: SplitEntry(amountOwed: Money.fromPaise(paise), settled: true)},
      date: now,
      createdAt: now,
      createdBy: _me,
    );

    final batch = _db.batch();
    batch.set(ref, payment.toMap());

    final after = [...currentExpenses, payment];
    final pairNet = Settlement.pairwiseFor(fromUid, after)[toUid] ?? 0;
    if (Money.isZero(pairNet)) {
      for (final e in currentExpenses) {
        if (e.isPayment || e.isDeleted || e.isRecurringTemplate) continue;
        String? debtor;
        if (e.payerUid == toUid && e.splits[fromUid] != null) debtor = fromUid;
        if (e.payerUid == fromUid && e.splits[toUid] != null) debtor = toUid;
        if (debtor == null) continue;
        final entry = e.splits[debtor]!;
        if (entry.settled || entry.amountOwed <= 0) continue;
        batch.update(_expenses(group.groupId).doc(e.expenseId), {
          'splits.$debtor': {'amountOwed': entry.amountOwed, 'settled': true},
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    _activity(batch, group.groupId, GroupActivityModel.settledUp,
        '$fromName paid $toName ${Money.format(amount)}',
        expenseId: ref.id);
    final outcome = await commitWithTimeout(batch.commit());

    runInBackground(() async {
      await _mirrors.scanAll();
      final other = _me == fromUid ? toUid : fromUid;
      await _notify.send(
        recipients: [other],
        type: NotificationModel.paymentRecorded,
        message: _me == fromUid
            ? '$_myName paid you ${Money.format(amount)} in ${group.name}'
            : '$_myName marked your ${Money.format(amount)} payment as received in ${group.name}',
        groupId: group.groupId,
        groupName: group.name,
        expenseId: ref.id,
        amount: amount,
      );
    }, label: 'payment side effects');
    return outcome;
  }

  // ── Recurring templates ───────────────────────────────────────────────────

  Future<void> setTemplatePaused(String groupId, String templateId, {required bool paused}) async {
    await commitWithTimeout(_expenses(groupId).doc(templateId).update({
      'isCancelled': paused,
      if (!paused) 'lastGeneratedDate': Timestamp.fromDate(DateTime.now()),
      'updatedAt': FieldValue.serverTimestamp(),
    }));
  }

  Future<void> deleteTemplate(String groupId, String templateId) async {
    await commitWithTimeout(_expenses(groupId).doc(templateId).update({
      'isDeleted': true,
      'isCancelled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }));
  }
}
