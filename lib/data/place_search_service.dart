import '../models/place_model.dart';

class PlaceSearchService {
  static List<Place> search(List<Place> places, String rawQuery) {
    final query = normalizeSearchText(rawQuery);
    if (query.isEmpty) return places;

    final searchedPlaces =
        places.where((place) => matchesSearch(place, query)).toList()
          ..sort((a, b) {
            final rankCompare = searchRank(
              a,
              query,
            ).compareTo(searchRank(b, query));
            if (rankCompare != 0) return rankCompare;
            return a.name.compareTo(b.name);
          });

    return searchedPlaces;
  }

  static String normalizeSearchText(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool matchesSearch(Place place, String query) {
    final normalizedQuery = normalizeSearchText(query);
    return _searchFields(place).any((field) => field.contains(normalizedQuery));
  }

  static int searchRank(Place place, String query) {
    final normalizedQuery = normalizeSearchText(query);
    final name = normalizeSearchText(place.name);
    if (name == normalizedQuery) return 0;
    if (name.startsWith(normalizedQuery)) return 1;
    if (name.contains(normalizedQuery)) return 2;
    if (normalizeSearchText(place.province).contains(normalizedQuery)) return 3;
    if (normalizeSearchText(place.type).contains(normalizedQuery)) return 4;
    if (normalizeSearchText(place.activity).contains(normalizedQuery)) return 5;
    return 6;
  }

  static List<String> _searchFields(Place place) {
    return [
      place.name,
      place.province,
      place.region,
      place.category,
      place.type,
      place.activity,
      place.description,
    ].map(normalizeSearchText).toList();
  }
}
