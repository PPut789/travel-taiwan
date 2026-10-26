import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/models/recommendation_preferences.dart';
import 'package:travel_taiwan/pages/demographics_page.dart';
import 'package:travel_taiwan/pages/location_page.dart';
import 'package:travel_taiwan/widgets/destination_card.dart';
import 'package:travel_taiwan/data/taiwan_geography.dart';
import 'package:travel_taiwan/data/destination_photos.dart';
import 'dart:io';

void main() {
  testWidgets('select cities directly across former regions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LocationPage()));
    await tester.pumpAndSettle();
    expect(find.text('Region'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(DestinationCard), findsNWidgets(22));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.ensureVisible(find.text('Taipei City'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taipei City'));
    await tester.ensureVisible(find.text('Kaohsiung City'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaohsiung City'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DestinationCard>(
            find.byKey(const ValueKey('destination-Taipei City')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<DestinationCard>(
            find.byKey(const ValueKey('destination-Kaohsiung City')),
          )
          .selected,
      isTrue,
    );
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    final interests = tester.widget<DemographicsPage>(
      find.byType(DemographicsPage),
    );
    expect(
      interests.selectedProvinces,
      unorderedEquals(['Taipei City', 'Kaohsiung City']),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('restores saved cities even with no regional preference', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LocationPage(
          initialPreferences: RecommendationPreferences(
            provinces: ['Taipei City', 'Kaohsiung City'],
            categories: ['Nature'],
            types: ['Parks'],
            activities: ['Walking'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DestinationCard>(
            find.byKey(const ValueKey('destination-Taipei City')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<DestinationCard>(
            find.byKey(const ValueKey('destination-Kaohsiung City')),
          )
          .selected,
      isTrue,
    );
  });
  test('all 22 destinations have local photos and retained source credits', () {
    expect(destinationPhotos.keys, unorderedEquals(taiwanCities));
    for (final asset in destinationPhotos.values) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
      expect(File(asset).lengthSync(), lessThan(150000));
    }
    expect(File('assets/destinations/manifest.json').existsSync(), isTrue);
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1280, 720),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('destination cards fit $size scale $scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const LocationPage(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(DestinationCard), findsNWidgets(22));
        final grid = tester.widget<GridView>(find.byType(GridView));
        final layout =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(layout.crossAxisCount, size.width < 700 ? 2 : 4);
        for (final city in taiwanCities) {
          await tester.ensureVisible(find.byKey(ValueKey('destination-$city')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        final last = find.byKey(const ValueKey('destination-Yunlin County'));
        await tester.tap(last);
        await tester.pumpAndSettle();
        expect(tester.widget<DestinationCard>(last).selected, isTrue);
        await tester.tap(last);
        await tester.pumpAndSettle();
        expect(tester.widget<DestinationCard>(last).selected, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
