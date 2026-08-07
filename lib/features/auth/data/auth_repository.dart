import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'is_seeding_provider.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref,
  );
});

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final Ref _ref;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthRepository(this._auth, this._firestore, this._ref);

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    if (credential.user != null) {
      await _seedUserIfNeeded(credential.user!, credential.user!.displayName);
    }
    return credential;
  }

  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _ref.read(isAuthSeedingProvider.notifier).state = true;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (credential.user != null) {
        await credential.user!.updateDisplayName(fullName);
        await _seedUserIfNeeded(credential.user!, fullName);
        try {
          await credential.user!.sendEmailVerification();
        } catch (e) {
          // Handled gracefully; fallback trigger in VerifyEmailScreen
        }
      }
      return credential;
    } finally {
      _ref.read(isAuthSeedingProvider.notifier).state = false;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    _ref.read(isAuthSeedingProvider.notifier).state = true;
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _seedUserIfNeeded(userCredential.user!, googleUser.displayName);
      }
      return userCredential;
    } finally {
      _ref.read(isAuthSeedingProvider.notifier).state = false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  String _generateAppCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  Future<void> _seedUserIfNeeded(User user, String? displayName) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    
    if (!doc.exists) {
      final uuid = const Uuid();
      final defaultCategories = [
        {'id': uuid.v4(), 'name': 'Food', 'iconCode': 'restaurant', 'colorHex': 'FF5722'},
        {'id': uuid.v4(), 'name': 'Rent', 'iconCode': 'home', 'colorHex': '2196F3'},
        {'id': uuid.v4(), 'name': 'Travel', 'iconCode': 'directions_car', 'colorHex': '4CAF50'},
        {'id': uuid.v4(), 'name': 'Entertainment', 'iconCode': 'movie', 'colorHex': '9C27B0'},
        {'id': uuid.v4(), 'name': 'Utilities', 'iconCode': 'electrical_services', 'colorHex': 'FFEB3B'},
      ];
      
      await docRef.set({
        'displayName': displayName ?? user.displayName ?? 'New Ledger User',
        'email': user.email ?? '',
        'photoUrl': user.photoURL,
        'appCode': _generateAppCode(),
        'categories': defaultCategories,
      }, SetOptions(merge: true));
    } else {
      // Backfill appCode if existing user doc is missing it
      final data = doc.data();
      if (data != null && data['appCode'] == null) {
        await docRef.update({'appCode': _generateAppCode()});
      }
    }
  }
}
