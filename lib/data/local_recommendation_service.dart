import '../models/place_model.dart';
import '../models/recommendation_preferences.dart';
import 'history_repository.dart';

class LocalRecommendationService {
  static List<Place> fallbackRecommendation({
    required List<Place> places,
    required RecommendationPreferences preferences,
    required HistoryPreferenceBoost historyBoost,
  }) {
    final scoredPlaces =
        places
            .where((place) => _matchesLocation(place, preferences))
            .map(
              (place) => _ScoredPlace(
                place,
                _scorePlace(
                  place: place,
                  preferences: preferences,
                  historyBoost: historyBoost,
                ),
              ),
            )
            .where((item) => item.score > 0)
            .toList()
          ..sort((a, b) {
            final scoreCompare = b.score.compareTo(a.score);
            if (scoreCompare != 0) return scoreCompare;
            return a.place.name.compareTo(b.place.name);
          });

    return scoredPlaces.map((item) => item.place).toList();
  }

  static bool _matchesLocation(
    Place place,
    RecommendationPreferences preferences,
  ) {
    if (preferences.provinces.isNotEmpty &&
        !preferences.provinces.contains(place.province)) {
      return false;
    }

    return true;
  }

  static int _scorePlace({
    required Place place,
    required RecommendationPreferences preferences,
    required HistoryPreferenceBoost historyBoost,
  }) {
    var score = 0;
    Set<String> features(String value) => value
        .split(RegExp(r'[,|;]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    final categories = features(place.category);
    final types = features(place.type);
    final activities = features(place.activity);

    if (preferences.categories.any(categories.contains)) {
      score += 3;
    }

    if (preferences.types.any(types.contains)) {
      score += 3;
    }

    for (final activity in preferences.activities) {
      if (activities.contains(activity)) {
        score += 4;
      }
    }

    if (historyBoost.categories.any(categories.contains)) {
      score += 2;
    }

    if (historyBoost.types.any(types.contains)) {
      score += 3;
    }

    for (final activity in historyBoost.activities) {
      if (activities.contains(activity)) {
        score += 2;
      }
    }

    return score;
  }
}

class _ScoredPlace {
  final Place place;
  final int score;

  const _ScoredPlace(this.place, this.score);
}
