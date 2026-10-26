import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/models/place_model.dart';
import 'package:travel_taiwan/pages/home_page.dart';

void main() {
  testWidgets('back stays visible while additional places scroll', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    final places = List.generate(
      20,
      (index) => Place.fromJson({
        'id': '$index',
        'nameTh': '景點 $index',
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
          ).copyWith(textScaler: TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AdditionalPlacesPage(
                    title: 'More places to explore',
                    places: places,
                    onOpenPlace: (_) async {},
                  ),
                ),
              ),
              child: const Text('Open list'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open list'));
    await tester.pumpAndSettle();
    final back = find.byIcon(Icons.arrow_back_ios_new_rounded);
    final before = tester.getRect(back);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(tester.getRect(back), before);
    expect(tester.takeException(), isNull);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('Open list'), findsOneWidget);
  });
}
