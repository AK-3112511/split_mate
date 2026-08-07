import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/personal_expenses/domain/expense_model.dart';
import '../../features/groups/domain/group_expense_model.dart';

Future<void> processRecurringTemplates(WidgetRef ref) async {
  final authState = ref.read(authStateProvider).value;
  if (authState == null) return;
  final myUid = authState.uid;

  final firestore = ref.read(firestoreProvider);

  // 1. Process Personal Templates
  try {
    final personalSnaps = await firestore
        .collection('users')
        .doc(myUid)
        .collection('expenses')
        .where('isRecurringTemplate', isEqualTo: true)
        .where('isCancelled', isEqualTo: false)
        .get();

    for (var doc in personalSnaps.docs) {
      final template = ExpenseModel.fromMap(doc.data(), doc.id);
      if (shouldGenerateRecurringInstance(template.lastGeneratedDate, template.recurrenceInterval, template.createdAt)) {
        final newId = const Uuid().v4();
        final newExpense = ExpenseModel(
          id: newId,
          amount: template.amount,
          category: template.category,
          description: template.description,
          createdAt: DateTime.now(),
          isRecurringTemplate: false,
          generatedFromTemplateId: template.id,
        );

        final batch = firestore.batch();
        // Add generated personal expense
        batch.set(
          firestore.collection('users').doc(myUid).collection('expenses').doc(newId),
          newExpense.toMap(),
        );
        // Update template lastGeneratedDate
        batch.update(
          firestore.collection('users').doc(myUid).collection('expenses').doc(template.id),
          {'lastGeneratedDate': FieldValue.serverTimestamp()},
        );
        await batch.commit();
      }
    }
  } catch (e) {
    // Gracefully catch background load errors (e.g. offline)
    print('Recurring Engine (Personal): $e');
  }

  // 2. Process Group Templates
  try {
    final groupsSnap = await firestore
        .collection('groups')
        .where('members', arrayContains: myUid)
        .get();

    for (var groupDoc in groupsSnap.docs) {
      final groupId = groupDoc.id;
      final groupTemplates = await firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .where('isRecurringTemplate', isEqualTo: true)
          .where('isCancelled', isEqualTo: false)
          .get();

      for (var doc in groupTemplates.docs) {
        final template = GroupExpenseModel.fromMap(doc.data(), doc.id);
        if (shouldGenerateRecurringInstance(template.lastGeneratedDate, template.recurrenceInterval, template.createdAt)) {
          final newId = const Uuid().v4();
          final newExpense = GroupExpenseModel(
            expenseId: newId,
            payerUid: template.payerUid,
            amount: template.amount,
            category: template.category,
            description: template.description,
            splitType: template.splitType,
            splits: template.splits,
            createdAt: DateTime.now(),
            isRecurringTemplate: false,
            generatedFromTemplateId: template.expenseId,
          );

          final batch = firestore.batch();

          // Add generated group expense
          final expenseDoc = firestore
              .collection('groups')
              .doc(groupId)
              .collection('expenses')
              .doc(newId);
          batch.set(expenseDoc, newExpense.toMap());

          // Update template lastGeneratedDate
          final templateDoc = firestore
              .collection('groups')
              .doc(groupId)
              .collection('expenses')
              .doc(template.expenseId);
          batch.update(templateDoc, {'lastGeneratedDate': FieldValue.serverTimestamp()});

          // Add group activity log
          final actorName = await _getActorName(firestore, myUid);
          final activityDoc = firestore
              .collection('groups')
              .doc(groupId)
              .collection('activity')
              .doc();
          batch.set(activityDoc, {
            'type': 'expense_added',
            'actorUid': myUid,
            'expenseId': newId,
            'message': 'Recurring: $actorName generated "${newExpense.description}" of ₹${newExpense.amount.toStringAsFixed(2)}',
            'createdAt': FieldValue.serverTimestamp(),
          });

          await batch.commit();
        }
      }
    }
  } catch (e) {
    print('Recurring Engine (Group): $e');
  }
}

bool shouldGenerateRecurringInstance(DateTime? lastGen, String? interval, DateTime templateCreated) {
  if (lastGen == null) return true; // never generated, needs initial instance
  
  final now = DateTime.now();
  if (interval == 'weekly') {
    return now.difference(lastGen).inDays >= 7;
  } else if (interval == 'monthly') {
    return now.difference(lastGen).inDays >= 30;
  }
  return false;
}

Future<String> _getActorName(FirebaseFirestore firestore, String uid) async {
  try {
    final userDoc = await firestore.collection('users').doc(uid).get();
    return userDoc.data()?['displayName'] ?? 'Someone';
  } catch (_) {
    return 'Someone';
  }
}
