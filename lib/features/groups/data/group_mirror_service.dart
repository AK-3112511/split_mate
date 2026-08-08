import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../groups/domain/group_expense_model.dart';
import '../../personal_expenses/data/expense_repository.dart';
import '../../personal_expenses/domain/expense_model.dart';

/// GroupMirrorService (Section 12 — Debtor-Side Deferred Mirroring)
///
/// Scans ALL shared group expenses across ALL groups the current user belongs to.
/// For each split entry where:
///   - currentUser is the debtor (split entry uid == currentUid)
///   - settled == true (payer confirmed the settlement)
///   - no personal mirror exists yet (idempotent deterministic doc ID check)
///
/// Writes a corresponding personal expense entry into users/{uid}/expenses
/// using a deterministic doc ID = "mirror_{sourceExpenseId}" so multiple runs
/// never create duplicates.
///
/// Called from:
///   1. App launch (app.dart) — one-shot scan for offline/delayed settlements.
///   2. Settlement confirmation (settlement_screen.dart) — immediate after batch
///      marking splits settled, so the debtor's live stream picks it up instantly.

class GroupMirrorService {
  final FirebaseFirestore _firestore;
  final ExpenseRepository _expenseRepo;
  final String? _currentUid;

  GroupMirrorService({
    required FirebaseFirestore firestore,
    required ExpenseRepository expenseRepo,
    required String? currentUid,
  })  : _firestore = firestore,
        _expenseRepo = expenseRepo,
        _currentUid = currentUid;

  Future<void> runMirrorScan() async {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    // Fetch all groups the user belongs to
    final groupsSnapshot = await _firestore
        .collection('groups')
        .where('members', arrayContains: currentUid)
        .get();

    for (final groupDoc in groupsSnapshot.docs) {
      final groupId = groupDoc.id;

      // Fetch all non-deleted, non-template group expenses
      final expensesSnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .where('isDeleted', isEqualTo: false)
          .get();

      for (final expDoc in expensesSnapshot.docs) {
        final expense = GroupExpenseModel.fromMap(expDoc.data(), expDoc.id);

        // Skip settlement records, recurring templates, and payer-initiated expenses
        // (payer mirrors are written immediately at creation, not here)
        if (expense.isSettlement || expense.isRecurringTemplate) continue;
        if (expense.payerUid == currentUid) continue;

        // Check if currentUser has a split entry in this expense
        final splitEntry = expense.splits[currentUid];
        if (splitEntry == null) continue;

        // Only mirror when settled == true
        if (!splitEntry.settled) continue;

        // Check for existing mirror (idempotent guard)
        final alreadyMirrored = await _expenseRepo.hasGroupMirror(expense.expenseId);
        if (alreadyMirrored) continue;

        final groupName = groupDoc.data()['name'] ?? 'Group';
        final baseDesc = expense.description.isNotEmpty
            ? expense.description
            : 'Group Expense';
        final mirrorDesc = baseDesc.contains('($groupName)')
            ? baseDesc
            : '$baseDesc ($groupName)';

        // Write the personal mirror expense for this debtor
        final mirrorExpense = ExpenseModel(
          id: 'mirror_${expense.expenseId}', // deterministic, never collides
          amount: splitEntry.amountOwed,
          category: expense.category,
          description: mirrorDesc,
          createdAt: DateTime.now(),
          isFromGroup: true,
          sourceGroupId: groupId,
          sourceExpenseId: expense.expenseId,
        );

        await _expenseRepo.addGroupMirrorExpense(mirrorExpense);
      }
    }
  }
}

/// Creates a GroupMirrorService from any Riverpod ref (Ref or WidgetRef).
/// Both expose .read() so we use the functional approach.
GroupMirrorService _buildMirrorService(
  FirebaseFirestore firestore,
  ExpenseRepository expenseRepo,
  String? currentUid,
) {
  return GroupMirrorService(
    firestore: firestore,
    expenseRepo: expenseRepo,
    currentUid: currentUid,
  );
}

/// For Provider-based usage (server-side Ref)
final groupMirrorServiceProvider = Provider<GroupMirrorService>((ref) {
  return _buildMirrorService(
    ref.read(firestoreProvider),
    ref.read(expenseRepositoryProvider),
    ref.read(firebaseAuthProvider).currentUser?.uid,
  );
});

/// Convenience function — accepts any Riverpod ref type (Ref or WidgetRef)
/// by using the shared dynamic .read() method.
/// Called from app.dart (WidgetRef) and settlement_screen.dart (WidgetRef).
Future<void> runGroupMirrorScan(WidgetRef ref) async {
  final service = _buildMirrorService(
    ref.read(firestoreProvider),
    ref.read(expenseRepositoryProvider),
    ref.read(firebaseAuthProvider).currentUser?.uid,
  );
  await service.runMirrorScan();
}
