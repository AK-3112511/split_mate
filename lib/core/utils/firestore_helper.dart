import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Wraps a Firestore stream and re-subscribes after a transient
/// 'permission-denied' (happens right after sign-in while the auth token
/// propagates). Other errors, or repeated denials, are surfaced to the UI.
Stream<T> retryOnPermissionDenied<T>(Stream<T> Function() streamBuilder) async* {
  var retries = 0;
  while (true) {
    try {
      await for (final val in streamBuilder()) {
        yield val;
        retries = 0;
      }
      return;
    } catch (e) {
      final denied = e is FirebaseException && e.code == 'permission-denied';
      if (denied && retries < 3) {
        retries++;
        await Future.delayed(Duration(milliseconds: 300 * retries));
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
