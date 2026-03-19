import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/screens/scan_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Prefer dark status bar for the dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const TerminalRelayApp());
}

class TerminalRelayApp extends StatelessWidget {
  const TerminalRelayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terminal Relay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const ScanScreen(),
    );
  }
}
