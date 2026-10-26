import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/data/destination_photos.dart';
import 'package:travel_taiwan/models/recommendation_preferences.dart';
import 'package:travel_taiwan/pages/location_page.dart';

void main() {
  testWidgets('render destination mobile preview with bundled photos', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final fonts = FontLoader('NotoSansThai')
      ..addFont(rootBundle.load('assets/fonts/NotoSansThai-Variable.ttf'));
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'NotoSansThai', useMaterial3: true),
          home: const LocationPage(
            initialPreferences: RecommendationPreferences(
              provinces: [
                'Changhua County',
                'Kinmen County',
                'Nantou County',
                'Tainan City',
              ],
              categories: [],
              types: [],
              activities: [],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(LocationPage));
      for (final asset in destinationPhotos.values) {
        await precacheImage(AssetImage(asset), context);
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await Directory('outputs').create(recursive: true);
      await File(
        'outputs/destination-mobile-preview.png',
      ).writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    });
  });
}
