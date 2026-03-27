import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/log.dart';
import 'core/pairing.dart';
import 'theme/farwatch_colors.dart';
import 'theme/theme_config.dart';
import 'ui/adaptive.dart';
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

  runApp(const ProviderScope(child: FarwatchApp()));
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
      adaptivePageRoute(builder: (_) => TerminalScreen(pairing: pairing)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = FarwatchColors.dark();

    if (isApplePlatform) {
      // Wrap CupertinoApp in a Theme so widgets can access FarwatchColors
      // via Theme.of(context).extension<FarwatchColors>() / context.colors.
      // CupertinoApp does not natively support ThemeExtension.
      return Theme(
        data: buildMaterialTheme(colors: colors),
        child: CupertinoApp(
          title: 'Farwatch',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          theme: buildCupertinoTheme(colors: colors),
          home: const HomeScreen(),
        ),
      );
    }

    return MaterialApp(
      title: 'Farwatch',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: buildMaterialTheme(colors: colors),
      home: const HomeScreen(),
    );
  }
}
