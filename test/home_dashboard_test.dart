import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/models/place_model.dart';
import 'package:travel_taiwan/models/favorite_place.dart';
import 'package:travel_taiwan/widgets/place_favorite_button.dart';
import 'package:travel_taiwan/widgets/selection_background.dart';
import 'package:travel_taiwan/models/recommendation_preferences.dart';
import 'package:travel_taiwan/pages/home_page.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'home fits without vertical scrolling at $size scale $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.reset);
          var locations = 0;
          var interests = 0;
          var viewAll = 0;
          var placeOpened = 0;
          final changes = <String, bool>{};
          final places = List.generate(
            5,
            (i) => Place.fromJson({
              'id': '$i',
              'nameTh': '推薦景點 $i',
              'province': 'Taipei City',
              'region': 'Northern Taiwan',
              'category': 'Nature',
              'type': 'Mountains',
            }),
          );
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                bottomNavigationBar: const SizedBox(height: 80),
                body: HomeDashboard(
                  username: 'Traveler',
                  profilePhotoFuture: Future.value(''),
                  preferences: const RecommendationPreferences(
                    provinces: ['Taipei City'],
                    categories: ['Nature'],
                    types: ['Mountains'],
                    activities: ['Scenic viewing'],
                  ),
                  places: places,
                  onProfileTap: () {},
                  onSelectLocation: () => locations++,
                  onSelectInterests: () => interests++,
                  onViewAll: () => viewAll++,
                  onOpenPlace: (_) async {
                    placeOpened++;
                  },
                  favorites: Stream.value([
                    FavoritePlace(place: places.first, savedAt: DateTime.now()),
                  ]),
                  onFavoriteChanged: (place, saved) async {
                    changes[place.id] = saved;
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(SelectionBackground), findsOneWidget);
          final featuredHeart = find.byKey(
            ValueKey('favorite:${FavoritePlace.keyFor(places.first)}'),
          );
          expect(
            tester.widget<PlaceFavoriteButton>(featuredHeart).selected,
            isTrue,
          );
          await tester.tap(featuredHeart);
          await tester.pumpAndSettle();
          final additionalHeart = find.byKey(
            ValueKey('favorite:${FavoritePlace.keyFor(places[1])}'),
          );
          await tester.tap(additionalHeart);
          await tester.pumpAndSettle();
          expect(changes, {'0': false, '1': true});
          expect(placeOpened, 0);
          expect(find.byTooltip('Favorites'), findsNothing);
          for (final scrollable in tester.widgetList<Scrollable>(
            find.byType(Scrollable),
          )) {
            expect(
              scrollable.axisDirection,
              anyOf(AxisDirection.left, AxisDirection.right),
            );
          }
          for (final label in [
            'Choose destinations',
            'Choose interests',
            'View all',
          ]) {
            final rect = tester.getRect(find.text(label));
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.bottom, lessThanOrEqualTo(size.height - 80));
            await tester.tap(find.text(label));
          }
          expect(locations, 1);
          expect(interests, 1);
          expect(viewAll, 1);
        },
      );
    }
  }
}
