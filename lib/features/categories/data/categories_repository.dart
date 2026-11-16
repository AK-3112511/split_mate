import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/firestore_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/category_model.dart';

/// The user's categories (falls back to defaults while a v1 profile migrates).
final userCategoriesProvider = Provider<AsyncValue<List<CategoryModel>>>((ref) {
  return ref.watch(currentUserProfileProvider).whenData((p) {
    final cats = p?.categories ?? const <CategoryModel>[];
    return cats.isEmpty ? CategoryModel.defaults : cats;
  });
});

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(ref.watch(firestoreProvider), ref.watch(currentUidProvider));
});

class CategoriesRepository {
  final FirebaseFirestore _db;
  final String? _uid;

  CategoriesRepository(this._db, this._uid);

  DocumentReference<Map<String, dynamic>> get _doc {
    final uid = _uid;
    if (uid == null) throw const AppException('Please sign in again.');
    return _db.collection('users').doc(uid);
  }

  Future<List<Map<String, dynamic>>> _read(Transaction tx) async {
    final snap = await tx.get(_doc);
    final raw = snap.data()?['categories'];
    if (raw is List && raw.isNotEmpty) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return CategoryModel.defaults.map((c) => c.toMap()).toList();
  }

  void _checkName(List<Map<String, dynamic>> list, String name, {String? exceptId}) {
    final clean = name.trim();
    if (clean.isEmpty) throw const AppException('Give the category a name.');
    if (clean.length > 24) throw const AppException('Keep the name under 24 characters.');
    final dup = list.any((m) =>
        m['id'] != exceptId && (m['name'] ?? '').toString().trim().toLowerCase() == clean.toLowerCase());
    if (dup) throw AppException('You already have a "$clean" category.');
  }

  Future<CategoryModel> add({
    required String name,
    required String iconCode,
    required String colorHex,
    double? monthlyBudget,
  }) async {
    final category = CategoryModel(
      id: const Uuid().v4(),
      name: name.trim(),
      iconCode: iconCode,
      colorHex: colorHex,
      monthlyBudget: monthlyBudget,
    );
    await _db.runTransaction((tx) async {
      final list = await _read(tx);
      _checkName(list, name);
      list.add(category.toMap());
      tx.set(_doc, {'categories': list}, SetOptions(merge: true));
    });
    return category;
  }

  Future<void> update(CategoryModel category) async {
    await _db.runTransaction((tx) async {
      final list = await _read(tx);
      _checkName(list, category.name, exceptId: category.id);
      final i = list.indexWhere((m) => m['id'] == category.id);
      if (i == -1) {
        list.add(category.toMap());
      } else {
        list[i] = category.toMap();
      }
      tx.set(_doc, {'categories': list}, SetOptions(merge: true));
    });
  }

  Future<void> setBudget(String categoryId, double? budget) async {
    await _db.runTransaction((tx) async {
      final list = await _read(tx);
      final i = list.indexWhere((m) => m['id'] == categoryId);
      if (i == -1) return;
      if (budget == null || budget <= 0) {
        list[i].remove('monthlyBudget');
      } else {
        list[i]['monthlyBudget'] = budget;
      }
      tx.set(_doc, {'categories': list}, SetOptions(merge: true));
    });
  }

  /// Removes the category and moves its expenses to "Other" (by id and, for v1
  /// expenses, by name) so nothing turns into a phantom category.
  Future<void> delete(CategoryModel category) async {
    await _db.runTransaction((tx) async {
      final list = await _read(tx);
      list.removeWhere((m) => m['id'] == category.id);
      tx.set(_doc, {'categories': list}, SetOptions(merge: true));
    });

    final expenses = _doc.collection('expenses');
    final byId = await expenses.where('categoryId', isEqualTo: category.id).get();
    final byName = await expenses.where('category', isEqualTo: category.name).get();
    final refs = {
      for (final d in [...byId.docs, ...byName.docs]) d.id: d.reference,
    }.values.toList();
    for (final chunk in chunked(refs, 450)) {
      final batch = _db.batch();
      for (final r in chunk) {
        batch.update(r, {
          'categoryId': CategoryModel.othersId,
          'category': CategoryModel.others.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }
}
