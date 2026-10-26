import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/place_model.dart';
import '../models/interest_choices.dart';
import 'request_cache.dart';

class PlaceRepository {
  static Future<Place?> loadPlaceByDocumentId(String id) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('attractions')
        .doc(id)
        .get()
        .timeout(const Duration(seconds: 15));
    final data = snapshot.data();
    return data == null
        ? null
        : Place.fromJson({...data, 'documentId': snapshot.id});
  }

  static final _places = RequestCache<String, List<Place>>();
  static final _choices = RequestCache<String, InterestChoices>();

  static Future<List<Place>> loadPlaces({List<String> provinces = const []}) {
    final cities = provinces.toSet().toList()..sort();
    return _places.load(cities.join('|'), () => _fetchPlaces(cities));
  }

  static Future<List<Place>> refreshPlaces({
    List<String> provinces = const [],
  }) {
    final cities = provinces.toSet().toList()..sort();
    return _places.load(
      cities.join('|'),
      () => _fetchPlaces(cities),
      refresh: true,
    );
  }

  static Future<InterestChoices> loadInterestChoices() =>
      _choices.load('catalog', () async {
        final snapshot = await FirebaseFirestore.instance
            .collection('catalog_metadata')
            .doc('attractions')
            .get()
            .timeout(const Duration(seconds: 10));
        final data = snapshot.data();
        if (data == null) throw StateError('Interest catalog is unavailable.');
        return InterestChoices.fromJson(data);
      });

  static Future<List<Place>> _fetchPlaces(List<String> cities) async {
    final watch = Stopwatch()..start();
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'attractions',
    );
    if (cities.isNotEmpty) query = query.where('province', whereIn: cities);
    final snapshot = await query.get().timeout(const Duration(seconds: 15));
    final places = snapshot.docs.map((doc) {
      final data = doc.data();
      return Place.fromJson({...data, 'documentId': doc.id});
    }).toList()..sort((a, b) => (a.sourceRow ?? 0).compareTo(b.sourceRow ?? 0));
    debugPrint(
      'Catalog loaded: ${places.length} places, ${cities.length} cities, ${watch.elapsedMilliseconds}ms',
    );
    return places;
  }
}
