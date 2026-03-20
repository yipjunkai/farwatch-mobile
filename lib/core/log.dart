import 'package:flutter/foundation.dart';

/// Debug-only logger. Calls are completely eliminated in release builds.
void log(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}
