/// Platform-adaptive widget helpers.
///
/// iOS: Cupertino widgets with liquid glass styling (translucent nav bars,
///       frosted blur, CupertinoActionSheet, etc.)
/// Android: Material 3 widgets (current design).
library;

import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Platform detection
// ---------------------------------------------------------------------------

/// True on iOS (and macOS during development). False on Android / everything else.
bool get isApplePlatform => Platform.isIOS || Platform.isMacOS;

// ---------------------------------------------------------------------------
// Colors (shared dark palette)
// ---------------------------------------------------------------------------

/// Tinted dark surface used for glass-style containers on iOS.
const _kGlassDark = Color(0xCC1C1C1E); // iOS system gray6 dark @ 80%
const _kGlassBorder = Color(0x33FFFFFF); // subtle white edge

// ---------------------------------------------------------------------------
// AdaptiveScaffold
// ---------------------------------------------------------------------------

/// A page scaffold that renders [CupertinoPageScaffold] on iOS and [Scaffold]
/// on Android.
///
/// On iOS the [navigationBar] is a [CupertinoNavigationBar] with translucent
/// background (liquid glass) that blurs content scrolling beneath it.
class AdaptiveScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? leading;
  final List<Widget> trailing;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;

  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.body,
    this.leading,
    this.trailing = const [],
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) {
      return CupertinoPageScaffold(
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        backgroundColor: backgroundColor ?? CupertinoColors.black,
        navigationBar: CupertinoNavigationBar(
          // Translucent background → framework applies backdrop blur (liquid glass).
          backgroundColor: const Color(0xB01C1C1E),
          middle: Text(title, style: const TextStyle(color: CupertinoColors.white)),
          leading: leading,
          trailing: trailing.isEmpty
              ? null
              : trailing.length == 1
                  ? trailing.first
                  : Row(mainAxisSize: MainAxisSize.min, children: trailing),
        ),
        child: body,
      );
    }
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: backgroundColor ?? Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        leading: leading,
        actions: trailing,
      ),
      body: body,
    );
  }
}

// ---------------------------------------------------------------------------
// AdaptiveScaffoldRaw — for screens that need full control over the nav bar
// ---------------------------------------------------------------------------

/// Like [AdaptiveScaffold] but accepts a pre-built nav bar widget instead of
/// title/leading/trailing. Useful for complex app bars (e.g. terminal screen).
class AdaptiveScaffoldRaw extends StatelessWidget {
  final ObstructingPreferredSizeWidget? cupertinoNavBar;
  final PreferredSizeWidget? materialAppBar;
  final Widget body;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final Widget? floatingActionButton;

  const AdaptiveScaffoldRaw({
    super.key,
    this.cupertinoNavBar,
    this.materialAppBar,
    required this.body,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) {
      return CupertinoPageScaffold(
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        backgroundColor: backgroundColor ?? CupertinoColors.black,
        navigationBar: cupertinoNavBar ??
            const CupertinoNavigationBar(
              backgroundColor: Color(0xB01C1C1E),
            ),
        child: floatingActionButton != null
            ? Stack(children: [body, floatingActionButton!])
            : body,
      );
    }
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: backgroundColor ?? Colors.black,
      appBar: materialAppBar,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

// ---------------------------------------------------------------------------
// Dialogs — uses Flutter's built-in AlertDialog.adaptive()
// ---------------------------------------------------------------------------

/// Show a confirmation dialog. Returns `true` if the user confirmed.
///
/// Uses [AlertDialog.adaptive] which automatically renders
/// [CupertinoAlertDialog] on iOS and [AlertDialog] on Android.
Future<bool> showAdaptiveConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final result = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(content),
      actions: isApplePlatform
          ? [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(cancelLabel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: isDestructive,
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(confirmLabel),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(cancelLabel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  confirmLabel,
                  style:
                      isDestructive ? const TextStyle(color: Colors.red) : null,
                ),
              ),
            ],
    ),
  );
  return result ?? false;
}

// ---------------------------------------------------------------------------
// Action sheets / bottom sheets
// ---------------------------------------------------------------------------

/// Data model for an action in [showAdaptiveActionSheet].
class AdaptiveAction {
  final IconData? icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const AdaptiveAction({
    this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });
}

/// Show a platform-appropriate action sheet.
///
/// iOS: [CupertinoActionSheet] (frosted glass popup from bottom).
/// Android: Material [BottomSheet] with a list of options.
Future<void> showAdaptiveActionSheet({
  required BuildContext context,
  String? title,
  required List<AdaptiveAction> actions,
}) async {
  if (isApplePlatform) {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: title != null ? Text(title) : null,
        actions: actions.map((a) {
          return CupertinoActionSheetAction(
            isDestructiveAction: a.isDestructive,
            onPressed: () {
              Navigator.of(ctx).pop();
              a.onTap();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (a.icon != null) ...[
                  Icon(a.icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(a.label),
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (title != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ...actions.map((a) {
                return ListTile(
                  leading: a.icon != null
                      ? Icon(a.icon,
                          color: a.isDestructive ? Colors.red : Colors.white)
                      : null,
                  title: Text(
                    a.label,
                    style: TextStyle(
                      color: a.isDestructive ? Colors.red : Colors.white,
                    ),
                  ),
                  subtitle: a.subtitle != null
                      ? Text(a.subtitle!,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12))
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    a.onTap();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Glass container (iOS liquid glass effect for custom surfaces)
// ---------------------------------------------------------------------------

/// A container with frosted-glass appearance on iOS (blur + translucent fill)
/// and a simple dark card on Android.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? color;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 12,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) {
      return Container(
        margin: margin,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: color ?? _kGlassDark,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: _kGlassBorder, width: 0.5),
              ),
              child: child,
            ),
          ),
        ),
      );
    }
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.grey[900],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Snackbar / toast
// ---------------------------------------------------------------------------

/// Show a brief notification. iOS uses an overlay toast; Android uses SnackBar.
void showAdaptiveToast(BuildContext context, String message) {
  if (isApplePlatform) {
    // Overlay toast that auto-dismisses (iOS style).
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        bottom: MediaQuery.of(ctx).padding.bottom + 80,
        left: 32,
        right: 32,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _kGlassDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kGlassBorder, width: 0.5),
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () => entry.remove());
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// ---------------------------------------------------------------------------
// Page route helper
// ---------------------------------------------------------------------------

/// Create a platform-appropriate page route.
Route<T> adaptivePageRoute<T>({required WidgetBuilder builder}) {
  if (isApplePlatform) {
    return CupertinoPageRoute<T>(builder: builder);
  }
  return MaterialPageRoute<T>(builder: builder);
}

// ---------------------------------------------------------------------------
// Adaptive icon button (used in nav bars)
// ---------------------------------------------------------------------------

/// A tappable icon that uses [CupertinoButton] on iOS and [IconButton] on Android.
class AdaptiveIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const AdaptiveIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        onPressed: onPressed,
        child: Icon(icon, color: color ?? CupertinoColors.white, size: 22),
      );
    }
    return IconButton(
      icon: Icon(icon, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
