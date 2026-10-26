import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_taiwan/pages/start_page.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1280, 720),
  ]) {
    testWidgets('Taiwan start screen fits $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: StartPage()));
      await tester.pumpAndSettle();
      expect(find.text('Tour Travel'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
