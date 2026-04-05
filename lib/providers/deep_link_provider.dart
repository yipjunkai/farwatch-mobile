import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log.dart';
import '../core/pairing.dart';

/// Stream provider that emits [PairingUri]s from deep links
/// (both cold-start and warm-start).
final deepLinkProvider = StreamProvider<PairingUri>((ref) {
  final appLinks = AppLinks();
  final controller = StreamController<PairingUri>();

  // Cold start: check if the app was launched via a deep link.
  () async {
    try {
      final uri = await appLinks.getInitialLink();
      if (uri != null && uri.scheme == 'farwatch') {
        controller.add(PairingUri.parse(uri.toString()));
      }
    } catch (e) {
      log('[deeplink] initial link error: $e');
    }
  }();

  // Warm start: listen for links while the app is running.
  final sub = appLinks.uriLinkStream.listen(
    (uri) {
      if (uri.scheme == 'farwatch') {
        controller.add(PairingUri.parse(uri.toString()));
      }
    },
    onError: (e) => log('[deeplink] link stream error: $e'),
  );

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});
