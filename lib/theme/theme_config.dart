import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'farwatch_colors.dart';

/// Build the Material [ThemeData] for Android, with [FarwatchColors] attached
/// as a theme extension.
ThemeData buildMaterialTheme({FarwatchColors? colors}) {
  final c = colors ?? FarwatchColors.dark();
  return ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: c.accent,
    useMaterial3: true,
    scaffoldBackgroundColor: c.background,
    extensions: [c],
  );
}

/// Build the [CupertinoThemeData] for iOS, matching the dark palette.
///
/// Note: [CupertinoThemeData] does not support theme extensions natively.
/// Widgets access [FarwatchColors] via the Material [Theme] ancestor that
/// wraps the [CupertinoApp] (Flutter automatically creates one).
CupertinoThemeData buildCupertinoTheme({FarwatchColors? colors}) {
  final c = colors ?? FarwatchColors.dark();
  return CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: CupertinoColors.systemTeal,
    scaffoldBackgroundColor: CupertinoColors.black,
    barBackgroundColor: c.navBarBackground,
    textTheme: const CupertinoTextThemeData(
      primaryColor: CupertinoColors.white,
    ),
  );
}
