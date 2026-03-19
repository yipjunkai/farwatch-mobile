import 'package:flutter_test/flutter_test.dart';

import 'package:terminal_relay_app/main.dart';

void main() {
  testWidgets('App launches to scan screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TerminalRelayApp());
    await tester.pump();
    expect(find.text('Scan QR Code'), findsOneWidget);
  });
}
