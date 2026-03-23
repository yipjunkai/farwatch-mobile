import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farwatch_app/main.dart';

void main() {
  testWidgets('App launches to home screen', (WidgetTester tester) async {
    // Start with empty preferences so no session history is loaded.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FarwatchApp());
    // Allow async _loadSessions() to complete and trigger rebuild.
    await tester.pump(const Duration(milliseconds: 100));

    // Home screen shows app title
    expect(find.text('Farwatch'), findsOneWidget);
    // Empty state: no sessions yet + scan button
    expect(find.text('No sessions yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Scan QR Code'), findsOneWidget);
  });
}
