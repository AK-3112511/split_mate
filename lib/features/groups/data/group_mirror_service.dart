import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/money.dart';
import '../../auth/data/auth_repository.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_model.dart';
import '../../categories/domain/category_resolver.dart';
import '../../personal_expenses/data/expense_repository.dart';
import '../../personal_expenses/domain/expense_model.dart';
import '../domain/group_expense_model.dart';

/// What to do with a user's personal copy ("mirror") of a group expense.
enum MirrorOp { none, upsert, remove, hide }

/// Pure decision (spec §12):
///  - my own share is mirrored immediately when I paid, otherwise once settled;
///  - deleted group expenses hide the mirror; a mirror the user hid stays hidden;
///  - shares that disappear or become unsettled after an edit drop the mirror.
MirrorOp decideMirror({
  required String me,
  required GroupExpenseModel expense,
  required ExpenseModel? existing,
}) {
  if (existing != null && existing.hidden) return MirrorOp.none;
  if (expense.isDeleted) return existing != null ? MirrorOp.hide : MirrorOp.none;
  if (expense.isPayment || expense.isRecurringTemplate) {
    return existing != null ? MirrorOp.remove : MirrorOp.none;
  }
  final entry = expense.splits[me];
  final share = entry?.amountOwed ?? 0;
  final should = share > 0 && (expense.payerUid == me || entry!.settled);
  if (!should) return existing != null ? MirrorOp.remove : MirrorOp.none;
  if (existing == null) return MirrorOp.upsert;
  final changed = !Money.equals(existing.amount, share) ||
      existing.description != expense.description ||
      existing.categoryName != expense.category ||
      existing.date != expense.date;
  return changed ? MirrorOp.upsert : MirrorOp.none;
}

ExpenseModel buildMirror({
  required String me,
  required String groupId,
  required String groupName,
  required GroupExpenseModel expense,
  required List<CategoryModel> myCategories,
  ExpenseModel? existing,
}) {
  final resolved = CategoryResolver.resolve(
    name: expense.category,
    iconCode: expense.categoryIcon,
    colorHex: expense.categoryColor,
    categories: myCategories,
  );
  return ExpenseModel(
    id: ExpenseRepository.mirrorId(expense.expenseId),
    amount: expense.shareOf(me),
    categoryId: resolved.id.startsWith('name:') ? '' : resolved.id,
    categoryName: expense.category,
    description: expense.description.isEmpty ? 'Group expense' : expense.description,
    date: expense.date,
    createdAt: existing?.createdAt ?? DateTime.now(),
    isFromGroup: true,
    sourceGroupId: groupId,
    sourceExpenseId: expense.expenseId,
    sourceGroupName: groupName,
  );
}

final mirrorServiceProvider = Provider<MirrorService>((ref) {
  return MirrorService(
    ref.watch(firestoreProvider),
    ref.watch(currentUidProvider),
    ref.watch(expenseRepositoryProvider),
    () => ref.read(userCategoriesProvider).valueOrNull ?? CategoryModel.defaults,
  );
});

/// Keeps the user's personal ledger in sync with their group shares.
class MirrorService {
  final FirebaseFirestore _db;
  final String? _uid;
  final ExpenseRepository _expenses;
  final List<CategoryModel> Function() _categories;

  MirrorService(this._db, this._uid, this._expenses, this._categories);

  static const Duration fullScanEvery = Duration(hours: 6);

  /// Scans all my groups. Full scan every few hours; otherwise only expenses
  /// updated since the last scan.
  Future<void> scanAll() async {
    final me = _uid;
    if (me == null) return;
    final startedAt = DateTime.now();
    final userDoc = _db.collection('users').doc(me);
    final lastScan = (await userDoc.get()).data()?['mirrorScanAt'];
    final last = lastScan is Timestamp ? lastScan.toDate() : null;
    final incremental = last != null && startedAt.difference(last) < fullScanEvery;

    final groups = await _db.collection('groups').where('members', arrayContains: me).get();
    final mirrors = await _expenses.loadMirrors();
    final ops = <_PendingOp>[];

    for (final g in groups.docs) {
      if (g.data()['isDeleted'] == true) continue;
      final groupName = (g.data()['name'] ?? 'Group').toString();
      Query<Map<String, dynamic>> q = g.reference.collection('expenses');
      if (incremental) {
        q = q.where('updatedAt', isGreaterThan: Timestamp.fromDate(last.subtract(const Duration(minutes: 10))));
      }
      final snap = await q.get();
      for (final d in snap.docs) {
        final e = GroupExpenseModel.fromMap(d.data(), d.id);
        final existing = mirrors[e.expenseId];
        final op = decideMirror(me: me, expense: e, existing: existing);
        if (op != MirrorOp.none) ops.add(_PendingOp(op, g.id, groupName, e, existing));
      }
    }
    await _apply(me, ops);
    await userDoc.set({'mirrorScanAt': Timestamp.fromDate(startedAt)}, SetOptions(merge: true));
  }

  /// Syncs one expense right after I add / edit / delete it or settle up.
  Future<void> syncOne(String groupId, String groupName, GroupExpenseModel expense) async {
    final me = _uid;
    if (me == null) return;
    final snap = await _db
        .collection('users')
        .doc(me)
        .collection('expenses')
        .doc(ExpenseRepository.mirrorId(expense.expenseId))
        .get();
    final existing = snap.exists ? ExpenseModel.fromMap(snap.data()!, snap.id) : null;
    final op = decideMirror(me: me, expense: expense, existing: existing);
    if (op == MirrorOp.none) return;
    await _apply(me, [_PendingOp(op, groupId, groupName, expense, existing)]);
  }

  Future<void> _apply(String me, List<_PendingOp> ops) async {
    if (ops.isEmpty) return;
    final cats = _categories();
    for (var i = 0; i < ops.length; i += 400) {
      final batch = _expenses.batch();
      for (final p in ops.skip(i).take(400)) {
        final id = ExpenseRepository.mirrorId(p.expense.expenseId);
        switch (p.op) {
          case MirrorOp.upsert:
            _expenses.stageMirrorUpsert(
              batch,
              buildMirror(
                me: me,
                groupId: p.groupId,
                groupName: p.groupName,
                expense: p.expense,
                myCategories: cats,
                existing: p.existing,
              ),
            );
          case MirrorOp.remove:
            _expenses.stageMirrorDelete(batch, id);
          case MirrorOp.hide:
            _expenses.stageMirrorHide(batch, id);
          case MirrorOp.none:
            break;
        }
      }
      await batch.commit();
    }
  }
}

class _PendingOp {
  final MirrorOp op;
  final String groupId;
  final String groupName;
  final GroupExpenseModel expense;
  final ExpenseModel? existing;
  _PendingOp(this.op, this.groupId, this.groupName, this.expense, this.existing);
}
