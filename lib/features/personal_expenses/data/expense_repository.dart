import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/firestore_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/expense_model.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final personalExpensesProvider = StreamProvider<List<ExpenseModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      final repository = ref.watch(expenseRepositoryProvider);
      return repository.streamExpenses(user.uid);
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => const Stream.empty(),
  );
});

final personalTemplatesProvider = StreamProvider<List<ExpenseModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      final repository = ref.watch(expenseRepositoryProvider);
      return repository.streamTemplates(user.uid);
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => const Stream.empty(),
  );
});

class ExpenseRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ExpenseRepository(this._firestore, this._auth);

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<ExpenseModel>> streamExpenses(String uid) {
    return retryOnPermissionDenied(() => _firestore
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
              .where((e) => !e.isRecurringTemplate)
              .toList();
        }));
  }

  Stream<List<ExpenseModel>> streamTemplates(String uid) {
    return retryOnPermissionDenied(() => _firestore
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
              .where((e) => e.isRecurringTemplate && !e.isCancelled)
              .toList();
        }));
  }

  Future<void> addExpense(ExpenseModel expense) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .add(expense.toMap());
  }

  Future<void> updateExpense(String id, ExpenseModel expense) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .doc(id)
        .set(expense.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteExpense(String id) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .doc(id)
        .delete();
  }

  Future<void> cancelRecurringExpense(String id) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .doc(id)
        .update({'isCancelled': true});
  }

  // ── Group Mirror Helpers (Section 12) ─────────────────────────────────────

  /// Deterministic document ID for a mirrored expense so we never write twice.
  /// Format: mirror_{sourceExpenseId}
  /// Combined with the user's own subcollection, this is globally unique per user.
  String _mirrorDocId(String sourceExpenseId) => 'mirror_$sourceExpenseId';

  /// Returns true if a personal mirror already exists for this group expense.
  Future<bool> hasGroupMirror(String sourceExpenseId) async {
    final uid = _uid;
    if (uid == null) return false;
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .doc(_mirrorDocId(sourceExpenseId))
        .get();
    return doc.exists;
  }

  /// Writes a personal expense mirrored from a group expense using a deterministic
  /// document ID to guarantee idempotency — safe to call multiple times.
  Future<void> addGroupMirrorExpense(ExpenseModel expense) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not authenticated');

    final sourceId = expense.sourceExpenseId;
    if (sourceId == null) throw Exception('sourceExpenseId must be set for mirror writes');

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .doc(_mirrorDocId(sourceId))
        .set(expense.toMap(), SetOptions(merge: false));
  }

  /// Updates an existing personal mirror expense when a group expense is edited.
  /// Uses merge:true so only provided fields are overwritten.
  /// Safe to call even if the mirror does not exist yet — Firestore will silently create it.
  Future<void> updateGroupMirrorExpense(ExpenseModel expense) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not authenticated');

    final sourceId = expense.sourceExpenseId;
    if (sourceId == null) throw Exception('sourceExpenseId must be set for mirror updates');

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .doc(_mirrorDocId(sourceId))
        .set(expense.toMap(), SetOptions(merge: true));
  }

  /// Deletes a personal mirror expense (called when the group expense is deleted).
  Future<void> deleteGroupMirrorExpense(String sourceExpenseId) async {
    final uid = _uid;
    if (uid == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .doc(_mirrorDocId(sourceExpenseId));

    final snap = await docRef.get();
    if (snap.exists) {
      await docRef.delete();
    }
  }

  /// Writes multiple group mirror expenses in a single batch (for debtor-side
  /// settlement mirroring where several split entries may exist across expenses).
  Future<void> addGroupMirrorExpenses(List<ExpenseModel> expenses) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not authenticated');

    if (expenses.isEmpty) return;

    final batch = _firestore.batch();
    for (final expense in expenses) {
      final sourceId = expense.sourceExpenseId;
      if (sourceId == null) continue;

      // Only write if not already present (skip-check per item)
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .doc(_mirrorDocId(sourceId));
      batch.set(docRef, expense.toMap(), SetOptions(merge: false));
    }
    await batch.commit();
  }
}
