import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/firestore_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/category_model.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final userCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      final repository = ref.watch(categoriesRepositoryProvider);
      return repository.streamCategories(user.uid);
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => const Stream.empty(),
  );
});

class CategoriesRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CategoriesRepository(this._firestore, this._auth);

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<CategoryModel>> streamCategories(String uid) {
    return retryOnPermissionDenied(() => _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null || data['categories'] == null) return [];
          final list = data['categories'] as List;
          return list.map((e) => CategoryModel.fromMap(Map<String, dynamic>.from(e))).toList();
        }));
  }

  Future<void> addCategory(CategoryModel category) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not authenticated');

    await _firestore.collection('users').doc(uid).set({
      'categories': FieldValue.arrayUnion([category.toMap()]),
    }, SetOptions(merge: true));
  }

  Future<void> updateCategory(CategoryModel oldCategory, CategoryModel newCategory) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not authenticated');

    final docRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      
      final List<dynamic> categories = [];
      if (snapshot.exists) {
        final data = snapshot.data() ?? {};
        categories.addAll(data['categories'] ?? []);
      }
      
      final index = categories.indexWhere((element) => element['id'] == oldCategory.id);
      if (index != -1) {
        categories[index] = newCategory.toMap();
      } else {
        categories.add(newCategory.toMap());
      }
      
      transaction.set(docRef, {'categories': categories}, SetOptions(merge: true));
    });
  }

  Future<void> deleteCategory(CategoryModel category) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not authenticated');

    await _firestore.collection('users').doc(uid).set({
      'categories': FieldValue.arrayRemove([category.toMap()]),
    }, SetOptions(merge: true));
  }
}
