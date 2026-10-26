import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/models/province_notification.dart';
import 'package:travel_taiwan/widgets/home_notifications_button.dart';

void main() {
  testWidgets(
    'province alerts are filtered, marked read and open their source',
    (tester) async {
      final controller =
          StreamController<List<ProvinceNotification>>.broadcast();
      addTearDown(controller.close);
      final item = ProvinceNotification(
        id: '1',
        source: 'videos',
        sourceId: 'clip1',
        province: 'Taipei City',
        generation: 'today',
        title: 'New videos in Taipei City',
        message: '陽明山',
        createdAt: DateTime.utc(2026, 10, 21),
      );
      final other = ProvinceNotification(
        id: '2',
        source: 'attractions',
        sourceId: 'a1',
        province: 'Kaohsiung City',
        generation: 'today',
        title: 'Kaohsiung City updated',
        message: 'Destination not selected',
        createdAt: DateTime.utc(2026, 10, 21),
      );
      ProvinceNotification? opened;
      final marked = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeNotificationsButton(
              notifications: controller.stream,
              selectedProvinces: const ['Taipei City'],
              onMarkRead: (ids) async {
                marked.addAll(ids);
                controller.add([
                  ProvinceNotification.fromJson({
                    ...item.toJson(),
                    'isRead': true,
                  }),
                  other,
                ]);
              },
              onOpenNotification: (notification) async {
                opened = notification;
              },
            ),
          ),
        ),
      );
      controller.add([item, other]);
      await tester.pump();
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('New videos in Taipei City'), findsOneWidget);
      expect(find.text('Kaohsiung City updated'), findsNothing);
      expect(marked, ['1']);
      expect(
        tester
            .widget<Badge>(find.byType(Badge, skipOffstage: false))
            .isLabelVisible,
        isFalse,
      );
      await tester.tap(find.text('New videos in Taipei City'));
      await tester.pumpAndSettle();
      expect(opened?.sourceId, 'clip1');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an empty feed does not fabricate recommendation notifications', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeNotificationsButton(
            notifications: Stream<List<ProvinceNotification>>.value(
              const [],
            ).asBroadcastStream(),
            selectedProvinces: const ['Taipei City'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    expect(
      find.text('No new updates in your selected destinations'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'feed errors are visible instead of displaying a misleading empty list',
    (tester) async {
      final stream = Stream<List<ProvinceNotification>>.error(
        StateError('offline'),
      ).asBroadcastStream();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeNotificationsButton(
              notifications: stream,
              selectedProvinces: const ['Taipei City'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not load notifications'),
        findsOneWidget,
      );
    },
  );
}
