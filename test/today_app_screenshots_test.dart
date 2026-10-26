import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/data/destination_photos.dart';
import 'package:travel_taiwan/main.dart';
import 'package:travel_taiwan/models/interest_choices.dart';
import 'package:travel_taiwan/models/place_model.dart';
import 'package:travel_taiwan/models/recommendation_preferences.dart';
import 'package:travel_taiwan/pages/demographics_page.dart';
import 'package:travel_taiwan/pages/home_page.dart';
import 'package:travel_taiwan/pages/interest_page.dart';
import 'package:travel_taiwan/pages/location_page.dart';
import 'package:travel_taiwan/widgets/destination_card.dart';
import 'package:travel_taiwan/widgets/travel_bottom_nav.dart';
import 'source_photo_client.dart';

const _outputDirectory = 'outputs/today-2026-10-26/screenshots';
const _modelDemoPath = 'outputs/model-demo-results.json';
const _preferences = RecommendationPreferences(
  provinces: ['Taipei City'],
  categories: ['Nature and ecology'],
  types: ['Natural scenery'],
  activities: ['Photography', 'Scenic viewing'],
  age: 26,
  gender: 'Female',
);

final _captures = <Map<String, Object?>>[];

InterestChoices _loadChoices() => InterestChoices.fromJson(
  jsonDecode(
        File('test/fixtures/taiwan_interest_metadata.json').readAsStringSync(),
      )
      as Map<String, dynamic>,
);

Future<void> _loadFonts() async {
  // The test renderer lacks Android's system CJK fallback. Use the installed
  // Windows CJK font for readable original Taiwanese attraction names in PNGs.
  final cjkFile = File('C:/Windows/Fonts/msjh.ttc');
  if (cjkFile.existsSync()) {
    final loader = FontLoader('ScreenshotCjkFallback')
      ..addFont(
        cjkFile.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    await loader.load();
  }
  for (final entry in {
    'NotoSansThai': ['assets/fonts/NotoSansThai-Variable.ttf'],
    'Kanit': [
      'assets/fonts/Kanit-Regular.ttf',
      'assets/fonts/Kanit-Medium.ttf',
      'assets/fonts/Kanit-SemiBold.ttf',
      'assets/fonts/Kanit-Bold.ttf',
    ],
    'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

Future<GlobalKey> _render(WidgetTester tester, Widget page) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: Builder(
        builder: (context) {
          // Reuse the app's current theme rather than a separate mockup theme.
          final app = const MyApp().build(context) as MaterialApp;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: app.theme?.copyWith(
              textTheme: app.theme!.textTheme.apply(
                fontFamilyFallback: const ['ScreenshotCjkFallback'],
              ),
            ),
            scrollBehavior: app.scrollBehavior,
            home: page,
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return boundaryKey;
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String filename,
  String description,
) async {
  expect(tester.takeException(), isNull);
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await Directory(_outputDirectory).create(recursive: true);
    await File('$_outputDirectory/$filename').writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    _captures.add({
      'file': filename,
      'description': description,
      'pixelWidth': image.width,
      'pixelHeight': image.height,
    });
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final hasModelDemo = File(_modelDemoPath).existsSync();
  setUpAll(_loadFonts);
  tearDownAll(() async {
    await Directory(_outputDirectory).create(recursive: true);
    await File('$_outputDirectory/capture_manifest.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'date': '2026-10-26',
        'captureMethod': 'Actual Flutter widgets in the Flutter test renderer',
        'liveAuthenticatedSession': false,
        'logicalViewport': {'width': 390, 'height': 844},
        'theme':
            'MyApp current theme, bundled Kanit/NotoSansThai/MaterialIcons',
        'preferences': _preferences.toJson(),
        'interestChoicesSource': 'test/fixtures/taiwan_interest_metadata.json',
        'firestoreWrites': false,
        'localModelFitOrPickleLoad': false,
        'modelDemoStatus': hasModelDemo
            ? 'Input JSON provided; see result screenshot test outcome'
            : 'SKIPPED: outputs/model-demo-results.json not supplied; no result invented',
        'screenshots': _captures,
      }),
    );
  });

  testWidgets('capture actual destination cards with Taipei selected', (
    tester,
  ) async {
    final key = await _render(
      tester,
      const LocationPage(initialPreferences: _preferences),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(LocationPage));
      for (final asset in destinationPhotos.values) {
        await precacheImage(AssetImage(asset), context);
      }
    });
    await tester.pumpAndSettle();
    await _capture(
      tester,
      key,
      '01-destination-overview.png',
      'LocationPage at its initial scroll position, using bundled source photos.',
    );
    final taipei = find.byKey(const ValueKey('destination-Taipei City'));
    await tester.ensureVisible(taipei);
    await tester.pumpAndSettle();
    expect(tester.widget<DestinationCard>(taipei).selected, isTrue);
    await _capture(
      tester,
      key,
      '01-destination.png',
      'LocationPage scrolled to the selected Taipei City card.',
    );
  });

  testWidgets('capture actual gender and age form with Female age 26', (
    tester,
  ) async {
    final key = await _render(
      tester,
      DemographicsPage(
        selectedProvinces: _preferences.provinces,
        initialPreferences: _preferences,
        choicesLoader: () async => _loadChoices(),
      ),
    );
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('26'), findsOneWidget);
    await _capture(
      tester,
      key,
      '02-demographics.png',
      'DemographicsPage with Female / 26; no form submission or profile write.',
    );
  });

  testWidgets('capture actual interest choices from Taiwan source metadata', (
    tester,
  ) async {
    final choices = _loadChoices();
    expect(choices.categories, containsAll(_preferences.categories));
    expect(choices.types, containsAll(_preferences.types));
    expect(choices.activities, containsAll(_preferences.activities));
    final key = await _render(
      tester,
      InterestPage(
        selectedProvinces: _preferences.provinces,
        initialPreferences: _preferences,
        choicesLoader: () async => choices,
      ),
    );
    expect(find.text('Other'), findsNothing);
    await _capture(
      tester,
      key,
      '03-interests.png',
      'InterestPage with source-backed selections; initial category viewport.',
    );
    await tester.ensureVisible(find.text('Scenic viewing'));
    await tester.pumpAndSettle();
    await _capture(
      tester,
      key,
      '03-interests-activities.png',
      'The same InterestPage scrolled to the selected Photography / Scenic viewing activities.',
    );
  });

  testWidgets(
    'capture HomeDashboard only from supplied actual model result JSON',
    (tester) async {
      final demo =
          jsonDecode(File(_modelDemoPath).readAsStringSync())
              as Map<String, dynamic>;
      final preferences = RecommendationPreferences.fromJson(
        demo['preferences'] as Map<String, dynamic>,
      );
      final rawPlaces = demo['places'] as List<dynamic>;
      final places = rawPlaces
          .map((value) => Place.fromJson(value as Map<String, dynamic>))
          .toList();
      final photoClient = SourcePhotoClient.fromManifest(
        'outputs/today-2026-10-26/photo-fixtures',
      );
      painting.debugNetworkImageHttpClientProvider = () => photoClient;
      addTearDown(() => painting.debugNetworkImageHttpClientProvider = null);
      expect(
        places,
        isNotEmpty,
        reason: 'Do not invent a model result screenshot',
      );
      final key = await _render(
        tester,
        Scaffold(
          body: HomeDashboard(
            username: 'Traveler',
            profilePhotoFuture: Future.value(''),
            preferences: preferences,
            places: places,
            selectedProvinces: preferences.provinces,
            onProfileTap: () {},
            onSelectLocation: () {},
            onSelectInterests: () {},
            onViewAll: () {},
            onOpenPlace: (_) async {},
          ),
          bottomNavigationBar: TravelBottomNav(
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.runAsync(() async {
        final context = tester.element(find.byType(HomeDashboard));
        for (final place in places) {
          if (place.images.isNotEmpty) {
            await precacheImage(NetworkImage(place.images.first), context);
          }
        }
      });
      await tester.pumpAndSettle();
      await _capture(
        tester,
        key,
        '04-model-results.png',
        'Actual HomeDashboard supplied with model-demo-results.json places; no local fitting.',
      );
      painting.debugNetworkImageHttpClientProvider = null;
    },
    skip: !hasModelDemo,
  );
}
