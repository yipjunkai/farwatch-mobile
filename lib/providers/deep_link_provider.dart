import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log.dart';
import '../core/pairing.dart';

/// Stream provider that emits [PairingUri]s from deep links
/// (both cold-start and warm-start).
final deepLinkProvider = StreamProvider<PairingUri>((ref) {
  const channel = MethodChannel('dev.farwatch/deeplink');
  final controller = StreamController<PairingUri>();

  // Cold start: check if the app was launched via a deep link.
  () async {
    try {
      final link = await channel.invokeMethod<String>('getInitialLink');
      if (link != null && link.startsWith('farwatch://')) {
        controller.add(PairingUri.parse(link));
      }
    } on MissingPluginException {
      // No native handler (e.g. in tests) -- ignore.
    } catch (e) {
      log('[deeplink] initial link error: $e');
    }
  }();

  // Warm start: listen for links while the app is running.
  channel.setMethodCallHandler((call) async {
    if (call.method == 'onNewLink') {
      final link = call.arguments as String?;
      if (link != null && link.startsWith('farwatch://')) {
        controller.add(PairingUri.parse(link));
      }
    }
  });

  ref.onDispose(() {
    controller.close();
    channel.setMethodCallHandler(null);
  });

  return controller.stream;
});
