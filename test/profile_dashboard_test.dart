import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/pages/profile_page.dart';
import 'package:travel_taiwan/widgets/selection_background.dart';
import 'package:travel_taiwan/widgets/travel_bottom_nav.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'profile fits without scrolling with shared footer at $size scale $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.view.padding = const FakeViewPadding(bottom: 34);
          addTearDown(tester.view.reset);
          var back = 0;
          final menus = <ProfileAction>[];
          final tabs = <int>[];
          var photos = 0;
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: ProfileDashboard(
                displayName: 'Traveler with a long display name',
                email: 'traveller@example.com',
                profilePhotoFuture: Future.value(''),
                onChangePhoto: () => photos++,
                onMenuSelected: menus.add,
                onNavigation: tabs.add,
                onBack: () => back++,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(SelectionBackground), findsOneWidget);
          await tester.tap(find.text('Edit profile'));
          expect(photos, 1);
          expect(find.text('My profile'), findsOneWidget);
          expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
          await tester.tap(find.byTooltip('Back'));
          expect(back, 1);
          expect(find.byTooltip('Notifications'), findsNothing);
          expect(find.byType(Scrollable), findsNothing);
          final content = find.byType(FittedBox).first;
          final footerTop = tester.getRect(find.byType(TravelBottomNav)).top;
          const labels = {
            'Favorites': ProfileAction.favorites,
            'Destinations and interests': ProfileAction.preferences,
            'Viewing history': ProfileAction.history,
            'My videos': ProfileAction.videos,
            'About': ProfileAction.about,
            'Settings': ProfileAction.settings,
            'Sign out': ProfileAction.logout,
          };
          for (final entry in labels.entries) {
            final item = find.descendant(
              of: content,
              matching: find.text(entry.key),
            );
            final rect = tester.getRect(item);
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.bottom, lessThanOrEqualTo(footerTop));
            await tester.tap(item);
            expect(menus.last, entry.value);
          }
          final footer = find.byType(TravelBottomNav);
          expect(tester.widget<TravelBottomNav>(footer).selectedIndex, 4);
          for (final label in ['Home', 'Favorites', 'Videos', 'Profile']) {
            await tester.tap(
              find.descendant(of: footer, matching: find.text(label)),
            );
          }
          await tester.tap(
            find.descendant(of: footer, matching: find.byIcon(Icons.add)),
          );
          expect(tabs, [0, 1, 3, 4, 2]);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
