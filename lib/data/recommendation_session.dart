import 'dart:convert';

import '../models/place_model.dart';
import '../models/recommendation_preferences.dart';

/// Keeps a search result through page changes for the current app session.
/// A user must explicitly start a new search to replace a completed result.
class RecommendationSession {
  static final shared = RecommendationSession();

  final _searches = <String, Map<String, Future<RecommendationSnapshot>>>{};

  Future<RecommendationSnapshot> load({
    required String userId,
    required RecommendationPreferences preferences,
    required Future<RecommendationSnapshot> Function() loader,
  }) {
    final searches = _searches.putIfAbsent(userId, () => {});
    final key = _preferencesKey(preferences);
    return searches.putIfAbsent(key, () {
      late final Future<RecommendationSnapshot> request;
      request = Future<RecommendationSnapshot>.sync(loader).then(
        (result) => result,
        onError: (Object error, StackTrace stack) {
          // A late failure from a previous search must not evict its replacement.
          if (identical(searches[key], request)) searches.remove(key);
          Error.throwWithStackTrace(error, stack);
        },
      );
      return request;
    });
  }

  /// Call after saving the submitted interests, before opening the new results.
  /// This also starts a new search when the selections have not changed.
  void beginNewSearch({required String userId}) {
    _searches.remove(userId);
  }

  String _preferencesKey(RecommendationPreferences preferences) {
    List<String> normalized(List<String> values) =>
        values.toSet().toList()..sort();
    return jsonEncode({
      'provinces': normalized(preferences.provinces),
      'categories': normalized(preferences.categories),
      'types': normalized(preferences.types),
      'activities': normalized(preferences.activities),
      'age': preferences.age,
      'gender': preferences.gender,
    });
  }
}

class RecommendationSnapshot {
  final List<Place> allPlaces;
  final List<Place> recommendedPlaces;

  RecommendationSnapshot({
    required List<Place> allPlaces,
    required List<Place> recommendedPlaces,
  }) : allPlaces = List.unmodifiable(allPlaces),
       recommendedPlaces = List.unmodifiable(recommendedPlaces);
}
