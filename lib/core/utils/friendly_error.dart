import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_exception.dart';

/// Maps any thrown object to a short, human message. Never leaks raw exceptions.
String friendlyError(Object? error) {
  if (error == null) return 'Something went wrong. Please try again.';
  if (error is AppException) return error.message;

  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address doesn\'t look right.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists with this email. Try signing in.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a minute and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and retry.';
      case 'requires-recent-login':
        return 'For security, please sign in again and retry.';
      case 'account-exists-with-different-credential':
        return 'This email is linked to a different sign-in method.';
      case 'popup-closed-by-user':
      case 'canceled':
        return 'Sign-in was cancelled.';
    }
    return 'Couldn\'t sign you in. Please try again.';
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'You don\'t have access to this anymore.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'You seem to be offline. We\'ll retry when you\'re back.';
      case 'not-found':
        return 'This item no longer exists.';
      case 'already-exists':
        return 'This already exists.';
      case 'resource-exhausted':
        return 'Too many requests right now. Try again shortly.';
      case 'failed-precondition':
      case 'aborted':
        return 'Something changed while saving. Please try again.';
      case 'invalid-argument':
        return 'Some details look invalid. Please check and retry.';
    }
    return 'Couldn\'t reach the server. Please try again.';
  }

  if (error is TimeoutException) {
    return 'This is taking longer than usual. Check your connection.';
  }
  return 'Something went wrong. Please try again.';
}
