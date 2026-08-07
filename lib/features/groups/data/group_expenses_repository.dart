import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/firestore_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/group_expense_model.dart';

class GroupActivityModel {
  final String activityId;
  final String type; // "expense_added" | "expense_edited" | "expense_deleted" | "settled_up"
  final String actorUid;
  final String? expenseId; // linked expense document ID
  final String message;
  final DateTime createdAt;

  GroupActivityModel({
    required this.activityId,
    required this.type,
    required this.actorUid,
    this.expenseId,
    required this.message,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'actorUid': actorUid,
      'expenseId': expenseId,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory GroupActivityModel.fromMap(Map<String, dynamic> map, String id) {
    final rawDate = map['createdAt'];
    DateTime parsedDate = DateTime.now();
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    return GroupActivityModel(
      activityId: id,
      type: map['type'] ?? '',
      actorUid: map['actorUid'] ?? '',
      expenseId: map['expenseId'],
      message: map['message'] ?? '',
      createdAt: parsedDate,
    );
  }
}

final groupExpensesRepositoryProvider = Provider<GroupExpensesRepository>((ref) {
  return GroupExpensesRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final groupExpensesStreamProvider = StreamProvider.family<List<GroupExpenseModel>, String>((ref, groupId) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      final repository = ref.watch(groupExpensesRepositoryProvider);
      return repository.streamGroupExpenses(groupId);
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => const Stream.empty(),
  );
});

final groupTemplatesStreamProvider = StreamProvider.family<List<GroupExpenseModel>, String>((ref, groupId) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      final repository = ref.watch(groupExpensesRepositoryProvider);
      return repository.streamGroupTemplates(groupId);
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => const Stream.empty(),
  );
});

final groupActivityStreamProvider = StreamProvider.family<List<GroupActivityModel>, String>((ref, groupId) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      final repository = ref.watch(groupExpensesRepositoryProvider);
      return repository.streamGroupActivity(groupId);
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => const Stream.empty(),
  );
});

class GroupExpensesRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  GroupExpensesRepository(this._firestore, this._auth);

  String? get _currentUid => _auth.currentUser?.uid;

  Stream<List<GroupExpenseModel>> streamGroupExpenses(String groupId) {
    return retryOnPermissionDenied(() => _firestore
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => GroupExpenseModel.fromMap(doc.data(), doc.id))
              .where((e) => !e.isRecurringTemplate)
              .toList();
          // Sort in-memory in Dart: descending order of creation (newest first)
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        }));
  }

  Stream<List<GroupExpenseModel>> streamGroupTemplates(String groupId) {
    return retryOnPermissionDenied(() => _firestore
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => GroupExpenseModel.fromMap(doc.data(), doc.id))
              .where((e) => e.isRecurringTemplate && !e.isCancelled)
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        }));
  }

  Stream<List<GroupActivityModel>> streamGroupActivity(String groupId) {
    return retryOnPermissionDenied(() => _firestore
        .collection('groups')
        .doc(groupId)
        .collection('activity')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => GroupActivityModel.fromMap(doc.data(), doc.id))
              .toList();
        }));
  }

  Future<String> _getActorName(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      return userDoc.data()?['displayName'] ?? 'Someone';
    } catch (_) {
      return _auth.currentUser?.displayName ?? 'Someone';
    }
  }

  Future<void> addGroupExpense(String groupId, GroupExpenseModel expense) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    final actorName = await _getActorName(uid);
    final batch = _firestore.batch();
    
    final expenseDoc = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .doc(expense.expenseId);
    batch.set(expenseDoc, expense.toMap());

    // Do not log template creation as a normal expense added activity to avoid feed clutter
    if (!expense.isRecurringTemplate) {
      final activityDoc = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('activity')
          .doc();
      batch.set(activityDoc, {
        'type': 'expense_added',
        'actorUid': uid,
        'expenseId': expense.expenseId,
        'message': '$actorName added "${expense.description}" of ₹${expense.amount.toStringAsFixed(2)}',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> updateGroupExpense(String groupId, GroupExpenseModel expense) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    final actorName = await _getActorName(uid);
    final batch = _firestore.batch();
    
    final expenseDoc = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .doc(expense.expenseId);
    batch.set(expenseDoc, expense.toMap(), SetOptions(merge: true));

    if (!expense.isRecurringTemplate) {
      final activityDoc = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('activity')
          .doc();
      batch.set(activityDoc, {
        'type': 'expense_edited',
        'actorUid': uid,
        'expenseId': expense.expenseId,
        'message': '$actorName edited "${expense.description}"',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> softDeleteGroupExpense(String groupId, String expenseId) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    final actorName = await _getActorName(uid);
    
    String description = 'an expense';
    try {
      final expDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .doc(expenseId)
          .get();
      description = expDoc.data()?['description'] ?? 'an expense';
    } catch (_) {}

    final batch = _firestore.batch();
    
    final expenseDoc = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .doc(expenseId);
    batch.update(expenseDoc, {'isDeleted': true});

    final activityDoc = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('activity')
        .doc();
    batch.set(activityDoc, {
      'type': 'expense_deleted',
      'actorUid': uid,
      'expenseId': expenseId,
      'message': '$actorName deleted "$description"',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> cancelGroupRecurringExpense(String groupId, String expenseId) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    final actorName = await _getActorName(uid);
    String description = 'a recurring expense';
    try {
      final expDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .doc(expenseId)
          .get();
      description = expDoc.data()?['description'] ?? 'a recurring expense';
    } catch (_) {}

    final batch = _firestore.batch();
    batch.update(
      _firestore.collection('groups').doc(groupId).collection('expenses').doc(expenseId),
      {'isCancelled': true},
    );

    final activityDoc = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('activity')
        .doc();
    batch.set(activityDoc, {
      'type': 'expense_edited',
      'actorUid': uid,
      'expenseId': expenseId,
      'message': '$actorName cancelled recurring template "$description"',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> recordPayment(String groupId, String fromUid, String toUid, double amount) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    final expenseId = const Uuid().v4();
    final expense = GroupExpenseModel(
      expenseId: expenseId,
      payerUid: fromUid,
      amount: amount,
      category: 'Settlement',
      description: 'Settlement Payment',
      splitType: 'custom',
      splits: {
        toUid: amount,
      },
      createdAt: DateTime.now(),
    );

    final fromName = await _getActorName(fromUid);
    final toName = await _getActorName(toUid);

    final batch = _firestore.batch();
    
    final expenseDoc = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .doc(expenseId);
    batch.set(expenseDoc, expense.toMap());

    final activityDoc = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('activity')
        .doc();
    batch.set(activityDoc, {
      'type': 'settled_up',
      'actorUid': uid,
      'expenseId': expenseId,
      'message': '$fromName paid $toName ₹${amount.toStringAsFixed(2)}',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
