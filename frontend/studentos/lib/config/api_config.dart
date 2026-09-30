import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Central place to configure the backend base URL.
///
/// - Android emulator can't reach the host machine via `localhost` — it must
///   use the special alias `10.0.2.2`, which is handled automatically below.
/// - iOS simulator and desktop/web can use `localhost` directly.
/// - A physical device must use your computer's LAN IP (e.g. 192.168.x.x) —
///   set STUDENTOS_API_BASE_URL via --dart-define when running on a real
///   device. See the README "Running on a physical Android device" section.
class ApiConfig {
  static const String _override = String.fromEnvironment('STUDENTOS_API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (_) {
      // Platform not available (e.g. running in a non-IO context) — fall through.
    }
    return 'http://localhost:8000';
  }
}
