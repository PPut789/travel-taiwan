import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/data/recommendation_session.dart';
import 'package:travel_taiwan/models/place_model.dart';
import 'package:travel_taiwan/models/recommendation_preferences.dart';

const _preferences = RecommendationPreferences(
  provinces: ['Taipei City', 'Tainan City'],
  categories: ['Nature'],
  types: ['Parks'],
  activities: ['Walking'],
);

RecommendationSnapshot _snapshot(List<String> ids) {
  final places = ids.map((id) => Place.fromJson({'id': id})).toList();
  return RecommendationSnapshot(allPlaces: places, recommendedPlaces: places);
}

void main() {
  test(
    'page reentry keeps exactly the same ordered attraction results',
    () async {
      final session = RecommendationSession();
      var calls = 0;
      Future<RecommendationSnapshot> load() => session.load(
        userId: 'user-a',
        preferences: _preferences,
        loader: () async {
          calls++;
          return _snapshot(calls == 1 ? ['A', 'C', 'B'] : ['B', 'A', 'C']);
        },
      );

      final first = await load();
      final reopenedHome = await load();
      expect(reopenedHome, same(first));
      expect(reopenedHome.recommendedPlaces.map((p) => p.id), ['A', 'C', 'B']);
      expect(calls, 1);
    },
  );

  test(
    'new search regenerates even when submitted interests are unchanged',
    () async {
      final session = RecommendationSession();
      var calls = 0;
      Future<RecommendationSnapshot> load() => session.load(
        userId: 'user-a',
        preferences: _preferences,
        loader: () async => _snapshot(['result-${++calls}']),
      );

      await load();
      session.beginNewSearch(userId: 'user-a');
      final second = await load();
      expect(second.recommendedPlaces.single.id, 'result-2');
      expect(calls, 2);
    },
  );

  test(
    'accounts have separate results and separate new-search invalidation',
    () async {
      final session = RecommendationSession();
      Future<RecommendationSnapshot> load(String user, String id) =>
          session.load(
            userId: user,
            preferences: _preferences,
            loader: () async => _snapshot([id]),
          );

      await load('user-a', 'A');
      await load('user-b', 'B');
      session.beginNewSearch(userId: 'user-a');
      expect(
        (await load('user-a', 'new A')).recommendedPlaces.single.id,
        'new A',
      );
      expect((await load('user-b', 'new B')).recommendedPlaces.single.id, 'B');
    },
  );

  test('changing selection order does not start another search', () async {
    final session = RecommendationSession();
    final first = await session.load(
      userId: 'user-a',
      preferences: _preferences,
      loader: () async => _snapshot(['A']),
    );
    final reordered = RecommendationPreferences(
      provinces: _preferences.provinces.reversed.toList(),
      categories: _preferences.categories,
      types: _preferences.types,
      activities: _preferences.activities,
    );
    expect(
      await session.load(
        userId: 'user-a',
        preferences: reordered,
        loader: () async => _snapshot(['changed']),
      ),
      same(first),
    );
  });

  test(
    'failed API request can retry rather than retaining its error',
    () async {
      final session = RecommendationSession();
      await expectLater(
        session.load(
          userId: 'user-a',
          preferences: _preferences,
          loader: () async => throw TimeoutException('API offline'),
        ),
        throwsA(isA<TimeoutException>()),
      );
      final result = await session.load(
        userId: 'user-a',
        preferences: _preferences,
        loader: () async => _snapshot(['retried']),
      );
      expect(result.recommendedPlaces.single.id, 'retried');
    },
  );

  test(
    'late response from old search cannot overwrite the new search',
    () async {
      final session = RecommendationSession();
      final pending = Completer<RecommendationSnapshot>();
      final old = session.load(
        userId: 'user-a',
        preferences: _preferences,
        loader: () => pending.future,
      );
      session.beginNewSearch(userId: 'user-a');
      final replacement = await session.load(
        userId: 'user-a',
        preferences: _preferences,
        loader: () async => _snapshot(['new']),
      );
      pending.complete(_snapshot(['old']));
      await old;
      final reopenedHome = await session.load(
        userId: 'user-a',
        preferences: _preferences,
        loader: () async => _snapshot(['unexpected']),
      );
      expect(reopenedHome, same(replacement));
      expect(reopenedHome.recommendedPlaces.single.id, 'new');
    },
  );

  test(
    'concurrent Home loads share one request and cannot mutate its order',
    () async {
      final session = RecommendationSession();
      final pending = Completer<RecommendationSnapshot>();
      var calls = 0;
      Future<RecommendationSnapshot> load() => session.load(
        userId: 'user-a',
        preferences: _preferences,
        loader: () {
          calls++;
          return pending.future;
        },
      );
      final first = load();
      final second = load();
      expect(second, same(first));
      pending.complete(_snapshot(['B', 'A']));
      final result = await first;
      expect(calls, 1);
      expect(() => result.recommendedPlaces.clear(), throwsUnsupportedError);
      expect(result.recommendedPlaces.map((p) => p.id), ['B', 'A']);
    },
  );
}
