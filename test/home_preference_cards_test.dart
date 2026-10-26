import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/models/recommendation_preferences.dart';
import 'package:travel_taiwan/widgets/home_preference_cards.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('home preference cards remain usable at $size scale $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        var locationTaps = 0;
        var interestTaps = 0;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: HomePreferenceCards(
                  preferences: const RecommendationPreferences(
                    provinces: ['Kaohsiung City'],
                    categories: ['Nature'],
                    types: ['Islands'],
                    activities: ['Relaxation'],
                  ),
                  onSelectLocation: () => locationTaps++,
                  onSelectInterests: () => interestTaps++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Choose destinations'));
        await tester.ensureVisible(find.text('Choose interests'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose interests'));
        expect(locationTaps, 1);
        expect(interestTaps, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
