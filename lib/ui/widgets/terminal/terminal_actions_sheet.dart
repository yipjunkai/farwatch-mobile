import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../adaptive.dart';

/// Show the terminal actions sheet (Ctrl+C, paste, etc.).
///
/// Uses [CupertinoActionSheet] on iOS and a Material [BottomSheet] on Android.
void showTerminalActions(
  BuildContext context, {
  required void Function(List<int>) onSendBytes,
  required void Function(String) onSendCtrl,
  required VoidCallback onPaste,
}) {
  if (isApplePlatform) {
    _showCupertinoActions(context,
        onSendBytes: onSendBytes, onSendCtrl: onSendCtrl, onPaste: onPaste);
  } else {
    _showMaterialActions(context,
        onSendBytes: onSendBytes, onSendCtrl: onSendCtrl, onPaste: onPaste);
  }
}

void _showCupertinoActions(
  BuildContext context, {
  required void Function(List<int>) onSendBytes,
  required void Function(String) onSendCtrl,
  required VoidCallback onPaste,
}) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: const Text('Terminal Actions'),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () { Navigator.pop(ctx); onSendCtrl('C'); },
          child: const Text('Interrupt (Ctrl+C)'),
        ),
        CupertinoActionSheetAction(
          onPressed: () { Navigator.pop(ctx); onSendCtrl('D'); },
          child: const Text('EOF (Ctrl+D)'),
        ),
        CupertinoActionSheetAction(
          onPressed: () { Navigator.pop(ctx); onSendCtrl('Z'); },
          child: const Text('Suspend (Ctrl+Z)'),
        ),
        CupertinoActionSheetAction(
          onPressed: () { Navigator.pop(ctx); onSendCtrl('L'); },
          child: const Text('Clear (Ctrl+L)'),
        ),
        CupertinoActionSheetAction(
          onPressed: () { Navigator.pop(ctx); onSendCtrl('R'); },
          child: const Text('Search (Ctrl+R)'),
        ),
        CupertinoActionSheetAction(
          onPressed: () { Navigator.pop(ctx); onSendBytes([0x1b]); },
          child: const Text('Escape'),
        ),
        CupertinoActionSheetAction(
          onPressed: () { Navigator.pop(ctx); onPaste(); },
          child: const Text('Paste Clipboard'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Cancel'),
      ),
    ),
  );
}

void _showMaterialActions(
  BuildContext context, {
  required void Function(List<int>) onSendBytes,
  required void Function(String) onSendCtrl,
  required VoidCallback onPaste,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey[900],
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _section('Control', [
                _tile(ctx, Icons.stop_circle_outlined, 'Interrupt', 'Ctrl+C', () => onSendCtrl('C')),
                _tile(ctx, Icons.logout, 'EOF', 'Ctrl+D', () => onSendCtrl('D')),
                _tile(ctx, Icons.pause_circle_outline, 'Suspend', 'Ctrl+Z', () => onSendCtrl('Z')),
                _tile(ctx, Icons.refresh, 'Clear', 'Ctrl+L', () => onSendCtrl('L')),
              ]),
              const SizedBox(height: 12),
              _section('Navigate', [
                _tile(ctx, Icons.arrow_upward, 'Previous', 'Up', () => onSendBytes([0x1b, 0x5b, 0x41])),
                _tile(ctx, Icons.arrow_downward, 'Next', 'Down', () => onSendBytes([0x1b, 0x5b, 0x42])),
                _tile(ctx, Icons.keyboard_tab, 'Tab', 'Tab', () => onSendBytes([0x09])),
                _tile(ctx, Icons.first_page, 'Escape', 'Esc', () => onSendBytes([0x1b])),
              ]),
              const SizedBox(height: 12),
              _section('Edit', [
                _tile(ctx, Icons.content_paste, 'Paste', '', onPaste),
                _tile(ctx, Icons.search, 'Search', 'Ctrl+R', () => onSendCtrl('R')),
              ]),
            ],
          ),
        ),
      );
    },
  );
}

Widget _section(String title, List<Widget> children) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title,
            style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      ),
      Wrap(spacing: 8, runSpacing: 8, children: children),
    ],
  );
}

Widget _tile(BuildContext ctx, IconData icon, String label, String shortcut,
    VoidCallback onTap) {
  return Material(
    color: Colors.grey[800],
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () { onTap(); Navigator.pop(ctx); },
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center),
            if (shortcut.isNotEmpty)
              Text(shortcut,
                  style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          ],
        ),
      ),
    ),
  );
}
