import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/data/history_repository.dart';
import 'package:travel_taiwan/data/local_recommendation_service.dart';
import 'package:travel_taiwan/models/place_model.dart';
import 'package:travel_taiwan/models/recommendation_preferences.dart';

void main() {
  test(
    'Chinese display name and canonical ID survive history serialization',
    () {
      final place = Place.fromJson({
        'id': 'Attraction_1',
        'documentId': 'Attraction_1',
        'nameZhTw': '\u592a\u5e73\u5c71',
        'nameTh': 'legacy',
        'province': 'Yilan County',
        'images': ['https://example.com/forest.jpg'],
      });
      expect(place.name, '\u592a\u5e73\u5c71');
      final restored = Place.fromJson(place.toJson());
      expect(restored.name, place.name);
      expect(restored.id, 'Attraction_1');
      expect(restored.documentId, 'Attraction_1');
      expect(restored.images, place.images);
    },
  );

  test('matches individual categories/types, not substrings of activities', () {
    Place place(String id, String category, String type, String activity) =>
        Place.fromJson({
          'id': id,
          'nameZhTw': id,
          'province': 'Taipei City',
          'category': category,
          'type': type,
          'activity': activity,
        });
    const preferences = RecommendationPreferences(
      provinces: ['Taipei City'],
      categories: ['Nature'],
      types: ['Parks'],
      activities: ['Walking'],
    );
    final results = LocalRecommendationService.fallbackRecommendation(
      places: [
        place('category', 'Culture | Nature', '', ''),
        place('type', '', 'Forest | Parks', ''),
        place('activity', '', '', 'Photography | Walking'),
        place('not-a-match', '', '', 'Walking and hiking'),
      ],
      preferences: preferences,
      historyBoost: const HistoryPreferenceBoost.empty(),
    );
    expect(
      results.map((place) => place.id),
      unorderedEquals(['category', 'type', 'activity']),
    );
  });
}
