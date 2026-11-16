import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/core/utils/firestore_helper.dart';

FirebaseException _denied() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

void main() {
  group('retryOnPermissionDenied', () {
    test('gives up when every attempt replays a cached value then is denied', () async {
      // Firestore emits the cached snapshot first, then the server denial.
      var subscriptions = 0;
      Stream<int> cachedThenDenied() async* {
        subscriptions++;
        yield subscriptions;
        throw _denied();
      }

      await expectLater(
        retryOnPermissionDenied(cachedThenDenied, retryDelay: Duration.zero),
        emitsInOrder([1, 2, 3, 4, emitsError(isA<FirebaseException>())]),
      );
      expect(subscriptions, 4); // first try + 3 retries, not an endless loop
    });

    test('recovers from a transient denial right after sign-in', () async {
      var subscriptions = 0;
      Stream<String> flaky() async* {
        subscriptions++;
        if (subscriptions <= 2) throw _denied();
        yield 'ok';
      }

      final values =
          await retryOnPermissionDenied(flaky, retryDelay: Duration.zero).toList();
      expect(values, ['ok']);
      expect(subscriptions, 3);
    });

    test('other errors are not retried', () async {
      var subscriptions = 0;
      Stream<int> broken() async* {
        subscriptions++;
        throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      }

      await expectLater(
        retryOnPermissionDenied(broken, retryDelay: Duration.zero),
        emitsError(isA<FirebaseException>()),
      );
      expect(subscriptions, 1);
    });

    test('budget refills after a long healthy subscription', () async {
      var subscriptions = 0;
      Stream<int> source() async* {
        subscriptions++;
        // 1-2: fast denials use up 2 of 3 retries. 3: healthy, then denied ->
        // budget refilled. 4: fast denial. 5: succeeds. Without the refill
        // attempt 4 would exhaust the budget and the stream would error.
        if (subscriptions == 3) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
        if (subscriptions == 5) {
          yield 5;
          return;
        }
        throw _denied();
      }

      final values = await retryOnPermissionDenied(
        source,
        retryDelay: Duration.zero,
        maxRetries: 3,
        healthyAfter: const Duration(milliseconds: 20),
      ).toList();
      expect(values, [5]);
      expect(subscriptions, 5);
    });
  });
}
