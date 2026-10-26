import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/models/favorite_place.dart';
import 'package:travel_taiwan/models/place_model.dart';
import 'package:travel_taiwan/pages/favorites_page.dart';
import 'package:travel_taiwan/widgets/place_favorite_button.dart';

Place sample(String id) => Place.fromJson({
  'documentId': id,
  'nameTh': '景點 $id',
  'province': 'Taipei City',
});

void main() {
  test(
    'saved favorites survive serialization, sort, and remove independently',
    () {
      final first = sample('first');
      final second = sample('second');
      final now = DateTime.utc(2026, 10, 21);
      final initial = FavoritePlace.update(null, first, true, now);
      final duplicate = FavoritePlace.update(
        initial,
        first,
        true,
        now.add(const Duration(minutes: 1)),
      );
      expect(duplicate.length, 1);
      expect(FavoritePlace.decode(duplicate).single.savedAt, now);
      final both = FavoritePlace.update(
        duplicate,
        second,
        true,
        now.add(const Duration(minutes: 2)),
      );
      expect(FavoritePlace.decode(both).map((item) => item.place.documentId), [
        'second',
        'first',
      ]);
      final removed = FavoritePlace.update(both, first, false, now);
      expect(FavoritePlace.decode(removed).single.place.documentId, 'second');
      expect(initial.length, 1);
    },
  );

  testWidgets('heart toggles independently of the surrounding card', (
    tester,
  ) async {
    var selected = false;
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => InkWell(
              onTap: () => opened++,
              child: PlaceFavoriteButton(
                selected: selected,
                onChanged: (value) async {
                  setState(() => selected = value);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(opened, 0);
    await tester.tap(find.byTooltip('Remove from favorites'));
    await tester.pumpAndSettle();
    expect(selected, isFalse);
    expect(opened, 0);
  });

  testWidgets('failed save shows an error without marking the heart selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceFavoriteButton(
            selected: false,
            onChanged: (_) async => throw StateError('offline'),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save favorite. Please try again.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
  });

  testWidgets('favorites list opens places and removes them live', (
    tester,
  ) async {
    final controller = StreamController<List<FavoritePlace>>();
    addTearDown(controller.close);
    final place = sample('saved');
    Place? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: FavoritesPage(
          favorites: controller.stream,
          onOpenPlace: (value) async => opened = value,
          onFavoriteChanged: (value, saved) async {
            expect(value.documentId, place.documentId);
            expect(saved, isFalse);
            controller.add([]);
          },
        ),
      ),
    );
    controller.add([FavoritePlace(place: place, savedAt: DateTime.now())]);
    await tester.pumpAndSettle();
    await tester.tap(find.text(place.name).last);
    expect(opened, place);
    await tester.tap(find.byTooltip('Remove from favorites'));
    await tester.pumpAndSettle();
    expect(find.text(place.name), findsNothing);
    expect(find.textContaining('No favorites yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
