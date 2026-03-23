import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/log.dart';
import 'core/pairing.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/terminal_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const FarwatchApp());
}

class FarwatchApp extends StatefulWidget {
  const FarwatchApp({super.key});

  @override
  State<FarwatchApp> createState() => _FarwatchAppState();
}

class _FarwatchAppState extends State<FarwatchApp> {
  static const _channel = MethodChannel('dev.farwatch/deeplink');

  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _checkInitialLink();
    _listenForLinks();
  }

  /// Check if the app was launched via a deep link (cold start).
  Future<void> _checkInitialLink() async {
    try {
      final link = await _channel.invokeMethod<String>('getInitialLink');
      if (link != null && link.startsWith('farwatch://')) {
        _navigateToTerminal(PairingUri.parse(link));
      }
    } on MissingPluginException {
      // No native handler (e.g. in tests) -- ignore
    } catch (e) {
      log('[deeplink] initial link error: $e');
    }
  }

  /// Listen for deep links while the app is running (warm start).
  void _listenForLinks() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewLink') {
        final link = call.arguments as String?;
        if (link != null && link.startsWith('farwatch://')) {
          _navigateToTerminal(PairingUri.parse(link));
        }
      }
    });
  }

  void _navigateToTerminal(PairingUri pairing) {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => TerminalScreen(pairing: pairing)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farwatch',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const HomeScreen(),
    );
  }
}
