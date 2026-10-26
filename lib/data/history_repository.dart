import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/place_model.dart';

class HistoryRepository {
  static CollectionReference<Map<String, dynamic>>? _historyCollection() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('history');
  }

  static Future<void> addViewedPlace(Place place) async {
    final collection = _historyCollection();
    if (collection == null) return;

    await collection.doc(_historyDocumentId(place)).set({
      'place': place.toJson(),
      'viewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String _historyDocumentId(Place place) {
    final rawId = place.documentId.trim().isNotEmpty
        ? place.documentId
        : place.sourceRow != null
        ? 'sourceRow_${place.sourceRow}'
        : place.id.trim().isNotEmpty
        ? place.id
        : place.name;
    return rawId.replaceAll(RegExp(r'[/#?\[\]]'), '_');
  }

  static Future<Set<int>> loadViewedSourceRows() async {
    final collection = _historyCollection();
    if (collection == null) return {};

    final snapshot = await collection.limit(200).get();
    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          final place = data['place'];
          if (place is! Map) return null;
          return (place['sourceRow'] as num?)?.toInt();
        })
        .whereType<int>()
        .toSet();
  }

  static Future<HistoryPreferenceBoost> loadPreferenceBoost() async {
    final collection = _historyCollection();
    if (collection == null) return const HistoryPreferenceBoost.empty();

    final snapshot = await collection
        .orderBy('viewedAt', descending: true)
        .limit(80)
        .get();

    final categoryCounts = <String, int>{};
    final typeCounts = <String, int>{};
    final activityCounts = <String, int>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final rawPlace = data['place'];
      if (rawPlace is! Map) continue;

      final place = Place.fromJson(Map<String, dynamic>.from(rawPlace));
      for (final category in _splitActivities(place.category)) {
        _increaseCount(categoryCounts, category);
      }
      for (final type in _splitActivities(place.type)) {
        _increaseCount(typeCounts, type);
      }
      for (final activity in _splitActivities(place.activity)) {
        _increaseCount(activityCounts, activity);
      }
    }

    return HistoryPreferenceBoost(
      categories: _topValues(categoryCounts, limit: 3),
      types: _topValues(typeCounts, limit: 5),
      activities: _topValues(activityCounts, limit: 5),
    );
  }

  static void _increaseCount(Map<String, int> counts, String value) {
    final key = value.trim();
    if (key.isEmpty) return;
    counts[key] = (counts[key] ?? 0) + 1;
  }

  static List<String> _splitActivities(String value) {
    return value
        .split(RegExp(r'[,/|;]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<String> _topValues(
    Map<String, int> counts, {
    required int limit,
  }) {
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return a.key.compareTo(b.key);
      });

    return entries.take(limit).map((entry) => entry.key).toList();
  }

  static Stream<List<HistoryItem>> watchHistory() {
    final collection = _historyCollection();
    if (collection == null) {
      return Stream.value(const []);
    }

    return collection
        .orderBy('viewedAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return HistoryItem(
              id: doc.id,
              place: Place.fromJson(
                Map<String, dynamic>.from(data['place'] as Map? ?? const {}),
              ),
              viewedAt: (data['viewedAt'] as Timestamp?)?.toDate(),
            );
          }).toList(),
        );
  }

  static Future<void> clearHistory() async {
    final collection = _historyCollection();
    if (collection == null) return;

    final snapshot = await collection.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

class HistoryPreferenceBoost {
  final List<String> categories;
  final List<String> types;
  final List<String> activities;

  const HistoryPreferenceBoost({
    required this.categories,
    required this.types,
    required this.activities,
  });

  const HistoryPreferenceBoost.empty()
    : categories = const [],
      types = const [],
      activities = const [];

  List<String> get keywords {
    return [...categories, ...types, ...activities];
  }

  bool get isEmpty => categories.isEmpty && types.isEmpty && activities.isEmpty;
}

class HistoryItem {
  final String id;
  final Place place;
  final DateTime? viewedAt;

  const HistoryItem({
    required this.id,
    required this.place,
    required this.viewedAt,
  });
}
