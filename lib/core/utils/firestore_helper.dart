import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper to wrap Firestore streams and retry them if they fail with a
/// transient 'permission-denied' error due to token synchronization latency.
Stream<T> retryOnPermissionDenied<T>(Stream<T> Function() streamBuilder) async* {
  int retries = 0;
  while (true) {
    try {
      await for (final val in streamBuilder()) {
        yield val;
        retries = 0; // Reset retries on successful emission
      }
      break; // Stream completed normally
    } catch (e) {
      final isPermissionDenied = e is FirebaseException && e.code == 'permission-denied';
      if (isPermissionDenied && retries < 4) {
        retries++;
        // Back off progressively: 300ms, 600ms, 900ms, 1200ms
        await Future.delayed(Duration(milliseconds: 300 * retries));
        continue; // Retry stream subscription
      }
      rethrow; // Rethrow if it's a different error or out of retries
    }
  }
}
