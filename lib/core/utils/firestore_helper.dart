import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Wraps a Firestore stream and re-subscribes after a transient
/// 'permission-denied' (happens right after sign-in while the auth token
/// propagates). Other errors, or repeated denials, are surfaced to the UI.
///
/// The retry budget is only refilled once a subscription has stayed healthy
/// for [healthyAfter]. It must not be refilled per value: Firestore replays the
/// cached snapshot before the server's denial arrives, so a real denial
/// (signed out, removed from a group) would otherwise retry forever.
Stream<T> retryOnPermissionDenied<T>(
  Stream<T> Function() streamBuilder, {
  int maxRetries = 3,
  Duration retryDelay = const Duration(milliseconds: 300),
  Duration healthyAfter = const Duration(seconds: 10),
}) async* {
  var retries = 0;
  while (true) {
    final alive = Stopwatch()..start();
    try {
      await for (final val in streamBuilder()) {
        yield val;
      }
      return;
    } catch (e) {
      final denied = e is FirebaseException && e.code == 'permission-denied';
      if (alive.elapsed >= healthyAfter) retries = 0;
      if (denied && retries < maxRetries) {
        retries++;
        await Future.delayed(retryDelay * retries);
        continue;
      }
      rethrow;
    }
  }
}

/// Splits [items] into chunks (Firestore batches max out at 500 writes).
Iterable<List<T>> chunked<T>(List<T> items, int size) sync* {
  for (var i = 0; i < items.length; i += size) {
    yield items.sublist(i, i + size > items.length ? items.length : i + size);
  }
}
