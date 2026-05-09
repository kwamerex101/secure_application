import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'secure_application_platform.dart';

/// Default [SecureApplicationPlatform] implementation backed by a
/// [MethodChannel].
///
/// This is the implementation selected on every platform that ships with
/// the package. Federated platform packages may replace it via
/// [SecureApplicationPlatform.instance].
class MethodChannelSecureApplication extends SecureApplicationPlatform {
  @visibleForTesting
  static const MethodChannel channel = MethodChannel('secure_application');

  VoidCallback? _onLock;
  VoidCallback? _onUnlock;
  bool _handlerInstalled = false;

  @override
  Future<void> secure() => channel.invokeMethod<void>('secure');

  @override
  Future<void> open() => channel.invokeMethod<void>('open');

  @override
  Future<void> lock() => channel.invokeMethod<void>('lock');

  @override
  Future<void> unlock() => channel.invokeMethod<void>('unlock');

  @override
  Future<void> setOpacity(double opacity) =>
      channel.invokeMethod<void>('opacity', {'opacity': opacity});

  @override
  Future<void> setCover({
    required int argb,
    bool useBlur = true,
    String? imageName,
  }) =>
      channel.invokeMethod<void>('setCover', <String, dynamic>{
        'argb': argb,
        'useBlur': useBlur,
        'imageName': imageName,
      });

  @override
  void registerForEvents(VoidCallback onLock, VoidCallback onUnlock) {
    _onLock = onLock;
    _onUnlock = onUnlock;
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    channel.setMethodCallHandler(_handle);
  }

  Future<dynamic> _handle(MethodCall call) async {
    switch (call.method) {
      case 'lock':
        _onLock?.call();
        return null;
      case 'unlock':
        _onUnlock?.call();
        return null;
      default:
        throw MissingPluginException(
            "secure_application: unknown method '${call.method}'");
    }
  }
}
