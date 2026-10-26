import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/models/interest_choices.dart';
import 'package:travel_taiwan/models/recommendation_preferences.dart';
import 'package:travel_taiwan/pages/interest_page.dart';

void main() {
  testWidgets(
    'Choose Interest renders the complete Taiwan metadata without Other',
    (tester) async {
      final metadata =
          jsonDecode(
                File(
                  'test/fixtures/taiwan_interest_metadata.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      // Exercise the same decoder used by the real Firestore metadata path,
      // including defensive handling of older metadata containing Other.
      final choices = InterestChoices.fromJson({
        ...metadata,
        'categories': [...metadata['categories'] as List, 'Other'],
        'types': [...metadata['types'] as List, 'Other'],
      });
      expect(choices.categories, hasLength(10));
      expect(choices.types, hasLength(27));
      expect(choices.activities, hasLength(12));
      await tester.binding.setSurfaceSize(const Size(1200, 8000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: InterestPage(
            selectedProvinces: const [],
            initialPreferences: const RecommendationPreferences(
              provinces: [],
              categories: ['Other'],
              types: ['Other'],
              activities: [],
            ),
            choicesLoader: () async => choices,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Other'), findsNothing);
      expect(
        find.textContaining('Nothing selected', findRichText: true),
        findsOneWidget,
      );
      for (final label in {
        ...choices.categories,
        ...choices.types,
        ...choices.activities,
      }) {
        expect(
          find.text(label),
          findsWidgets,
          reason: 'Missing option: $label',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1280, 720),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('interest options fit at $size with text scale $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        final metadata =
            jsonDecode(
                  File(
                    'test/fixtures/taiwan_interest_metadata.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final choices = InterestChoices.fromJson(metadata);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: InterestPage(
              selectedProvinces: const [],
              choicesLoader: () async => choices,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final scroll = find.byType(SingleChildScrollView).first;
        // Visit every row, including the types and activities below the fold.
        final scrollable = Scrollable.of(
          tester.element(
            find.text('Choose your interests for personalized recommendations'),
          ),
        );
        while (scrollable.position.pixels <
            scrollable.position.maxScrollExtent) {
          await tester.drag(scroll, const Offset(0, -300));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.ensureVisible(find.text('Worship and prayer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Worship and prayer'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
