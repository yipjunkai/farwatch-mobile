import 'package:flutter/material.dart';

import '../../../../theme/farwatch_colors.dart';

/// Animated shimmer/pulse effect shown while a tool is running.
///
/// Displays the tool name with a pulsing glow and elapsed time counter.
class ToolShimmer extends StatefulWidget {
  final String toolName;
  final DateTime startedAt;
  final FarwatchColors colors;

  const ToolShimmer({
    super.key,
    required this.toolName,
    required this.startedAt,
    required this.colors,
  });

  @override
  State<ToolShimmer> createState() => _ToolShimmerState();
}

class _ToolShimmerState extends State<ToolShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _elapsed() {
    final d = DateTime.now().difference(widget.startedAt);
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(opacity: _opacity.value, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: widget.colors.toolCallSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: widget.colors.toolCallBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: widget.colors.toolCallAccent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Running ${widget.toolName}...',
              style: TextStyle(
                color: widget.colors.toolCallAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            // Elapsed time — rebuilt every second via the animation.
            Text(
              _elapsed(),
              style: TextStyle(
                color: widget.colors.textPlaceholder,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
