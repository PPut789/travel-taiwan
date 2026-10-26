import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/models/interest_choices.dart';
import 'package:travel_taiwan/models/recommendation_preferences.dart';
import 'package:travel_taiwan/pages/demographics_page.dart';
import 'package:travel_taiwan/pages/interest_page.dart';

void main() {
  final choices = InterestChoices(
    categories: const ['Nature'],
    types: const ['Parks'],
    activities: const ['Walking'],
  );

  test('profile roundtrip preserves demographics and optional cities', () {
    const profile = RecommendationPreferences(
      provinces: [],
      categories: ['Nature'],
      types: ['Parks'],
      activities: ['Walking'],
      age: 26,
      gender: 'Female',
    );
    final restored = RecommendationPreferences.fromJson(profile.toJson());
    expect(restored.age, 26);
    expect(restored.gender, 'Female');
    expect(restored.isComplete, isTrue);
    expect(restored.hasDemographics, isTrue);
    expect(
      RecommendationPreferences.fromJson({
        ...profile.toJson(),
        'age': 0,
      }).hasDemographics,
      isFalse,
    );
    expect(
      RecommendationPreferences.fromJson({
        ...profile.toJson(),
        'gender': 'unknown',
      }).hasDemographics,
      isFalse,
    );
  });

  testWidgets('requires gender and a positive whole age before interests', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DemographicsPage(
          selectedProvinces: const [],
          choicesLoader: () async => choices,
        ),
      ),
    );
    await tester.tap(find.text('Continue to interests'));
    await tester.pumpAndSettle();
    expect(find.text('Please select your gender.'), findsOneWidget);
    expect(find.text('Please enter your age in whole years.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('gender-field')));
    await tester.pumpAndSettle();
    expect(find.text('Other'), findsOneWidget);
    await tester.tap(find.text('Female').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('age-field')), '0');
    await tester.tap(find.text('Continue to interests'));
    await tester.pumpAndSettle();
    expect(find.byType(InterestPage), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('age-field')), '26');
    await tester.tap(find.text('Continue to interests'));
    await tester.pumpAndSettle();
    final interest = tester.widget<InterestPage>(find.byType(InterestPage));
    expect(interest.initialPreferences?.age, 26);
    expect(interest.initialPreferences?.gender, 'Female');
    expect(interest.selectedProvinces, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('demographic form restores values and fits $size at scale 2', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const DemographicsPage(
            selectedProvinces: ['Taipei City'],
            initialPreferences: RecommendationPreferences(
              provinces: ['Taipei City'],
              categories: [],
              types: [],
              activities: [],
              age: 26,
              gender: 'Other',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('26'), findsOneWidget);
      await tester.ensureVisible(find.text('Continue to interests'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
