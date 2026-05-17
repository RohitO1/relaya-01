// Meetra widget tests
// NOTE: main.dart relies on native plugins (Supabase, Geolocator, etc.) that
// cannot be initialised in a plain unit-test environment.  The tests below are
// therefore kept minimal – they verify that Flutter's test infrastructure works
// and serve as placeholders until a proper mock/integration-test suite is added.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Text('Meetra')),
    ));
    expect(find.text('Meetra'), findsOneWidget);
  });
}
