import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/data/province_notification_tracker.dart';

void main() {
  final start = DateTime.utc(2026, 10, 21, 10);
  late Map<String, dynamic> state;
  late String generation;

  ProvinceUpdateRecord record(
    String id,
    String description, {
    String province = 'Kaohsiung City',
    DateTime? updated,
  }) => ProvinceUpdateRecord(
    id: id,
    province: province,
    name: '景點 $id',
    content: {'description': description},
    updatedAt: updated,
  );

  Map<String, dynamic> apply(
    List<ProvinceUpdateRecord> records, {
    String source = 'attractions',
    Map<String, dynamic>? current,
  }) => ProvinceNotificationTracker.applySnapshot(
    state: current ?? state,
    source: source,
    province: 'Kaohsiung City',
    generation: generation,
    records: records,
    now: start.add(const Duration(minutes: 10)),
  );

  setUp(() {
    state = ProvinceNotificationTracker.reconcile(null, [
      'Kaohsiung City',
    ], start);
    generation =
        ProvinceNotificationTracker.map(
              state['subscriptions'],
            )['Kaohsiung City']
            as String;
  });

  test(
    'existing data establishes a baseline without old recommendations as notifications',
    () {
      state = apply([record('1', 'original')]);
      expect(
        ProvinceNotificationTracker.visibleItems(state, ['Kaohsiung City']),
        isEmpty,
      );
      state = apply([record('1', 'original')]);
      expect(
        ProvinceNotificationTracker.visibleItems(state, ['Kaohsiung City']),
        isEmpty,
      );
    },
  );

  test(
    'changed data and new videos generate distinct alerts only for selected provinces',
    () {
      state = apply([record('1', 'original')]);
      state = apply([
        record('1', 'updated content'),
        record('elsewhere', 'new', province: 'Taipei City'),
      ]);
      var items = ProvinceNotificationTracker.visibleItems(state, [
        'Kaohsiung City',
      ]);
      expect(items, hasLength(1));
      expect(items.single.title, contains('Attraction information'));
      expect(items.single.sourceId, '1');
      state = apply([], source: 'videos');
      state = apply([record('clip', 'new video')], source: 'videos');
      items = ProvinceNotificationTracker.visibleItems(state, [
        'Kaohsiung City',
      ]);
      expect(items, hasLength(2));
      expect(
        items.where((item) => item.isVideo).single.title,
        contains('New videos'),
      );
      expect(
        ProvinceNotificationTracker.visibleItems(state, ['Taipei City']),
        isEmpty,
      );
    },
  );

  test(
    'a video edit creates an update while unchanged snapshots do not duplicate alerts',
    () {
      state = apply([record('clip', 'original')], source: 'videos');
      state = apply([record('clip', 'แก้Caption')], source: 'videos');
      final item = ProvinceNotificationTracker.visibleItems(state, [
        'Kaohsiung City',
      ]).single;
      expect(item.title, contains('updated'));
      state = apply([record('clip', 'แก้Caption')], source: 'videos');
      expect(
        ProvinceNotificationTracker.visibleItems(state, ['Kaohsiung City']),
        hasLength(1),
      );
    },
  );

  test(
    'serialized checkpoints detect updates made while the app was closed',
    () {
      state = apply([record('1', 'original')]);
      state = Map<String, dynamic>.from(jsonDecode(jsonEncode(state)) as Map);
      state = apply([record('1', 'new')]);
      expect(
        ProvinceNotificationTracker.visibleItems(state, ['Kaohsiung City']),
        hasLength(1),
      );
      final id = ProvinceNotificationTracker.visibleItems(state, [
        'Kaohsiung City',
      ]).single.id;
      state = ProvinceNotificationTracker.markRead(state, {id});
      state = Map<String, dynamic>.from(jsonDecode(jsonEncode(state)) as Map);
      expect(
        ProvinceNotificationTracker.visibleItems(state, [
          'Kaohsiung City',
        ]).single.isRead,
        isTrue,
      );
    },
  );

  test(
    'deselecting a province removes its alerts and rejects stale listeners after reselecting',
    () {
      state = apply([record('1', 'original')]);
      state = apply([record('1', 'new')]);
      state = ProvinceNotificationTracker.reconcile(state, [
        'Taipei City',
      ], start.add(const Duration(hours: 1)));
      expect(
        ProvinceNotificationTracker.visibleItems(state, ['Kaohsiung City']),
        isEmpty,
      );
      expect(ProvinceNotificationTracker.map(state['checkpoints']), isEmpty);
      state = ProvinceNotificationTracker.reconcile(state, [
        'Kaohsiung City',
      ], start.add(const Duration(hours: 2)));
      final rejected = apply([record('1', 'old subscription')]);
      expect(rejected, same(state));
    },
  );

  test(
    'timestamped updates since selection are retained on the first server snapshot',
    () {
      state = apply([
        record('1', 'new', updated: start.add(const Duration(minutes: 1))),
      ]);
      expect(
        ProvinceNotificationTracker.visibleItems(state, ['Kaohsiung City']),
        hasLength(1),
      );
    },
  );

  test(
    'initial snapshot distinguishes a new video from an older video edited since selection',
    () {
      final recent = start.add(const Duration(minutes: 1));
      state = apply([
        ProvinceUpdateRecord(
          id: 'new',
          province: 'Kaohsiung City',
          name: 'new video',
          content: const {'caption': 'new'},
          createdAt: recent,
          updatedAt: recent,
        ),
        ProvinceUpdateRecord(
          id: 'edited',
          province: 'Kaohsiung City',
          name: 'edited video',
          content: const {'caption': 'edited'},
          createdAt: start.subtract(const Duration(days: 1)),
          updatedAt: recent,
        ),
      ], source: 'videos');
      final items = ProvinceNotificationTracker.visibleItems(state, [
        'Kaohsiung City',
      ]);
      expect(
        items.firstWhere((item) => item.sourceId == 'new').title,
        contains('New videos'),
      );
      expect(
        items.firstWhere((item) => item.sourceId == 'edited').title,
        contains('updated'),
      );
    },
  );

  test(
    'read status only changes requested alerts and unrelated preferences preserve subscriptions',
    () {
      state = apply([]);
      state = apply([record('1', 'new'), record('2', 'new')]);
      final items = ProvinceNotificationTracker.visibleItems(state, [
        'Kaohsiung City',
      ]);
      state = ProvinceNotificationTracker.markRead(state, {items.first.id});
      state = ProvinceNotificationTracker.reconcile(state, [
        'Kaohsiung City',
      ], start.add(const Duration(days: 1)));
      expect(
        ProvinceNotificationTracker.map(
          state['subscriptions'],
        )['Kaohsiung City'],
        generation,
      );
      expect(
        ProvinceNotificationTracker.visibleItems(state, [
          'Kaohsiung City',
        ]).where((item) => item.isRead),
        hasLength(1),
      );
    },
  );

  test('deletions are silent and notification history is bounded', () {
    state = apply([record('1', 'original')]);
    state = apply([]);
    expect(
      ProvinceNotificationTracker.visibleItems(state, ['Kaohsiung City']),
      isEmpty,
    );
    state = apply(List.generate(60, (index) => record('$index', 'new')));
    expect(
      ProvinceNotificationTracker.visibleItems(state, ['Kaohsiung City']),
      hasLength(50),
    );
  });

  test(
    'Firestore map key ordering does not cause repeated checkpoint writes',
    () {
      expect(
        ProvinceNotificationTracker.sameState(
          {
            'subscriptions': {'Kaohsiung City': generation},
            'checkpoints': {},
            'items': [],
          },
          {
            'items': [],
            'checkpoints': {},
            'subscriptions': {'Kaohsiung City': generation},
          },
        ),
        isTrue,
      );
    },
  );

  test('fingerprints ignore field order and detect actual content changes', () {
    const a = ProvinceUpdateRecord(
      id: 'a',
      province: 'Kaohsiung City',
      name: 'a',
      content: {
        'name': 'a',
        'images': ['1', '2'],
      },
    );
    const b = ProvinceUpdateRecord(
      id: 'a',
      province: 'Kaohsiung City',
      name: 'a',
      content: {
        'images': ['1', '2'],
        'name': 'a',
      },
    );
    expect(a.fingerprint, b.fingerprint);
    expect(a.fingerprint, isNot(record('a', 'new').fingerprint));
  });
}
