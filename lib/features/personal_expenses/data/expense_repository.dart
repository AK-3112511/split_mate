import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/firestore_helper.dart';
import '../../../core/utils/image_codec.dart';
import '../../../core/utils/write_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../../receipts/data/receipts_repository.dart';
import '../domain/expense_model.dart';

/// All visible personal expenses (no templates, no tombstoned mirrors), newest first.
final personalExpensesProvider = StreamProvider<List<ExpenseModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(expenseRepositoryProvider).streamExpenses(uid);
});

/// Recurring templates, including paused ones (the UI can resume them).
final personalTemplatesProvider = StreamProvider<List<ExpenseModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(expenseRepositoryProvider).streamTemplates(uid);
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(
    ref.watch(firestoreProvider),
    ref.watch(currentUidProvider),
    ref.watch(receiptsRepositoryProvider),
  );
});

class ExpenseRepository {
  final FirebaseFirestore _db;
  final String? _uid;
  final ReceiptsRepository _receipts;

  ExpenseRepository(this._db, this._uid, this._receipts);

  String get _requireUid {
    final uid = _uid;
    if (uid == null) throw const AppException('Please sign in again.');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('expenses');

  Stream<List<ExpenseModel>> streamExpenses(String uid) {
    return retryOnPermissionDenied(() => _col(uid).snapshots().map((snap) {
          final list = snap.docs
              .map((d) => ExpenseModel.fromMap(d.data(), d.id))
              .where((e) => !e.isRecurringTemplate && !e.hidden)
              .toList();
          list.sort((a, b) {
            final byDate = b.date.compareTo(a.date);
            return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
          });
          return list;
        }));
  }

  Stream<List<ExpenseModel>> streamTemplates(String uid) {
    return retryOnPermissionDenied(() => _col(uid)
        .where('isRecurringTemplate', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => ExpenseModel.fromMap(d.data(), d.id)).toList();
          list.sort((a, b) => a.description.toLowerCase().compareTo(b.description.toLowerCase()));
          return list;
        }));
  }

  /// Pre-allocates an id so callers can reference the doc before it syncs.
  String newId() => _col(_requireUid).doc().id;

  Future<WriteOutcome> add(ExpenseModel expense, {EncodedImage? receipt}) {
    final uid = _requireUid;
    final batch = _db.batch();
    String? receiptId = expense.receiptId;
    if (receipt != null) {
      receiptId = _receipts.stage(batch, receipt, expenseId: expense.id);
    }
    final data = expense.copyWith(receiptId: receiptId).toMap();
    if (expense.isRecurringTemplate) data['recurrenceVersion'] = 2;
    batch.set(_col(uid).doc(expense.id), data);
    return commitWithTimeout(batch.commit());
  }

  /// Edits only user-editable fields so mirror / recurring metadata survives.
  Future<WriteOutcome> update(
    ExpenseModel expense, {
    EncodedImage? newReceipt,
    bool removeReceipt = false,
  }) {
    final uid = _requireUid;
    final batch = _db.batch();
    final fields = <String, dynamic>{
      'amount': expense.amount,
      'categoryId': expense.categoryId,
      'category': expense.categoryName,
      'description': expense.description,
      'notes': expense.notes,
      'date': Timestamp.fromDate(expense.date),
      'recurrenceInterval': expense.recurrenceInterval,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (newReceipt != null) {
      fields['receiptId'] = _receipts.stage(batch, newReceipt, expenseId: expense.id);
      fields['receiptUrl'] = FieldValue.delete();
    } else if (removeReceipt) {
      fields['receiptId'] = null;
      fields['receiptUrl'] = FieldValue.delete();
    }
    if (removeReceipt || newReceipt != null) {
      final old = expense.receiptId;
      if (old != null) batch.delete(_receipts.collection().doc(old));
    }
    batch.update(_col(uid).doc(expense.id), fields);
    return commitWithTimeout(batch.commit());
  }

  /// Deletes an expense. Group mirrors are tombstoned (`hidden`) instead, so
  /// the mirror scan never brings them back.
  Future<WriteOutcome> delete(ExpenseModel expense) {
    final uid = _requireUid;
    final doc = _col(uid).doc(expense.id);
    if (expense.isMirror) {
      return commitWithTimeout(
        doc.update({'hidden': true, 'updatedAt': FieldValue.serverTimestamp()}),
      );
    }
    return commitWithTimeout(doc.delete());
  }

  /// Undo for [delete]: restores the exact previous document.
  Future<WriteOutcome> restore(ExpenseModel expense) {
    final uid = _requireUid;
    final doc = _col(uid).doc(expense.id);
    if (expense.isMirror) {
      return commitWithTimeout(doc.update({'hidden': false}));
    }
    final data = expense.toMap();
    if (expense.legacyReceipt != null) data['receiptUrl'] = expense.legacyReceipt;
    return commitWithTimeout(doc.set(data));
  }

  /// Called once an undo window has passed so orphaned receipt images go away.
  Future<void> purgeReceipt(ExpenseModel expense) async {
    final id = expense.receiptId;
    if (id == null || expense.isMirror) return;
    await _receipts.delete(id);
  }

  Future<void> setTemplatePaused(String templateId, {required bool paused}) async {
    final uid = _requireUid;
    await commitWithTimeout(_col(uid).doc(templateId).update({
      'isCancelled': paused,
      // Resuming continues from today instead of back-filling the paused months.
      if (!paused) 'lastGeneratedDate': Timestamp.fromDate(DateTime.now()),
      'updatedAt': FieldValue.serverTimestamp(),
    }));
  }

  Future<void> deleteTemplate(String templateId) async {
    final uid = _requireUid;
    await commitWithTimeout(_col(uid).doc(templateId).delete());
  }

  // ── Group mirrors (spec §12) — doc id "mirror_{groupExpenseId}" ───────────

  static String mirrorId(String groupExpenseId) => 'mirror_$groupExpenseId';

  /// Every mirror the user has, keyed by source group expense id (incl. hidden).
  Future<Map<String, ExpenseModel>> loadMirrors() async {
    final uid = _requireUid;
    final snap = await _col(uid).where('isFromGroup', isEqualTo: true).get();
    return {
      for (final d in snap.docs)
        if (d.data()['sourceExpenseId'] != null)
          d.data()['sourceExpenseId'] as String: ExpenseModel.fromMap(d.data(), d.id),
    };
  }

  void stageMirrorUpsert(WriteBatch batch, ExpenseModel mirror) {
    batch.set(_col(_requireUid).doc(mirror.id), mirror.toMap());
  }

  void stageMirrorDelete(WriteBatch batch, String mirrorDocId) {
    batch.delete(_col(_requireUid).doc(mirrorDocId));
  }

  void stageMirrorHide(WriteBatch batch, String mirrorDocId) {
    batch.update(_col(_requireUid).doc(mirrorDocId), {
      'hidden': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  WriteBatch batch() => _db.batch();
}
