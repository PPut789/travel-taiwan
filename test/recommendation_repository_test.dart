import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travel_taiwan/data/recommendation_repository.dart';
import 'package:travel_taiwan/models/place_model.dart';
import 'package:travel_taiwan/models/recommendation_preferences.dart';

const preferences = RecommendationPreferences(
  provinces: [],
  categories: ['Nature'],
  types: ['Park'],
  activities: ['Photography'],
  age: 27,
  gender: 'Female',
);

Map<String, dynamic> result(String id, int rank, {bool rated = true}) => {
  'attractionId': id,
  'rank': rank,
  'knnRuleProbability': .8,
  'hasRealRating': rated,
  'avgRating': rated ? 4.6 : null,
  'reviewCount': rated ? 12 : null,
};

Map<String, dynamic> envelope(List<dynamic> results, {int? eligiblePool}) => {
  'modelVersion': 'V2.3-test',
  'results': results,
  'total': results.length,
  'eligiblePool': eligiblePool ?? results.length,
};

final places = [
  Place.fromJson({
    'id': 'A1',
    'documentId': 'A1',
    'sourceRow': 999,
    'province': 'Taipei City',
  }),
  Place.fromJson({
    'id': 'B2',
    'documentId': 'B2',
    'sourceRow': 1,
    'province': 'Tainan City',
  }),
];

Future<List<Place>> call(
  Map<String, dynamic> body, {
  RecommendationPreferences prefs = preferences,
  int status = 200,
}) => RecommendationRepository.recommendPlaces(
  preferences: prefs,
  places: places,
  baseUrl: 'http://test.local:8010/',
  client: MockClient((_) async => http.Response(jsonEncode(body), status)),
);

void main() {
  test(
    'sends demographic and model option fields, preserves canonical ID order',
    () async {
      final ordered = await RecommendationRepository.recommendPlaces(
        preferences: preferences,
        places: places,
        baseUrl: 'http://test.local:8010/',
        client: MockClient((request) async {
          expect(request.url.toString(), 'http://test.local:8010/recommend');
          expect(jsonDecode(request.body), {
            'preferred_cities_en': [],
            'preferred_categories_en': ['Nature'],
            'preferred_types_en': ['Park'],
            'preferred_activities_en': ['Photography'],
            'age': 27,
            'gender': 'Female',
            'limit': 10,
          });
          return http.Response(
            jsonEncode(
              envelope([result('B2', 1), result('A1', 2, rated: false)]),
            ),
            200,
          );
        }),
      );
      expect(ordered.map((p) => p.id), ['B2', 'A1']);
      expect(() => ordered.add(places.first), throwsUnsupportedError);
    },
  );

  test(
    'accepts a genuine empty eligible pool and fewer than ten matches',
    () async {
      expect(await call(envelope([])), isEmpty);
      expect((await call(envelope([result('A1', 1)]))).single.id, 'A1');
    },
  );

  test(
    'rejects missing, duplicate and legacy row-only IDs instead of silently dropping them',
    () async {
      for (final body in [
        envelope([result('missing', 1)]),
        envelope([result('A1', 1), result('A1', 2)]),
        envelope([
          {'sourceRow': 999},
        ]),
        envelope([result('A1', 1), null]),
      ]) {
        await expectLater(call(body), throwsFormatException);
      }
    },
  );

  test(
    'rejects inconsistent response totals, pool, ranking and rating metadata',
    () async {
      for (final body in [
        {
          ...envelope([result('A1', 1)]),
          'total': 0,
        },
        envelope([result('A1', 1)], eligiblePool: 0),
        {...envelope([]), 'modelVersion': ''},
        envelope([result('A1', 2)]),
        envelope([
          {...result('A1', 1), 'avgRating': 6},
        ]),
        envelope([
          {...result('A1', 1), 'knnRuleProbability': 1.2},
        ]),
        envelope([
          {...result('A1', 1, rated: false), 'avgRating': 0},
        ]),
      ]) {
        await expectLater(call(body), throwsFormatException);
      }
    },
  );

  test('rejects results outside selected cities and API failures', () async {
    const selectedCity = RecommendationPreferences(
      provinces: ['Taipei City'],
      categories: ['Nature'],
      types: ['Park'],
      activities: ['Photography'],
      age: 27,
      gender: 'Female',
    );
    await expectLater(
      call(envelope([result('B2', 1)]), prefs: selectedCity),
      throwsFormatException,
    );
    await expectLater(call({}, status: 503), throwsException);
  });

  test('requires demographics before any network request', () async {
    const incomplete = RecommendationPreferences(
      provinces: [],
      categories: ['Nature'],
      types: ['Park'],
      activities: ['Photography'],
    );
    await expectLater(call(envelope([]), prefs: incomplete), throwsStateError);
  });
}
