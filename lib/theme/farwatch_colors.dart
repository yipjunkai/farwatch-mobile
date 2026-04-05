import 'package:flutter/material.dart';

/// Semantic color tokens for the Farwatch app.
///
/// Registered as a [ThemeExtension] so every widget can access tokens via
/// `context.colors` instead of hard-coding `Colors.grey[900]` etc.
///
/// Supports future theme variants (AMOLED, light, custom accent) by
/// swapping the factory constructor.
@immutable
class FarwatchColors extends ThemeExtension<FarwatchColors> {
  // ── Surfaces ──────────────────────────────────────────────────────────────

  /// App background (pure black).
  final Color background;

  /// Navigation bar background (translucent for glass blur on iOS).
  final Color navBarBackground;

  /// Primary elevated surface (cards, bottom sheets, status bars).
  final Color surfacePrimary;

  /// Secondary surface (action tiles, input field backgrounds).
  final Color surfaceSecondary;

  /// Tertiary surface (drag handles, subtle dividers).
  final Color surfaceTertiary;

  /// Translucent glass surface for iOS frosted-glass containers.
  final Color glassSurface;

  /// Subtle border for glass containers.
  final Color glassBorder;

  /// Semi-transparent status bar background.
  final Color statusBarSurface;

  /// Text input field background (prompt bar, manual entry).
  final Color inputBackground;

  // ── Text ───────────────────────────────────────────────────────────────────

  /// Primary text (white).
  final Color textPrimary;

  /// Secondary text (labels, subtitles).
  final Color textSecondary;

  /// Tertiary text (timestamps, hints).
  final Color textTertiary;

  /// Placeholder/disabled text.
  final Color textPlaceholder;

  /// Muted text (tool results, code).
  final Color textMuted;

  // ── Accent ─────────────────────────────────────────────────────────────────

  /// Primary accent (teal).
  final Color accent;

  // ── Status indicators ──────────────────────────────────────────────────────

  /// Connected / success.
  final Color statusConnected;

  /// Connecting / in-progress.
  final Color statusConnecting;

  /// Handshake / warning.
  final Color statusWarning;

  /// Error / disconnected.
  final Color statusError;

  /// Error accent (brighter, for text/icons).
  final Color statusErrorAccent;

  /// Neutral / unknown state.
  final Color statusNeutral;

  // ── Agent card surfaces ────────────────────────────────────────────────────

  /// Tool call card background.
  final Color toolCallSurface;

  /// Tool call card border.
  final Color toolCallBorder;

  /// Tool call accent text.
  final Color toolCallAccent;

  /// Thinking card background.
  final Color thinkingSurface;

  /// Thinking card border.
  final Color thinkingBorder;

  /// Thinking accent text.
  final Color thinkingAccent;

  /// Thinking icon color.
  final Color thinkingIcon;

  /// Error card background.
  final Color errorSurface;

  /// Error card border.
  final Color errorBorder;

  /// System message card background.
  final Color systemSurface;

  /// Tool result background.
  final Color resultSurface;

  /// Info banner background (amber).
  final Color infoSurface;

  /// Info banner border.
  final Color infoBorder;

  /// Info banner accent text/icon.
  final Color infoAccent;

  // ── Permissions ────────────────────────────────────────────────────────────

  /// Pending permission card background.
  final Color permissionPendingSurface;

  /// Pending permission border.
  final Color permissionPendingBorder;

  /// Pending permission accent (text, icons).
  final Color permissionPendingAccent;

  /// Resolved permission card background.
  final Color permissionResolvedSurface;

  /// Resolved permission border.
  final Color permissionResolvedBorder;

  /// Approve button background.
  final Color approveBackground;

  /// Approve button text.
  final Color approveText;

  /// Deny button background.
  final Color denyBackground;

  /// Deny button text.
  final Color denyText;

  /// "Allowed" badge background.
  final Color allowedBadge;

  /// "Denied" badge background.
  final Color deniedBadge;

  // ── Questions (mcp_question native UI) ─────────────────────────────────────

  /// Question card background.
  final Color questionSurface;

  /// Question card border.
  final Color questionBorder;

  /// Question accent (header text, icons).
  final Color questionAccent;

  /// Primary action button (first option / Done).
  final Color questionPrimaryButton;

  /// Secondary action button (second option).
  final Color questionSecondaryButton;

  /// Option tile background.
  final Color questionOptionSurface;

  /// Option tile border.
  final Color questionOptionBorder;

  // ── User prompt (chat bubble) ──────────────────────────────────────────────

  /// User message bubble background.
  final Color userBubble;

  /// User message bubble text.
  final Color userBubbleText;

  // ── Markdown / code ────────────────────────────────────────────────────────

  /// Inline code background.
  final Color codeInlineBackground;

  /// Code block background.
  final Color codeBlockBackground;

  /// Code block border.
  final Color codeBlockBorder;

  /// Copy button foreground.
  final Color copyButton;

  // ── Todos ──────────────────────────────────────────────────────────────────

  /// Todo section background.
  final Color todoSurface;

  /// Todo section border.
  final Color todoBorder;

  /// Todo section header text.
  final Color todoHeader;

  /// Completed todo icon.
  final Color todoCompleted;

  /// In-progress todo icon.
  final Color todoInProgress;

  /// Cancelled / pending todo icon.
  final Color todoPending;

  /// High-priority dot.
  final Color todoHighPriority;

  // ── Cost ticker ────────────────────────────────────────────────────────────

  /// Cost ticker surface.
  final Color costSurface;

  /// Cost ticker divider.
  final Color costDivider;

  /// Cost ticker icon.
  final Color costIcon;

  // ── Mic / Speech ───────────────────────────────────────────────────────────

  /// Active recording.
  final Color micActive;

  /// Idle mic button.
  final Color micIdle;

  // ── Prompt bar ─────────────────────────────────────────────────────────────

  /// Send button when text present.
  final Color sendActive;

  /// Prompt bar top border.
  final Color promptBarBorder;

  // ── Destructive ────────────────────────────────────────────────────────────

  /// Destructive action (swipe delete background, etc.).
  final Color destructive;

  /// Swipe delete icon/text.
  final Color destructiveOnSurface;

  // ── Session tile ───────────────────────────────────────────────────────────

  /// Host ended indicator.
  final Color sessionHostEnded;

  /// Connection lost indicator.
  final Color sessionLost;

  const FarwatchColors({
    required this.background,
    required this.navBarBackground,
    required this.surfacePrimary,
    required this.surfaceSecondary,
    required this.surfaceTertiary,
    required this.glassSurface,
    required this.glassBorder,
    required this.statusBarSurface,
    required this.inputBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textPlaceholder,
    required this.textMuted,
    required this.accent,
    required this.statusConnected,
    required this.statusConnecting,
    required this.statusWarning,
    required this.statusError,
    required this.statusErrorAccent,
    required this.statusNeutral,
    required this.toolCallSurface,
    required this.toolCallBorder,
    required this.toolCallAccent,
    required this.thinkingSurface,
    required this.thinkingBorder,
    required this.thinkingAccent,
    required this.thinkingIcon,
    required this.errorSurface,
    required this.errorBorder,
    required this.systemSurface,
    required this.resultSurface,
    required this.infoSurface,
    required this.infoBorder,
    required this.infoAccent,
    required this.permissionPendingSurface,
    required this.permissionPendingBorder,
    required this.permissionPendingAccent,
    required this.permissionResolvedSurface,
    required this.permissionResolvedBorder,
    required this.approveBackground,
    required this.approveText,
    required this.denyBackground,
    required this.denyText,
    required this.allowedBadge,
    required this.deniedBadge,
    required this.questionSurface,
    required this.questionBorder,
    required this.questionAccent,
    required this.questionPrimaryButton,
    required this.questionSecondaryButton,
    required this.questionOptionSurface,
    required this.questionOptionBorder,
    required this.userBubble,
    required this.userBubbleText,
    required this.codeInlineBackground,
    required this.codeBlockBackground,
    required this.codeBlockBorder,
    required this.copyButton,
    required this.todoSurface,
    required this.todoBorder,
    required this.todoHeader,
    required this.todoCompleted,
    required this.todoInProgress,
    required this.todoPending,
    required this.todoHighPriority,
    required this.costSurface,
    required this.costDivider,
    required this.costIcon,
    required this.micActive,
    required this.micIdle,
    required this.sendActive,
    required this.promptBarBorder,
    required this.destructive,
    required this.destructiveOnSurface,
    required this.sessionHostEnded,
    required this.sessionLost,
  });

  /// The light theme — warm rose accent on iOS-standard light surfaces.
  factory FarwatchColors.light() => const FarwatchColors(
    // Surfaces
    background: Color(0xFFF2F2F7),
    navBarBackground: Color(0xE6F9F9F9),
    surfacePrimary: Colors.white,
    surfaceSecondary: Color(0xFFE5E5EA),
    surfaceTertiary: Color(0xFFD1D1D6),
    glassSurface: Color(0xCCF9F9F9),
    glassBorder: Color(0x1A000000),
    statusBarSurface: Color(0x80F9F9F9),
    inputBackground: Color(0xFFE5E5EA),
    textPrimary: Colors.black,
    textSecondary: Color(0xFF636366),
    textTertiary: Color(0xFF8E8E93),
    textPlaceholder: Color(0xFFAEAEB2),
    textMuted: Color(0xFF8E8E93),
    accent: Color(0xFFD4736A),
    statusConnected: Color(0xFF34C759),
    statusConnecting: Color(0xFFFF9500),
    statusWarning: Color(0xFFFFCC00),
    statusError: Color(0xFFFF3B30),
    statusErrorAccent: Color(0xFFFF3B30),
    statusNeutral: Color(0xFF8E8E93),
    toolCallSurface: Color(0x1AD4736A),
    toolCallBorder: Color(0x33D4736A),
    toolCallAccent: Color(0xFFB85C54),
    thinkingSurface: Color(0x1A9C27B0),
    thinkingBorder: Color(0x339C27B0),
    thinkingAccent: Color(0xFF7B1FA2),
    thinkingIcon: Color(0xFF9C27B0),
    errorSurface: Color(0x1AFF3B30),
    errorBorder: Color(0x33FF3B30),
    systemSurface: Color(0x14607D8B),
    resultSurface: Color(0x0A000000),
    infoSurface: Color(0x1AFFCC00),
    infoBorder: Color(0x33FFCC00),
    infoAccent: Color(0xFFB38F00),
    permissionPendingSurface: Color(0x1AFFCC00),
    permissionPendingBorder: Color(0x4DFFCC00),
    permissionPendingAccent: Color(0xFFB38F00),
    permissionResolvedSurface: Color(0x0A000000),
    permissionResolvedBorder: Color(0x1A000000),
    approveBackground: Color(0x3334C759),
    approveText: Color(0xFF248A3D),
    denyBackground: Color(0x33FF3B30),
    denyText: Color(0xFFD70015),
    allowedBadge: Color(0x3334C759),
    deniedBadge: Color(0x33FF3B30),
    questionSurface: Color(0x1AD4736A),
    questionBorder: Color(0x33D4736A),
    questionAccent: Color(0xFFB85C54),
    questionPrimaryButton: Color(0x33D4736A),
    questionSecondaryButton: Color(0x1AD4736A),
    questionOptionSurface: Color(0x08000000),
    questionOptionBorder: Color(0x14000000),
    userBubble: Color(0xFFD4736A),
    userBubbleText: Colors.white,
    codeInlineBackground: Color(0x14000000),
    codeBlockBackground: Color(0xFFF2F2F7),
    codeBlockBorder: Color(0xFFD1D1D6),
    copyButton: Color(0xFF8E8E93),
    todoSurface: Color(0x14607D8B),
    todoBorder: Color(0x26607D8B),
    todoHeader: Color(0xFF546E7A),
    todoCompleted: Color(0xFF34C759),
    todoInProgress: Color(0xFFD4736A),
    todoPending: Color(0xFF8E8E93),
    todoHighPriority: Color(0xFFFF3B30),
    costSurface: Color(0x0A000000),
    costDivider: Color(0x14000000),
    costIcon: Color(0xFF8E8E93),
    micActive: Color(0xFFFF3B30),
    micIdle: Color(0xFFE5E5EA),
    sendActive: Color(0xFFD4736A),
    promptBarBorder: Color(0xFFD1D1D6),
    destructive: Color(0xFFFF3B30),
    destructiveOnSurface: Colors.white,
    sessionHostEnded: Color(0xFFFF9500),
    sessionLost: Color(0xFFFF3B30),
  );

  /// The default dark theme.
  factory FarwatchColors.dark() => const FarwatchColors(
    // Surfaces
    background: Colors.black,
    navBarBackground: Color(0xB01C1C1E),
    surfacePrimary: Color(0xFF1C1C1E), // ~ Colors.grey[900]
    surfaceSecondary: Color(0xFF2C2C2E), // ~ Colors.grey[800]
    surfaceTertiary: Color(0xFF3A3A3C), // ~ Colors.grey[700]
    glassSurface: Color(0xCC1C1C1E),
    glassBorder: Color(0x33FFFFFF),
    statusBarSurface: Color(0x801C1C1E),
    inputBackground: Color(0xFF2C2C2E),

    // Text
    textPrimary: Colors.white,
    textSecondary: Color(0xFF9E9E9E), // ~ Colors.grey[400]
    textTertiary: Color(0xFF8E8E93), // ~ Colors.grey[500]
    textPlaceholder: Color(0xFF757575), // ~ Colors.grey[600]
    textMuted: Color(0xFF8E8E93), // ~ Colors.grey[500]
    // Accent — warm rose/coral
    accent: Color(0xFFE8758A),

    // Status
    statusConnected: Colors.green,
    statusConnecting: Colors.orange,
    statusWarning: Colors.amber,
    statusError: Colors.red,
    statusErrorAccent: Colors.redAccent,
    statusNeutral: Colors.grey,

    // Tool call cards
    toolCallSurface: Color(0x1A00BCD4), // cyan @ ~10%
    toolCallBorder: Color(0x4D00BCD4), // cyan @ ~30%
    toolCallAccent: Color(0xFF80DEEA), // ~ Colors.cyan[200]
    // Thinking cards
    thinkingSurface: Color(0x1A9C27B0), // purple @ ~10%
    thinkingBorder: Color(0x4D9C27B0), // purple @ ~30%
    thinkingAccent: Color(0xFFCE93D8), // ~ Colors.purple[200]
    thinkingIcon: Color(0xFFBA68C8), // ~ Colors.purple[300]
    // Error cards
    errorSurface: Color(0x1AF44336), // red @ ~10%
    errorBorder: Color(0x4DF44336), // red @ ~30%
    // System / result
    systemSurface: Color(0x26607D8B), // blueGrey @ ~15%
    resultSurface: Color(0x14808080), // grey @ ~8%
    // Info banners
    infoSurface: Color(0x1AFFC107), // amber @ ~10%
    infoBorder: Color(0x4DFFC107), // amber @ ~30%
    infoAccent: Color(0xFFFFD54F), // ~ Colors.amber[300]
    // Permissions
    permissionPendingSurface: Color(0x1AFFC107), // amber @ ~10%
    permissionPendingBorder: Color(0x66FFC107), // amber @ ~40%
    permissionPendingAccent: Color(0xFFFFD54F), // ~ Colors.amber[300]
    permissionResolvedSurface: Color(0x14808080), // grey @ ~8%
    permissionResolvedBorder: Color(0x33808080), // grey @ ~20%
    approveBackground: Color(0x4D4CAF50), // green @ ~30%
    approveText: Color(0xFFA5D6A7), // ~ Colors.green[200]
    denyBackground: Color(0x33F44336), // red @ ~20%
    denyText: Color(0xFFE57373), // ~ Colors.red[300]
    allowedBadge: Color(0x334CAF50), // green @ ~20%
    deniedBadge: Color(0x33F44336), // red @ ~20%
    // Questions
    questionSurface: Color(0x1A2196F3), // blue @ ~10%
    questionBorder: Color(0x4D2196F3), // blue @ ~30%
    questionAccent: Color(0xFF90CAF9), // ~ Colors.blue[200]
    questionPrimaryButton: Color(0x4D2196F3), // blue @ ~30%
    questionSecondaryButton: Color(0x332196F3), // blue @ ~20%
    questionOptionSurface: Color(0x0DFFFFFF), // white @ ~5%
    questionOptionBorder: Color(0x1AFFFFFF), // white @ ~10%
    // User prompt bubble — warm rose
    userBubble: Color(0xFFD4736A),
    userBubbleText: Colors.white,

    // Markdown / code
    codeInlineBackground: Color(0x26808080), // grey @ ~15%
    codeBlockBackground: Color(0xFF1A1A1A),
    codeBlockBorder: Color(0xFF2C2C2E),
    copyButton: Color(0xFF8E8E93), // ~ Colors.grey[500]
    // Todos
    todoSurface: Color(0x1A607D8B), // blueGrey @ ~10%
    todoBorder: Color(0x33607D8B), // blueGrey @ ~20%
    todoHeader: Color(0xFFB0BEC5), // ~ Colors.blueGrey[200]
    todoCompleted: Color(0xFF66BB6A), // ~ Colors.green[400]
    todoInProgress: Color(0xFF42A5F5), // ~ Colors.blue[400]
    todoPending: Color(0xFF757575), // ~ Colors.grey[600]
    todoHighPriority: Colors.redAccent,

    // Cost ticker
    costSurface: Color(0x14808080), // grey @ ~8%
    costDivider: Color(0x26808080), // grey @ ~15%
    costIcon: Color(0xFF757575), // ~ Colors.grey[600]
    // Mic
    micActive: Colors.redAccent,
    micIdle: Color(0xFF3A3A3C),

    // Prompt
    sendActive: Color(0xFFE8758A),
    promptBarBorder: Color(0xFF2C2C2E),

    // Destructive
    destructive: Color(0xFFB71C1C), // ~ Colors.red[900]
    destructiveOnSurface: Colors.white,

    // Session tile
    sessionHostEnded: Colors.orange,
    sessionLost: Colors.red,
  );

  // ── ThemeExtension boilerplate ──────────────────────────────────────────

  @override
  FarwatchColors copyWith({
    Color? background,
    Color? navBarBackground,
    Color? surfacePrimary,
    Color? surfaceSecondary,
    Color? surfaceTertiary,
    Color? glassSurface,
    Color? glassBorder,
    Color? statusBarSurface,
    Color? inputBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textPlaceholder,
    Color? textMuted,
    Color? accent,
    Color? statusConnected,
    Color? statusConnecting,
    Color? statusWarning,
    Color? statusError,
    Color? statusErrorAccent,
    Color? statusNeutral,
    Color? toolCallSurface,
    Color? toolCallBorder,
    Color? toolCallAccent,
    Color? thinkingSurface,
    Color? thinkingBorder,
    Color? thinkingAccent,
    Color? thinkingIcon,
    Color? errorSurface,
    Color? errorBorder,
    Color? systemSurface,
    Color? resultSurface,
    Color? infoSurface,
    Color? infoBorder,
    Color? infoAccent,
    Color? permissionPendingSurface,
    Color? permissionPendingBorder,
    Color? permissionPendingAccent,
    Color? permissionResolvedSurface,
    Color? permissionResolvedBorder,
    Color? approveBackground,
    Color? approveText,
    Color? denyBackground,
    Color? denyText,
    Color? allowedBadge,
    Color? deniedBadge,
    Color? questionSurface,
    Color? questionBorder,
    Color? questionAccent,
    Color? questionPrimaryButton,
    Color? questionSecondaryButton,
    Color? questionOptionSurface,
    Color? questionOptionBorder,
    Color? userBubble,
    Color? userBubbleText,
    Color? codeInlineBackground,
    Color? codeBlockBackground,
    Color? codeBlockBorder,
    Color? copyButton,
    Color? todoSurface,
    Color? todoBorder,
    Color? todoHeader,
    Color? todoCompleted,
    Color? todoInProgress,
    Color? todoPending,
    Color? todoHighPriority,
    Color? costSurface,
    Color? costDivider,
    Color? costIcon,
    Color? micActive,
    Color? micIdle,
    Color? sendActive,
    Color? promptBarBorder,
    Color? destructive,
    Color? destructiveOnSurface,
    Color? sessionHostEnded,
    Color? sessionLost,
  }) {
    return FarwatchColors(
      background: background ?? this.background,
      navBarBackground: navBarBackground ?? this.navBarBackground,
      surfacePrimary: surfacePrimary ?? this.surfacePrimary,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      surfaceTertiary: surfaceTertiary ?? this.surfaceTertiary,
      glassSurface: glassSurface ?? this.glassSurface,
      glassBorder: glassBorder ?? this.glassBorder,
      statusBarSurface: statusBarSurface ?? this.statusBarSurface,
      inputBackground: inputBackground ?? this.inputBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textPlaceholder: textPlaceholder ?? this.textPlaceholder,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      statusConnected: statusConnected ?? this.statusConnected,
      statusConnecting: statusConnecting ?? this.statusConnecting,
      statusWarning: statusWarning ?? this.statusWarning,
      statusError: statusError ?? this.statusError,
      statusErrorAccent: statusErrorAccent ?? this.statusErrorAccent,
      statusNeutral: statusNeutral ?? this.statusNeutral,
      toolCallSurface: toolCallSurface ?? this.toolCallSurface,
      toolCallBorder: toolCallBorder ?? this.toolCallBorder,
      toolCallAccent: toolCallAccent ?? this.toolCallAccent,
      thinkingSurface: thinkingSurface ?? this.thinkingSurface,
      thinkingBorder: thinkingBorder ?? this.thinkingBorder,
      thinkingAccent: thinkingAccent ?? this.thinkingAccent,
      thinkingIcon: thinkingIcon ?? this.thinkingIcon,
      errorSurface: errorSurface ?? this.errorSurface,
      errorBorder: errorBorder ?? this.errorBorder,
      systemSurface: systemSurface ?? this.systemSurface,
      resultSurface: resultSurface ?? this.resultSurface,
      infoSurface: infoSurface ?? this.infoSurface,
      infoBorder: infoBorder ?? this.infoBorder,
      infoAccent: infoAccent ?? this.infoAccent,
      permissionPendingSurface:
          permissionPendingSurface ?? this.permissionPendingSurface,
      permissionPendingBorder:
          permissionPendingBorder ?? this.permissionPendingBorder,
      permissionPendingAccent:
          permissionPendingAccent ?? this.permissionPendingAccent,
      permissionResolvedSurface:
          permissionResolvedSurface ?? this.permissionResolvedSurface,
      permissionResolvedBorder:
          permissionResolvedBorder ?? this.permissionResolvedBorder,
      approveBackground: approveBackground ?? this.approveBackground,
      approveText: approveText ?? this.approveText,
      denyBackground: denyBackground ?? this.denyBackground,
      denyText: denyText ?? this.denyText,
      allowedBadge: allowedBadge ?? this.allowedBadge,
      deniedBadge: deniedBadge ?? this.deniedBadge,
      questionSurface: questionSurface ?? this.questionSurface,
      questionBorder: questionBorder ?? this.questionBorder,
      questionAccent: questionAccent ?? this.questionAccent,
      questionPrimaryButton:
          questionPrimaryButton ?? this.questionPrimaryButton,
      questionSecondaryButton:
          questionSecondaryButton ?? this.questionSecondaryButton,
      questionOptionSurface:
          questionOptionSurface ?? this.questionOptionSurface,
      questionOptionBorder: questionOptionBorder ?? this.questionOptionBorder,
      userBubble: userBubble ?? this.userBubble,
      userBubbleText: userBubbleText ?? this.userBubbleText,
      codeInlineBackground: codeInlineBackground ?? this.codeInlineBackground,
      codeBlockBackground: codeBlockBackground ?? this.codeBlockBackground,
      codeBlockBorder: codeBlockBorder ?? this.codeBlockBorder,
      copyButton: copyButton ?? this.copyButton,
      todoSurface: todoSurface ?? this.todoSurface,
      todoBorder: todoBorder ?? this.todoBorder,
      todoHeader: todoHeader ?? this.todoHeader,
      todoCompleted: todoCompleted ?? this.todoCompleted,
      todoInProgress: todoInProgress ?? this.todoInProgress,
      todoPending: todoPending ?? this.todoPending,
      todoHighPriority: todoHighPriority ?? this.todoHighPriority,
      costSurface: costSurface ?? this.costSurface,
      costDivider: costDivider ?? this.costDivider,
      costIcon: costIcon ?? this.costIcon,
      micActive: micActive ?? this.micActive,
      micIdle: micIdle ?? this.micIdle,
      sendActive: sendActive ?? this.sendActive,
      promptBarBorder: promptBarBorder ?? this.promptBarBorder,
      destructive: destructive ?? this.destructive,
      destructiveOnSurface: destructiveOnSurface ?? this.destructiveOnSurface,
      sessionHostEnded: sessionHostEnded ?? this.sessionHostEnded,
      sessionLost: sessionLost ?? this.sessionLost,
    );
  }

  @override
  FarwatchColors lerp(FarwatchColors? other, double t) {
    if (other is! FarwatchColors) return this;
    return FarwatchColors(
      background: Color.lerp(background, other.background, t)!,
      navBarBackground: Color.lerp(
        navBarBackground,
        other.navBarBackground,
        t,
      )!,
      surfacePrimary: Color.lerp(surfacePrimary, other.surfacePrimary, t)!,
      surfaceSecondary: Color.lerp(
        surfaceSecondary,
        other.surfaceSecondary,
        t,
      )!,
      surfaceTertiary: Color.lerp(surfaceTertiary, other.surfaceTertiary, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      statusBarSurface: Color.lerp(
        statusBarSurface,
        other.statusBarSurface,
        t,
      )!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textPlaceholder: Color.lerp(textPlaceholder, other.textPlaceholder, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      statusConnected: Color.lerp(statusConnected, other.statusConnected, t)!,
      statusConnecting: Color.lerp(
        statusConnecting,
        other.statusConnecting,
        t,
      )!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
      statusError: Color.lerp(statusError, other.statusError, t)!,
      statusErrorAccent: Color.lerp(
        statusErrorAccent,
        other.statusErrorAccent,
        t,
      )!,
      statusNeutral: Color.lerp(statusNeutral, other.statusNeutral, t)!,
      toolCallSurface: Color.lerp(toolCallSurface, other.toolCallSurface, t)!,
      toolCallBorder: Color.lerp(toolCallBorder, other.toolCallBorder, t)!,
      toolCallAccent: Color.lerp(toolCallAccent, other.toolCallAccent, t)!,
      thinkingSurface: Color.lerp(thinkingSurface, other.thinkingSurface, t)!,
      thinkingBorder: Color.lerp(thinkingBorder, other.thinkingBorder, t)!,
      thinkingAccent: Color.lerp(thinkingAccent, other.thinkingAccent, t)!,
      thinkingIcon: Color.lerp(thinkingIcon, other.thinkingIcon, t)!,
      errorSurface: Color.lerp(errorSurface, other.errorSurface, t)!,
      errorBorder: Color.lerp(errorBorder, other.errorBorder, t)!,
      systemSurface: Color.lerp(systemSurface, other.systemSurface, t)!,
      resultSurface: Color.lerp(resultSurface, other.resultSurface, t)!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
      infoBorder: Color.lerp(infoBorder, other.infoBorder, t)!,
      infoAccent: Color.lerp(infoAccent, other.infoAccent, t)!,
      permissionPendingSurface: Color.lerp(
        permissionPendingSurface,
        other.permissionPendingSurface,
        t,
      )!,
      permissionPendingBorder: Color.lerp(
        permissionPendingBorder,
        other.permissionPendingBorder,
        t,
      )!,
      permissionPendingAccent: Color.lerp(
        permissionPendingAccent,
        other.permissionPendingAccent,
        t,
      )!,
      permissionResolvedSurface: Color.lerp(
        permissionResolvedSurface,
        other.permissionResolvedSurface,
        t,
      )!,
      permissionResolvedBorder: Color.lerp(
        permissionResolvedBorder,
        other.permissionResolvedBorder,
        t,
      )!,
      approveBackground: Color.lerp(
        approveBackground,
        other.approveBackground,
        t,
      )!,
      approveText: Color.lerp(approveText, other.approveText, t)!,
      denyBackground: Color.lerp(denyBackground, other.denyBackground, t)!,
      denyText: Color.lerp(denyText, other.denyText, t)!,
      allowedBadge: Color.lerp(allowedBadge, other.allowedBadge, t)!,
      deniedBadge: Color.lerp(deniedBadge, other.deniedBadge, t)!,
      questionSurface: Color.lerp(questionSurface, other.questionSurface, t)!,
      questionBorder: Color.lerp(questionBorder, other.questionBorder, t)!,
      questionAccent: Color.lerp(questionAccent, other.questionAccent, t)!,
      questionPrimaryButton: Color.lerp(
        questionPrimaryButton,
        other.questionPrimaryButton,
        t,
      )!,
      questionSecondaryButton: Color.lerp(
        questionSecondaryButton,
        other.questionSecondaryButton,
        t,
      )!,
      questionOptionSurface: Color.lerp(
        questionOptionSurface,
        other.questionOptionSurface,
        t,
      )!,
      questionOptionBorder: Color.lerp(
        questionOptionBorder,
        other.questionOptionBorder,
        t,
      )!,
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      userBubbleText: Color.lerp(userBubbleText, other.userBubbleText, t)!,
      codeInlineBackground: Color.lerp(
        codeInlineBackground,
        other.codeInlineBackground,
        t,
      )!,
      codeBlockBackground: Color.lerp(
        codeBlockBackground,
        other.codeBlockBackground,
        t,
      )!,
      codeBlockBorder: Color.lerp(codeBlockBorder, other.codeBlockBorder, t)!,
      copyButton: Color.lerp(copyButton, other.copyButton, t)!,
      todoSurface: Color.lerp(todoSurface, other.todoSurface, t)!,
      todoBorder: Color.lerp(todoBorder, other.todoBorder, t)!,
      todoHeader: Color.lerp(todoHeader, other.todoHeader, t)!,
      todoCompleted: Color.lerp(todoCompleted, other.todoCompleted, t)!,
      todoInProgress: Color.lerp(todoInProgress, other.todoInProgress, t)!,
      todoPending: Color.lerp(todoPending, other.todoPending, t)!,
      todoHighPriority: Color.lerp(
        todoHighPriority,
        other.todoHighPriority,
        t,
      )!,
      costSurface: Color.lerp(costSurface, other.costSurface, t)!,
      costDivider: Color.lerp(costDivider, other.costDivider, t)!,
      costIcon: Color.lerp(costIcon, other.costIcon, t)!,
      micActive: Color.lerp(micActive, other.micActive, t)!,
      micIdle: Color.lerp(micIdle, other.micIdle, t)!,
      sendActive: Color.lerp(sendActive, other.sendActive, t)!,
      promptBarBorder: Color.lerp(promptBarBorder, other.promptBarBorder, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      destructiveOnSurface: Color.lerp(
        destructiveOnSurface,
        other.destructiveOnSurface,
        t,
      )!,
      sessionHostEnded: Color.lerp(
        sessionHostEnded,
        other.sessionHostEnded,
        t,
      )!,
      sessionLost: Color.lerp(sessionLost, other.sessionLost, t)!,
    );
  }
}

// ── BuildContext convenience extension ──────────────────────────────────────

extension FarwatchColorsExtension on BuildContext {
  /// Shorthand to access [FarwatchColors] from the current theme.
  ///
  /// Usage: `final c = context.colors;`
  FarwatchColors get colors => Theme.of(this).extension<FarwatchColors>()!;
}
