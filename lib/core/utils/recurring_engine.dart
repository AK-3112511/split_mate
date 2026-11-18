import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/groups/domain/group_activity_model.dart';
import '../../features/groups/domain/group_expense_model.dart';
import '../../features/personal_expenses/domain/expense_model.dart';
import '../domain/recurrence.dart';
import 'money.dart';

final recurringEngineProvider = Provider<RecurringEngine>((ref) {
  return RecurringEngine(ref.watch(firestoreProvider));
});

/// Generates due instances of recurring templates, idempotently.
///
/// - Instance ids are deterministic (`{templateId}_{yyyyMMdd}`) and created in a
///   transaction, so several devices / group members can run this at once
///   without duplicates (v1 bug).
/// - Missed periods are caught up (capped), each instance dated on its due day.
/// - Runs online only (transactions); offline it simply retries next launch.
class RecurringEngine {
  final FirebaseFirestore _db;
  RecurringEngine(this._db);

  Future<void> run(String uid, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    try {
      await _personal(uid, at);
    } catch (e) {
      debugPrint('Recurring (personal) skipped: $e');
    }
    try {
      await _groups(uid, at);
    } catch (e) {
      debugPrint('Recurring (groups) skipped: $e');
    }
  }

  /// v1 templates whose lastGeneratedDate was wiped by the old edit bug would
  /// otherwise back-fill a year of instances; for those only the latest
  /// occurrence is generated.
  static List<DateTime> dueFor(Map<String, dynamic> raw, DateTime start, RecurrenceInterval interval,
      DateTime? lastGen, DateTime now) {
    final due = Recurrence.dueOccurrences(start: start, interval: interval, lastGenerated: lastGen, now: now);
    final isV2 = raw['recurrenceVersion'] == 2;
    if (!isV2 && lastGen == null && due.length > 1) return [due.last];
    return due;
  }

  Future<void> _personal(String uid, DateTime now) async {
    final col = _db.collection('users').doc(uid).collection('expenses');
    final templates = await col.where('isRecurringTemplate', isEqualTo: true).get();
    for (final doc in templates.docs) {
      final t = ExpenseModel.fromMap(doc.data(), doc.id);
      final interval = t.interval;
      if (t.isCancelled || interval == null) continue;
      if (dueFor(doc.data(), t.date, interval, t.lastGeneratedDate, now).isEmpty) continue;

      await _db.runTransaction((tx) async {
        final fresh = await tx.get(doc.reference);
        final data = fresh.data();
        if (data == null) return;
        final tm = ExpenseModel.fromMap(data, fresh.id);
        if (tm.isCancelled || !tm.isRecurringTemplate) return;
        final due = dueFor(data, tm.date, interval, tm.lastGeneratedDate, now);
        if (due.isEmpty) return;
        final refs = [for (final d in due) col.doc(Recurrence.instanceId(tm.id, d))];
        final existing = [for (final r in refs) await tx.get(r)];
        for (var i = 0; i < due.length; i++) {
          if (existing[i].exists) continue;
          tx.set(refs[i], ExpenseModel(
            id: refs[i].id,
            amount: tm.amount,
            categoryId: tm.categoryId,
            categoryName: tm.categoryName,
            description: tm.description,
            notes: tm.notes,
            date: due[i],
            createdAt: now,
            generatedFromTemplateId: tm.id,
          ).toMap());
        }
        tx.update(fresh.reference, {'lastGeneratedDate': Timestamp.fromDate(due.last)});
      });
    }
  }

  Future<void> _groups(String uid, DateTime now) async {
    final groups = await _db.collection('groups').where('members', arrayContains: uid).get();
    for (final g in groups.docs) {
      if (g.data()['isDeleted'] == true) continue;
      final col = g.reference.collection('expenses');
      final templates = await col.where('isRecurringTemplate', isEqualTo: true).get();
      for (final doc in templates.docs) {
        final t = GroupExpenseModel.fromMap(doc.data(), doc.id);
        final interval = t.interval;
        if (t.isCancelled || t.isDeleted || interval == null) continue;
        if (dueFor(doc.data(), t.date, interval, t.lastGeneratedDate, now).isEmpty) continue;

        await _db.runTransaction((tx) async {
          final fresh = await tx.get(doc.reference);
          final data = fresh.data();
          if (data == null) return;
          final tm = GroupExpenseModel.fromMap(data, fresh.id);
          if (tm.isCancelled || tm.isDeleted || !tm.isRecurringTemplate) return;
          final due = dueFor(data, tm.date, interval, tm.lastGeneratedDate, now);
          if (due.isEmpty) return;
          final refs = [for (final d in due) col.doc(Recurrence.instanceId(tm.expenseId, d))];
          final existing = [for (final r in refs) await tx.get(r)];
          for (var i = 0; i < due.length; i++) {
            if (existing[i].exists) continue;
            final instance = GroupExpenseModel(
              expenseId: refs[i].id,
              payerUid: tm.payerUid,
              amount: tm.amount,
              category: tm.category,
              categoryIcon: tm.categoryIcon,
              categoryColor: tm.categoryColor,
              description: tm.description,
              notes: tm.notes,
              splitType: tm.splitType,
              splits: {
                for (final e in tm.splits.entries)
                  e.key: SplitEntry(amountOwed: e.value.amountOwed, settled: e.key == tm.payerUid),
              },
              items: tm.items,
              itemsExtra: tm.itemsExtra,
              shareWeights: tm.shareWeights,
              adjustments: tm.adjustments,
              fx: tm.fx,
              date: due[i],
              createdAt: now,
              createdBy: tm.createdBy,
              generatedFromTemplateId: tm.expenseId,
            );
            tx.set(refs[i], instance.toMap());
            tx.set(g.reference.collection('activity').doc(), {
              'type': GroupActivityModel.expenseAdded,
              'actorUid': uid,
              'expenseId': refs[i].id,
              'message': 'Recurring: "${tm.description}" · ${Money.format(tm.amount)} was added',
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
          tx.update(fresh.reference, {
            'lastGeneratedDate': Timestamp.fromDate(due.last),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      }
    }
  }
}
