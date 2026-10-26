import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/data/history_repository.dart';
import 'package:travel_taiwan/data/local_recommendation_service.dart';
import 'package:travel_taiwan/models/place_model.dart';
import 'package:travel_taiwan/models/recommendation_preferences.dart';

void main() {
  const preferences = RecommendationPreferences(
    provinces: ['Taipei City', 'Kaohsiung City'],
    categories: ['Nature'],
    types: ['Parks'],
    activities: ['Walking'],
  );

  test('complete city-only preferences roundtrip without a region', () {
    expect(preferences.isComplete, isTrue);
    expect(preferences.toJson().containsKey('regions'), isFalse);
    expect(
      RecommendationPreferences.fromJson(preferences.toJson()).isComplete,
      isTrue,
    );
    final legacy = RecommendationPreferences.fromJson({
      ...preferences.toJson(),
      'regions': ['Northern Taiwan'],
    });
    expect(legacy.toJson(), preferences.toJson());
  });

  test(
    'recommendations use selected cities regardless of attraction region',
    () {
      final places = ['Taipei City', 'Kaohsiung City', 'Tainan City']
          .map(
            (city) => Place.fromJson({
              'id': city,
              'nameTh': city,
              'province': city,
              'category': 'Nature',
              'region': '',
              'type': 'Parks',
              'activity': 'Walking',
            }),
          )
          .toList();
      final results = LocalRecommendationService.fallbackRecommendation(
        places: places,
        preferences: preferences,
        historyBoost: const HistoryPreferenceBoost.empty(),
      );
      expect(
        results.map((p) => p.province),
        unorderedEquals(preferences.provinces),
      );
    },
  );
}
