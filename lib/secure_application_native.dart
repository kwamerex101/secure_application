import 'dart:async';

import 'package:flutter/foundation.dart';

import 'src/secure_application_platform.dart';

/// Thin compatibility shim that forwards to
/// [SecureApplicationPlatform.instance]. New code should call the platform
/// instance directly; this static surface is preserved for callers that
/// imported `SecureApplicationNative` before 5.0.0.
class SecureApplicationNative {
  SecureApplicationNative._();

  static void registerForEvents(VoidCallback lock, VoidCallback unlock) {
    SecureApplicationPlatform.instance.registerForEvents(lock, unlock);
  }

  static Future<void> secure() => SecureApplicationPlatform.instance.secure();

  static Future<void> open() => SecureApplicationPlatform.instance.open();

  static Future<void> lock() => SecureApplicationPlatform.instance.lock();

  static Future<void> unlock() => SecureApplicationPlatform.instance.unlock();

  static Future<void> opacity(double opacity) =>
      SecureApplicationPlatform.instance.setOpacity(opacity);
}
