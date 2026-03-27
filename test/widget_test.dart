import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farwatch_app/main.dart';

void main() {
  testWidgets('App launches to home screen', (WidgetTester tester) async {
    // Start with empty preferences so no session history is loaded.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: FarwatchApp()));
    // Allow async provider to load and trigger rebuild.
    await tester.pump(const Duration(milliseconds: 100));

    // Home screen shows app title
    expect(find.text('Farwatch'), findsOneWidget);
    // Empty state visible
    expect(find.text('No sessions yet'), findsOneWidget);
    // Scan QR Code button visible (Material FilledButton or CupertinoButton)
    expect(find.text('Scan QR Code'), findsOneWidget);
  });
}
