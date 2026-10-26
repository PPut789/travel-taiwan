import 'dart:convert';

import 'place_model.dart';

class FavoritePlace {
  final Place place;
  final DateTime savedAt;

  const FavoritePlace({required this.place, required this.savedAt});

  static String keyFor(Place place) {
    final identity = place.documentId.isNotEmpty
        ? 'document:${place.documentId}'
        : place.id.isNotEmpty
        ? 'source:${place.id}'
        : 'place:${place.province}:${place.name}';
    return base64Url.encode(utf8.encode(identity));
  }

  factory FavoritePlace.fromJson(Map<String, dynamic> data) => FavoritePlace(
    place: Place.fromJson(Map<String, dynamic>.from(data['place'] as Map)),
    savedAt: DateTime.fromMillisecondsSinceEpoch(
      data['savedAt'] as int,
      isUtc: true,
    ),
  );

  Map<String, dynamic> toJson() => {
    // Keep the saved preview compact. Details are fetched fresh when opened.
    'place': {
      'documentId': place.documentId,
      'id': place.id,
      'nameTh': place.name,
      'province': place.province,
      'region': place.region,
      'category': place.category,
      'type': place.type,
      'images': place.images.take(1).toList(),
      'assetImages': place.assetImages.take(1).toList(),
    },
    'savedAt': savedAt.millisecondsSinceEpoch,
  };

  static List<FavoritePlace> decode(dynamic data) {
    if (data is! Map) return const [];
    final items =
        data.values
            .map(
              (entry) => FavoritePlace.fromJson(
                Map<String, dynamic>.from(entry as Map),
              ),
            )
            .toList()
          ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return items;
  }

  static Map<String, dynamic> update(
    dynamic previous,
    Place place,
    bool saved,
    DateTime now,
  ) {
    final favorites = previous is Map
        ? Map<String, dynamic>.from(previous)
        : <String, dynamic>{};
    final key = keyFor(place);
    if (saved) {
      favorites.putIfAbsent(
        key,
        () => FavoritePlace(place: place, savedAt: now).toJson(),
      );
    } else {
      favorites.remove(key);
    }
    return favorites;
  }
}
