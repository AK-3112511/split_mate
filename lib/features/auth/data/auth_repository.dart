import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/firestore_helper.dart';
import '../../../core/utils/image_codec.dart';
import '../../categories/domain/category_model.dart';
import '../domain/user_profile.dart';
import 'is_seeding_provider.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Emits on sign-in/out *and* profile/verification changes (userChanges).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).userChanges();
});

/// The signed-in uid, or null. Every user-scoped provider watches this so data
/// is rebuilt (never leaked) when the account changes.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});

/// The signed-in user's own public profile.
final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).streamProfile(uid);
});

/// Any user's public profile (friends, group members).
final userProfileProvider = StreamProvider.autoDispose.family<UserProfile?, String>((ref, uid) {
  if (uid.isEmpty) return Stream.value(null);
  final link = ref.keepAlive();
  // Keep profiles warm briefly so scrolling lists don't resubscribe constantly.
  ref.onCancel(() => Future.delayed(const Duration(seconds: 30), link.close));
  return ref.watch(authRepositoryProvider).streamProfile(uid);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider), ref);
});

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final Ref _ref;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthRepository(this._auth, this._db, this._ref);

  /// Look-alike characters (0/O, 1/I/L) removed so codes are easy to read aloud.
  static const String codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static String generateCode([Random? rnd]) {
    final r = rnd ?? Random.secure();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => codeAlphabet.codeUnitAt(r.nextInt(codeAlphabet.length))),
    );
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) => _db.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _privateDoc(String uid) =>
      _userDoc(uid).collection('private').doc('profile');
  DocumentReference<Map<String, dynamic>> _codeDoc(String code) =>
      _db.collection('app_codes').doc(code);

  Stream<UserProfile?> streamProfile(String uid) {
    return retryOnPermissionDenied(
      () => _userDoc(uid).snapshots().map((s) => s.exists ? UserProfile.fromMap(uid, s.data()) : null),
    );
  }

  // ── Sign in / up ──────────────────────────────────────────────────────────

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _ref.read(isAuthSeedingProvider.notifier).state = true;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      final user = cred.user;
      if (user == null) throw const AppException('Couldn\'t create your account. Please try again.');
      await user.updateDisplayName(fullName.trim());
      await ensureProfile(user, displayName: fullName.trim());
      // Sent exactly once, here. The verify screen only resends on request.
      try {
        await user.sendEmailVerification();
      } catch (_) {}
    } finally {
      _ref.read(isAuthSeedingProvider.notifier).state = false;
    }
  }

  /// Returns false when the user cancelled the Google picker.
  Future<bool> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return false;
    final googleAuth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    _ref.read(isAuthSeedingProvider.notifier).state = true;
    try {
      final result = await _auth.signInWithCredential(credential);
      if (result.user != null) {
        await ensureProfile(result.user!, displayName: account.displayName);
      }
      return true;
    } finally {
      _ref.read(isAuthSeedingProvider.notifier).state = false;
    }
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> resendVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw const AppException('Please sign in again.');
    await user.sendEmailVerification();
  }

  /// Reloads the auth user; returns true when the email is now verified.
  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  bool get isPasswordUser =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ?? false;

  Future<void> changePassword({required String current, required String next}) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) throw const AppException('Please sign in again.');
    final cred = EmailAuthProvider.credential(email: email, password: current);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(next);
  }

  // ── Profile edits ─────────────────────────────────────────────────────────

  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    final clean = name.trim();
    if (user == null) throw const AppException('Please sign in again.');
    if (clean.length < 2) throw const AppException('Name should be at least 2 characters.');
    if (clean.length > 40) throw const AppException('Name should be under 40 characters.');
    await _userDoc(user.uid).set({'displayName': clean}, SetOptions(merge: true));
    await user.updateDisplayName(clean);
  }

  Future<void> updatePhoto(EncodedImage? image) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AppException('Please sign in again.');
    await _userDoc(uid).set({
      'photoData': image?.dataUri,
      // v1 stored a device-local file path here; clear it so nobody sees a broken image.
      'photoUrl': image == null ? null : FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  static final RegExp upiPattern = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z][a-zA-Z0-9]{1,63}$');

  Future<void> updateUpiId(String? upi) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AppException('Please sign in again.');
    final clean = upi?.trim() ?? '';
    if (clean.isNotEmpty && !upiPattern.hasMatch(clean)) {
      throw const AppException('That UPI ID doesn\'t look right (e.g. name@okaxis).');
    }
    await _userDoc(uid).set({'upiId': clean.isEmpty ? null : clean}, SetOptions(merge: true));
  }

  Future<String?> readPrivateEmail() async {
    final user = _auth.currentUser;
    return user?.email;
  }

  // ── Seeding & migration (idempotent; also run on every launch) ────────────

  /// Creates the profile for new users and migrates v1 profiles:
  /// - claims a unique friend code in `app_codes/{code}`
  /// - moves email out of the public doc into `private/profile`
  /// - seeds default categories when missing
  Future<void> ensureProfile(User user, {String? displayName}) async {
    final ref = _userDoc(user.uid);
    final snap = await ref.get();
    final data = snap.data();

    if (!snap.exists || data == null) {
      await _claimCode(user.uid, extra: {
        'displayName': (displayName ?? user.displayName ?? '').trim().isEmpty
            ? 'SplitMate user'
            : (displayName ?? user.displayName)!.trim(),
        if (ImageCodec.isNetwork(user.photoURL)) 'photoUrl': user.photoURL,
        'categories': CategoryModel.defaults.map((c) => c.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _privateDoc(user.uid).set({'email': user.email ?? ''}, SetOptions(merge: true));
      return;
    }

    // Friend code: claim or register in the uniqueness registry.
    final code = (data['appCode'] as String?)?.toUpperCase();
    if (code == null || code.isEmpty) {
      await _claimCode(user.uid);
    } else {
      final reg = await _codeDoc(code).get();
      if (!reg.exists) {
        try {
          await _codeDoc(code).set({'uid': user.uid, 'createdAt': FieldValue.serverTimestamp()});
        } catch (_) {
          await _claimCode(user.uid); // someone else holds it
        }
      } else if (reg.data()?['uid'] != user.uid) {
        await _claimCode(user.uid); // v1 duplicate code → issue a fresh one
      }
    }

    final updates = <String, dynamic>{};
    if (data.containsKey('email')) {
      await _privateDoc(user.uid).set({'email': data['email'] ?? user.email ?? ''}, SetOptions(merge: true));
      updates['email'] = FieldValue.delete();
    }
    final photo = data['photoUrl'];
    if (photo is String && photo.isNotEmpty && !ImageCodec.isNetwork(photo)) {
      updates['photoUrl'] = FieldValue.delete(); // v1 device-local path
    }
    final cats = data['categories'];
    if (cats is! List || cats.isEmpty) {
      updates['categories'] = CategoryModel.defaults.map((c) => c.toMap()).toList();
    }
    if (data['createdAt'] == null) updates['createdAt'] = FieldValue.serverTimestamp();
    if (updates.isNotEmpty) await ref.update(updates);
  }

  /// Atomically reserves a fresh code in `app_codes` and writes it (plus any
  /// [extra] fields) to the user doc. Retries on collision.
  Future<String> _claimCode(String uid, {Map<String, dynamic>? extra}) async {
    for (var attempt = 0; attempt < 6; attempt++) {
      final code = generateCode();
      try {
        await _db.runTransaction((tx) async {
          final reg = await tx.get(_codeDoc(code));
          if (reg.exists) throw const _Collision();
          tx.set(_codeDoc(code), {'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
          tx.set(_userDoc(uid), {'appCode': code, ...?extra}, SetOptions(merge: true));
        });
        return code;
      } on _Collision {
        continue;
      }
    }
    throw const AppException('Couldn\'t create your friend code. Please try again.');
  }
}

class _Collision implements Exception {
  const _Collision();
}
