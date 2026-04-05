import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/pairing.dart';
import 'providers/deep_link_provider.dart';
import 'theme/farwatch_colors.dart';
import 'theme/theme_config.dart';
import 'ui/adaptive.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/terminal_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FarwatchApp()));
}

class FarwatchApp extends ConsumerStatefulWidget {
  const FarwatchApp({super.key});

  @override
  ConsumerState<FarwatchApp> createState() => _FarwatchAppState();
}

class _FarwatchAppState extends ConsumerState<FarwatchApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
  }

  void _navigateToTerminal(PairingUri pairing) {
    _navigatorKey.currentState?.push(
      adaptivePageRoute(builder: (_) => TerminalScreen(pairing: pairing)),
    );
  }

  /// Pick color tokens based on platform brightness.
  FarwatchColors _colorsFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? FarwatchColors.dark()
        : FarwatchColors.light();
  }

  SystemUiOverlayStyle _overlayStyleFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
          )
        : const SystemUiOverlayStyle(
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
          );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for deep links and navigate to terminal.
    ref.listen(deepLinkProvider, (_, next) {
      next.whenData((pairing) => _navigateToTerminal(pairing));
    });

    final brightness = MediaQuery.platformBrightnessOf(context);
    final colors = _colorsFor(brightness);
    final overlayStyle = _overlayStyleFor(brightness);

    final darkColors = FarwatchColors.dark();
    final lightColors = FarwatchColors.light();

    if (isApplePlatform) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: Theme(
          data: buildMaterialTheme(colors: colors),
          child: CupertinoApp(
            title: 'Farwatch',
            debugShowCheckedModeBanner: false,
            navigatorKey: _navigatorKey,
            theme: buildCupertinoTheme(colors: colors),
            home: const HomeScreen(),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: MaterialApp(
        title: 'Farwatch',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: buildMaterialTheme(colors: lightColors),
        darkTheme: buildMaterialTheme(colors: darkColors),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
