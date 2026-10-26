import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/models/favorite_place.dart';
import 'package:travel_taiwan/models/place_model.dart';
import 'package:travel_taiwan/pages/detail_page.dart';
import 'package:travel_taiwan/widgets/selection_background.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'detail keeps back and favorite accessible at $size scale $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.reset);
          final favorites = StreamController<List<FavoritePlace>>();
          addTearDown(favorites.close);
          final description = List.filled(40, '山景與自然風光').join('\n');
          final place = Place.fromJson({
            'documentId': 'test-place',
            'nameTh': '景點สำหรับการท่องเที่ยวและRelaxation',
            'province': 'Taipei City',
            'region': 'Northern Taiwan',
            'category': 'Nature',
            'type': 'Mountains',
            'description': description,
          });
          final changes = <bool>[];
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DetailPage(
                          place: place,
                          favorites: favorites.stream,
                          onFavoriteChanged: (savedPlace, saved) async {
                            expect(savedPlace.documentId, place.documentId);
                            changes.add(saved);
                            favorites.add(
                              saved
                                  ? [
                                      FavoritePlace(
                                        place: place,
                                        savedAt: DateTime.now(),
                                      ),
                                    ]
                                  : [],
                            );
                          },
                        ),
                      ),
                    ),
                    child: const Text('Open attraction'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open attraction'));
          await tester.pumpAndSettle();
          favorites.add([]);
          await tester.pumpAndSettle();
          expect(find.byType(SelectionBackground), findsOneWidget);
          final back = find.byTooltip('Back');
          final initialPosition = tester.getRect(back);
          await tester.tap(find.byTooltip('Add to favorites'));
          await tester.pumpAndSettle();
          expect(find.byTooltip('Remove from favorites'), findsOneWidget);
          final heartRect = tester.getRect(
            find.byTooltip('Remove from favorites'),
          );
          expect(heartRect.left, greaterThan(size.width / 2));
          expect(
            (heartRect.center.dy - initialPosition.center.dy).abs(),
            lessThan(2),
          );
          await tester.tap(find.byTooltip('Remove from favorites'));
          await tester.pumpAndSettle();
          expect(changes, [true, false]);
          final scrollable = find.byType(ListView).first;
          await tester.drag(scrollable, const Offset(0, -650));
          await tester.pumpAndSettle();
          expect(tester.getRect(back), initialPosition);
          expect(find.byType(ShaderMask), findsOneWidget);
          final richDescription = tester.widget<RichText>(
            find.descendant(
              of: find.text(description),
              matching: find.byType(RichText),
            ),
          );
          expect(richDescription.text.style?.fontFamily, 'NotoSansThai');
          expect(tester.takeException(), isNull);
          await tester.tap(back);
          await tester.pumpAndSettle();
          expect(find.byType(DetailPage), findsNothing);
          expect(find.text('Open attraction'), findsOneWidget);
        },
      );
    }
  }
}
