import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'farwatch_colors.dart';

/// Build the Material [ThemeData] with [FarwatchColors] attached as a theme
/// extension.
ThemeData buildMaterialTheme({FarwatchColors? colors}) {
  final c = colors ?? FarwatchColors.dark();
  final isDark = c.background.computeLuminance() < 0.5;
  return ThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorSchemeSeed: c.accent,
    useMaterial3: true,
    scaffoldBackgroundColor: c.background,
    extensions: [c],
  );
}

/// Build the [CupertinoThemeData] for iOS.
CupertinoThemeData buildCupertinoTheme({FarwatchColors? colors}) {
  final c = colors ?? FarwatchColors.dark();
  final isDark = c.background.computeLuminance() < 0.5;
  return CupertinoThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    primaryColor: c.accent,
    scaffoldBackgroundColor: c.background,
    barBackgroundColor: c.navBarBackground,
    textTheme: CupertinoTextThemeData(
      primaryColor: isDark ? CupertinoColors.white : CupertinoColors.black,
    ),
  );
}
