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
}
