import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/firebase_options.dart';
import 'package:travel_taiwan/main.dart';
import 'package:travel_taiwan/pages/login_page.dart';
import 'package:travel_taiwan/pages/register_page.dart';

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('unsupported platforms cannot initialize Firebase', () {
    expect(DefaultFirebaseOptions.isConfigured, isFalse);
    expect(
      () => DefaultFirebaseOptions.currentPlatform,
      throwsUnsupportedError,
    );
  });

  test('Android and Web are isolated to the Taiwan project', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(DefaultFirebaseOptions.isConfigured, isTrue);
    expect(DefaultFirebaseOptions.currentPlatform, isNotNull);
    expect(
      DefaultFirebaseOptions.currentPlatform.appId,
      '1:1020915794188:android:bf7623e4eda437329c8929',
    );
    for (final options in [
      DefaultFirebaseOptions.web,
      DefaultFirebaseOptions.android,
    ]) {
      expect(options.projectId, 'travel---taiwan');
      expect(options.storageBucket, 'travel---taiwan.firebasestorage.app');
      expect(options.messagingSenderId, '1020915794188');
    }
    expect(
      DefaultFirebaseOptions.web.appId,
      '1:1020915794188:web:82309fbd68f082f99c8929',
    );
  });

  testWidgets('app starts without initializing any Firebase project', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Tour Travel'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('sign-in stops before accessing an unconfigured Firebase app', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(InkWell, 'Sign in');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Sign-in is not available yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('registration stops before creating a cloud account', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(InkWell, 'Sign up');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Registration is not available yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
