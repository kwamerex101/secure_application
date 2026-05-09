import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the `secured` flag across process restarts so that
/// `FLAG_SECURE` / `WDA_MONITOR` is reapplied immediately on relaunch.
///
/// Other state (locked / paused / authenticated) is intentionally NOT
/// persisted — it is runtime UI state that must not survive a hostile
/// process kill, and `authenticated` in particular must always be earned
/// fresh.
class SecureApplicationRestoration {
  static const String _securedKey = 'secure_application.secured';

  /// Read the persisted `secured` flag, or `false` if no value exists or
  /// if the storage layer fails (we never want a restore error to crash
  /// the app on launch).
  static Future<bool> readSecured() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_securedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Write the `secured` flag. Failures are swallowed by design.
  static Future<void> writeSecured(bool secured) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_securedKey, secured);
    } catch (_) {
      // Persistence is best-effort.
    }
  }
}
