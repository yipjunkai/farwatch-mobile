import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../adaptive.dart';

/// Show a manual pairing URI entry dialog/sheet.
///
/// iOS: [CupertinoAlertDialog] with a text field.
/// Android: Material [BottomSheet] with a text field.
void showManualEntry(
  BuildContext context, {
  required void Function(String uri) onConnect,
}) {
  if (isApplePlatform) {
    _showCupertinoEntry(context, onConnect: onConnect);
  } else {
    _showMaterialEntry(context, onConnect: onConnect);
  }
}

void _showCupertinoEntry(
  BuildContext context, {
  required void Function(String uri) onConnect,
}) {
  final controller = TextEditingController();
  showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Paste pairing URI'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: controller,
          placeholder: 'farwatch://pair?...',
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(fontSize: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF3A3A3C)),
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () {
            final text = controller.text.trim();
            Navigator.pop(ctx);
            if (text.isNotEmpty) onConnect(text);
          },
          child: const Text('Connect'),
        ),
      ],
    ),
  ).then((_) => controller.dispose());
}

void _showMaterialEntry(
  BuildContext context, {
  required void Function(String uri) onConnect,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _MaterialEntrySheet(onConnect: onConnect),
  );
}

class _MaterialEntrySheet extends StatefulWidget {
  final void Function(String uri) onConnect;
  const _MaterialEntrySheet({required this.onConnect});

  @override
  State<_MaterialEntrySheet> createState() => _MaterialEntrySheetState();
}

class _MaterialEntrySheetState extends State<_MaterialEntrySheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Paste pairing URI',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'farwatch://pair?...',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final text = _controller.text.trim();
              Navigator.pop(context);
              if (text.isNotEmpty) widget.onConnect(text);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
