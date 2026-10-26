import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place_model.dart';
import '../models/recommendation_preferences.dart';

class RecommendationRepository {
  static const String _baseUrl = String.fromEnvironment(
    'RECOMMENDATION_API_URL',
    defaultValue: '',
  );

  static bool get isConfigured => _baseUrl.isNotEmpty;

  /// Scores are model metadata, not stars or a probability of user satisfaction.
  static Future<List<Place>> recommendPlaces({
    required RecommendationPreferences preferences,
    required List<Place> places,
    http.Client? client,
    String? baseUrl,
  }) async {
    final endpoint = (baseUrl ?? _baseUrl).replaceAll(RegExp(r'/+$'), '');
    if (endpoint.isEmpty) {
      throw StateError('Taiwan recommendation service is not configured.');
    }
    if (!preferences.hasDemographics ||
        preferences.categories.isEmpty ||
        preferences.types.isEmpty ||
        preferences.activities.isEmpty) {
      throw StateError('Complete age, gender and all three interest groups.');
    }
    final requestBody = jsonEncode({
      'preferred_cities_en': preferences.provinces,
      'preferred_categories_en': preferences.categories,
      'preferred_types_en': preferences.types,
      'preferred_activities_en': preferences.activities,
      'age': preferences.age,
      'gender': preferences.gender,
      'limit': 10,
    });
    final uri = Uri.parse('$endpoint/recommend');
    final headers = {'Content-Type': 'application/json; charset=UTF-8'};
    final response =
        await (client == null
                ? http.post(uri, headers: headers, body: requestBody)
                : client.post(uri, headers: headers, body: requestBody))
            .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception(
        'Recommendation API returned HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic> ||
        decoded['results'] is! List ||
        decoded['modelVersion'] is! String ||
        (decoded['modelVersion'] as String).isEmpty) {
      throw const FormatException('Recommendation API returned invalid data.');
    }
    final results = decoded['results'] as List<dynamic>;
    final total = decoded['total'];
    final eligiblePool = decoded['eligiblePool'];
    if (total is! int ||
        total != results.length ||
        results.length > 10 ||
        eligiblePool is! int ||
        eligiblePool < total) {
      throw const FormatException(
        'Recommendation API returned invalid counts.',
      );
    }

    final placesById = <String, Place>{};
    for (final place in places) {
      for (final id in {
        place.id,
        place.documentId,
      }.where((id) => id.isNotEmpty)) {
        final existing = placesById[id];
        if (existing != null && !identical(existing, place)) {
          throw const FormatException(
            'Catalog contains duplicate attraction IDs.',
          );
        }
        placesById[id] = place;
      }
    }

    final seen = <String>{};
    final rankedPlaces = <Place>[];
    for (var index = 0; index < results.length; index++) {
      final result = results[index];
      if (result is! Map<String, dynamic>) {
        throw const FormatException(
          'Recommendation API returned an invalid item.',
        );
      }
      final id = result['attractionId'];
      final probability = result['knnRuleProbability'];
      final hasRating = result['hasRealRating'];
      final rating = result['avgRating'];
      final reviewCount = result['reviewCount'];
      if (id is! String ||
          id.isEmpty ||
          !seen.add(id) ||
          result['rank'] != index + 1 ||
          probability is! num ||
          !probability.isFinite ||
          probability < 0 ||
          probability > 1 ||
          hasRating is! bool) {
        throw const FormatException(
          'Recommendation API returned invalid ranking metadata.',
        );
      }
      if (hasRating) {
        if (rating is! num ||
            !rating.isFinite ||
            rating <= 0 ||
            rating > 5 ||
            reviewCount is! int ||
            reviewCount < 0) {
          throw const FormatException(
            'Recommendation API returned invalid rating metadata.',
          );
        }
      } else if (rating != null || reviewCount != null) {
        throw const FormatException(
          'An unrated attraction must have null rating metadata.',
        );
      }
      final place = placesById[id];
      if (place == null) {
        throw FormatException(
          'Recommended attraction is missing from the catalog: $id.',
        );
      }
      if (preferences.provinces.isNotEmpty &&
          !preferences.provinces.contains(place.province)) {
        throw const FormatException(
          'Recommendation is outside the selected destinations.',
        );
      }
      rankedPlaces.add(place);
    }
    return List<Place>.unmodifiable(rankedPlaces);
  }
}
