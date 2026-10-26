import 'dart:convert';

import '../models/province_notification.dart';

class ProvinceUpdateRecord {
  final String id;
  final String province;
  final String name;
  final Map<String, dynamic> content;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  const ProvinceUpdateRecord({
    required this.id,
    required this.province,
    required this.name,
    required this.content,
    this.updatedAt,
    this.createdAt,
  });

  String get fingerprint {
    // Stable across app restarts and platforms; ignore map insertion order.
    dynamic canonical(dynamic value) {
      if (value is Map) {
        final keys = value.keys.map((key) => key.toString()).toList()..sort();
        return {for (final key in keys) key: canonical(value[key])};
      }
      if (value is List) return value.map(canonical).toList();
      return value;
    }

    final bytes = utf8.encode(jsonEncode(canonical(content)));
    var first = 17;
    var second = 23;
    for (final byte in bytes) {
      first = (first * 31 + byte) & 0x7fffffff;
      second = (second * 131 + byte) & 0x7fffffff;
    }
    return '${first.toRadixString(16).padLeft(8, '0')}${second.toRadixString(16).padLeft(8, '0')}';
  }
}

class ProvinceNotificationTracker {
  static const maxItems = 50;

  static bool sameState(dynamic left, dynamic right) {
    dynamic canonical(dynamic value) {
      if (value is Map) {
        final keys = value.keys.cast<String>().toList()..sort();
        return {for (final key in keys) key: canonical(value[key])};
      }
      if (value is List) return value.map(canonical).toList();
      return value;
    }

    return jsonEncode(canonical(left)) == jsonEncode(canonical(right));
  }

  static Map<String, dynamic> map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static Map<String, dynamic> reconcile(
    dynamic previous,
    List<String> provinces,
    DateTime now,
  ) {
    final state = map(previous);
    final oldSubscriptions = map(state['subscriptions']);
    final selected = provinces
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toSet();
    final subscriptions = {
      for (final province in selected)
        province: oldSubscriptions[province] ?? now.toUtc().toIso8601String(),
    };
    final checkpoints = map(state['checkpoints'])
      ..removeWhere((key, value) {
        final checkpoint = map(value);
        return subscriptions[checkpoint['province']] !=
            checkpoint['generation'];
      });
    final items = _items(
      state,
    ).where((item) => subscriptions[item.province] == item.generation).toList();
    return {
      'subscriptions': subscriptions,
      'checkpoints': checkpoints,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  static List<ProvinceNotification> _items(Map<String, dynamic> state) =>
      (state['items'] as List? ?? [])
          .map((item) => ProvinceNotification.fromJson(map(item)))
          .toList();

  static List<ProvinceNotification> visibleItems(
    dynamic raw,
    List<String> provinces,
  ) {
    final state = map(raw);
    final subscriptions = map(state['subscriptions']);
    final items =
        _items(state)
            .where(
              (item) =>
                  provinces.contains(item.province) &&
                  subscriptions[item.province] == item.generation,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  static Map<String, dynamic> applySnapshot({
    required Map<String, dynamic> state,
    required String source,
    required String province,
    required String generation,
    required List<ProvinceUpdateRecord> records,
    required DateTime now,
  }) {
    if (map(state['subscriptions'])[province] != generation) return state;
    final checkpoints = map(state['checkpoints']);
    final key = '$source:$province';
    final old = map(checkpoints[key]);
    final hasBaseline = old['generation'] == generation;
    final previous = hasBaseline ? map(old['records']) : <String, dynamic>{};
    final startedAt = DateTime.tryParse(generation) ?? now;
    final current = <String, String>{};
    final items = _items(state);
    var revision = old['revision'] as int? ?? 0;
    for (final record in records) {
      if (record.province != province) continue;
      final fingerprint = record.fingerprint;
      current[record.id] = fingerprint;
      final changed = hasBaseline
          ? previous[record.id] != fingerprint
          : record.updatedAt?.isAfter(startedAt) == true;
      if (!changed) continue;
      revision++;
      final isNew = hasBaseline
          ? !previous.containsKey(record.id)
          : record.createdAt?.isAfter(startedAt) == true;
      final video = source == 'videos';
      items.add(
        ProvinceNotification(
          id: '$source:${record.id}:$generation:$revision',
          source: source,
          sourceId: record.id,
          province: province,
          generation: generation,
          title: video
              ? (isNew
                    ? 'New videos in $province'
                    : 'Videos updated in $province')
              : (isNew
                    ? 'New attractions in $province'
                    : 'Attraction information updated in $province'),
          message: record.name,
          createdAt:
              record.updatedAt != null && record.updatedAt!.isAfter(startedAt)
              ? record.updatedAt!
              : now,
        ),
      );
    }
    checkpoints[key] = {
      'province': province,
      'generation': generation,
      'records': current,
      'revision': revision,
    };
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return {
      ...state,
      'checkpoints': checkpoints,
      'items': items.take(maxItems).map((item) => item.toJson()).toList(),
    };
  }

  static Map<String, dynamic> markRead(dynamic raw, Set<String> ids) {
    final state = map(raw);
    return {
      ...state,
      'items': _items(state)
          .map(
            (item) => {
              ...item.toJson(),
              'isRead': item.isRead || ids.contains(item.id),
            },
          )
          .toList(),
    };
  }
}
