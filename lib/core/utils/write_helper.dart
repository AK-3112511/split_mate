import 'dart:async';
import 'package:flutter/foundation.dart';

enum WriteOutcome {
  /// The server confirmed the write.
  synced,

  /// The write is queued locally (offline / slow network) and will sync later.
  pending,
}

/// Firestore write futures only complete after the *server* acknowledges them,
/// so offline they would hang forever. This waits briefly, then lets the UI move
/// on while Firestore keeps the write queued.
///
/// Errors that happen within [timeout] are rethrown so the caller can show them.
Future<WriteOutcome> commitWithTimeout(
  Future<void> write, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  try {
    await write.timeout(timeout);
    return WriteOutcome.synced;
  } on TimeoutException {
    unawaited(write.catchError((Object e) {
      debugPrint('Queued write failed later: $e');
    }));
    return WriteOutcome.pending;
  }
}

/// Fire-and-forget for best-effort side effects (notifications, scans, activity).
void runInBackground(Future<void> Function() task, {String label = 'task'}) {
  unawaited(Future<void>(() async {
    try {
      await task();
    } catch (e) {
      debugPrint('Background $label failed: $e');
    }
  }));
}
