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

import '../theme/farwatch_colors.dart';

// ---------------------------------------------------------------------------
// Platform detection
// ---------------------------------------------------------------------------

/// True on iOS (and macOS during development). False on Android / everything else.
bool get isApplePlatform => Platform.isIOS || Platform.isMacOS;

// ---------------------------------------------------------------------------
// Constants for overlay contexts where Theme is not available
// ---------------------------------------------------------------------------

const _kGlassDark = Color(0xCC1C1C1E);
const _kGlassBorder = Color(0x33FFFFFF);

// ---------------------------------------------------------------------------
// Scroll physics
// ---------------------------------------------------------------------------

/// Returns platform-appropriate scroll physics.
/// iOS: BouncingScrollPhysics (rubber-band overscroll).
/// Android: ClampingScrollPhysics (default).
ScrollPhysics get adaptiveScrollPhysics => isApplePlatform
    ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
    : const ClampingScrollPhysics();

// ---------------------------------------------------------------------------
// AdaptiveScaffold
// ---------------------------------------------------------------------------

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
    final c = context.colors;
    if (isApplePlatform) {
      return CupertinoPageScaffold(
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        backgroundColor: backgroundColor ?? c.background,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: c.navBarBackground,
          middle: Text(title, style: TextStyle(color: c.textPrimary)),
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
      backgroundColor: backgroundColor ?? c.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: c.surfacePrimary,
        foregroundColor: c.textPrimary,
        leading: leading,
        actions: trailing,
      ),
      body: body,
    );
  }
}

// ---------------------------------------------------------------------------
// AdaptiveScaffoldRaw
// ---------------------------------------------------------------------------

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
    final c = context.colors;
    if (isApplePlatform) {
      return CupertinoPageScaffold(
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        backgroundColor: backgroundColor ?? c.background,
        navigationBar: cupertinoNavBar ??
            CupertinoNavigationBar(backgroundColor: c.navBarBackground),
        child: floatingActionButton != null
            ? Stack(children: [body, floatingActionButton!])
            : body,
      );
    }
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: backgroundColor ?? c.background,
      appBar: materialAppBar,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

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
                  style: isDestructive
                      ? TextStyle(color: context.colors.statusError)
                      : null,
                ),
              ),
            ],
    ),
  );
  return result ?? false;
}

// ---------------------------------------------------------------------------
// Action sheets
// ---------------------------------------------------------------------------

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

Future<void> showAdaptiveActionSheet({
  required BuildContext context,
  String? title,
  required List<AdaptiveAction> actions,
}) async {
  final c = context.colors;
  if (isApplePlatform) {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: title != null ? Text(title) : null,
        actions: actions.map((a) {
          return CupertinoActionSheetAction(
            isDestructiveAction: a.isDestructive,
            onPressed: () { Navigator.of(ctx).pop(); a.onTap(); },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (a.icon != null) ...[Icon(a.icon, size: 20), const SizedBox(width: 8)],
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
      backgroundColor: c.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: c.surfaceTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (title != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(title, style: TextStyle(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ...actions.map((a) {
                return ListTile(
                  leading: a.icon != null
                      ? Icon(a.icon, color: a.isDestructive ? c.statusError : c.textPrimary)
                      : null,
                  title: Text(a.label, style: TextStyle(color: a.isDestructive ? c.statusError : c.textPrimary)),
                  subtitle: a.subtitle != null
                      ? Text(a.subtitle!, style: TextStyle(color: c.textTertiary, fontSize: 12))
                      : null,
                  onTap: () { Navigator.of(ctx).pop(); a.onTap(); },
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
// Glass container
// ---------------------------------------------------------------------------

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? color;
  final double blurSigma;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 12,
    this.color,
    this.blurSigma = 24,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (isApplePlatform) {
      return Container(
        margin: margin,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: color ?? c.glassSurface,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: c.glassBorder, width: 0.5),
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
        color: color ?? c.surfacePrimary,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Toast
// ---------------------------------------------------------------------------

void showAdaptiveToast(BuildContext context, String message) {
  if (isApplePlatform) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      // Overlay callbacks don't have Theme access, so use constants.
      builder: (ctx) => _AnimatedToast(
        message: message,
        bottomPadding: MediaQuery.of(ctx).padding.bottom,
        onDismiss: () {
          try {
            entry.remove();
          } catch (_) {}
        },
      ),
    );
    overlay.insert(entry);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Animated iOS-style toast with fade-in/out.
class _AnimatedToast extends StatefulWidget {
  final String message;
  final double bottomPadding;
  final VoidCallback onDismiss;

  const _AnimatedToast({
    required this.message,
    required this.bottomPadding,
    required this.onDismiss,
  });

  @override
  State<_AnimatedToast> createState() => _AnimatedToastState();
}

class _AnimatedToastState extends State<_AnimatedToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    Future.delayed(const Duration(seconds: 2, milliseconds: 500), () {
      if (mounted) {
        _animController.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: widget.bottomPadding + 80,
      left: 32,
      right: 32,
      child: FadeTransition(
        opacity: _opacity,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _kGlassDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kGlassBorder, width: 0.5),
                  ),
                  child: Text(widget.message,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page route helper
// ---------------------------------------------------------------------------

Route<T> adaptivePageRoute<T>({required WidgetBuilder builder}) {
  if (isApplePlatform) return CupertinoPageRoute<T>(builder: builder);
  return MaterialPageRoute<T>(builder: builder);
}

// ---------------------------------------------------------------------------
// Adaptive icon button
// ---------------------------------------------------------------------------

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
    final c = context.colors;
    if (isApplePlatform) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        onPressed: onPressed,
        child: Icon(icon, color: color ?? c.textPrimary, size: 22),
      );
    }
    return IconButton(
      icon: Icon(icon, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
