import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/data/request_cache.dart';
import 'package:travel_taiwan/data/optional_history.dart';
import 'package:travel_taiwan/data/history_repository.dart';
import 'package:travel_taiwan/models/interest_choices.dart';

void main() {
  test('simultaneous requests share a single successful fetch', () async {
    final cache = RequestCache<String, int>();
    var calls = 0;
    final pending = Completer<int>();
    Future<int> fetch() {
      calls++;
      return pending.future;
    }

    final first = cache.load('Taipei', fetch);
    final second = cache.load('Taipei', fetch);
    expect(identical(first, second), isTrue);
    pending.complete(12);
    expect(await first, 12);
    expect(await cache.load('Taipei', fetch), 12);
    expect(calls, 1);
  });

  test('a failed request can retry without restarting the app', () async {
    final cache = RequestCache<String, int>();
    await expectLater(
      cache.load('city', () async => throw TimeoutException('offline')),
      throwsA(isA<TimeoutException>()),
    );
    expect(await cache.load('city', () async => 8), 8);
  });

  test(
    'late failure cannot evict a refreshed or different city request',
    () async {
      final cache = RequestCache<String, int>();
      final pending = Completer<int>();
      final old = cache.load('city', () => pending.future);
      final oldError = expectLater(old, throwsStateError);
      expect(await cache.load('city', () async => 9, refresh: true), 9);
      pending.completeError(StateError('old failure'));
      await oldError;
      expect(await cache.load('city', () async => 100), 9);
      expect(await cache.load('another city', () async => 4), 4);
    },
  );

  test('history outage or timeout does not prevent catalog ranking', () async {
    final failed = await optionalHistoryBoost(
      () async => throw StateError('offline'),
    );
    expect(failed.isEmpty, isTrue);
    final stalled = await optionalHistoryBoost(
      () => Completer<HistoryPreferenceBoost>().future,
      timeout: const Duration(milliseconds: 5),
    );
    expect(stalled.isEmpty, isTrue);
    const available = HistoryPreferenceBoost(
      categories: ['Nature'],
      types: [],
      activities: [],
    );
    expect(await optionalHistoryBoost(() async => available), same(available));
  });

  test(
    'interest metadata decodes without downloading attraction documents',
    () {
      final choices = InterestChoices.fromJson({
        'categories': ['Nature', 'Other', 'Nature', ''],
        'types': ['Temples', 'Parks'],
        'activities': ['Photography'],
      });
      expect(choices.categories, ['Nature']);
      expect(choices.types, ['Parks', 'Temples']);
      expect(choices.activities, ['Photography']);
    },
  );
}
