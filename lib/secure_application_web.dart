import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

/// Web implementation of the SecureApplication plugin.
///
/// Best-effort visual masking only — a determined user with DevTools can
/// remove the overlay. Treat as a UX safeguard, not a security boundary.
class SecureApplicationWeb {
  static const String _overlayId = 'secure-application-web-overlay';
  static const String _styleId = 'secure-application-web-style';

  bool secured = false;

  // Listener handles, kept so we can remove them on `unsecureApplication`.
  JSFunction? _visibilityListener;
  JSFunction? _blurListener;
  JSFunction? _beforePrintListener;
  JSFunction? _afterPrintListener;

  final MethodChannel _channel;

  SecureApplicationWeb(this._channel);

  void secureApplication() {
    if (secured) return;
    secured = true;

    _visibilityListener = ((web.Event _) => _onVisibilityChange()).toJS;
    web.document.addEventListener('visibilitychange', _visibilityListener!);

    _blurListener = ((web.Event _) => _maskAndLock()).toJS;
    web.window.addEventListener('blur', _blurListener!);

    _beforePrintListener = ((web.Event _) => _maskAndLock()).toJS;
    web.window.addEventListener('beforeprint', _beforePrintListener!);

    _afterPrintListener = ((web.Event _) => _removeOverlay()).toJS;
    web.window.addEventListener('afterprint', _afterPrintListener!);

    _injectPrintStyle();
  }

  void unsecureApplication() {
    secured = false;
    if (_visibilityListener != null) {
      web.document
          .removeEventListener('visibilitychange', _visibilityListener!);
      _visibilityListener = null;
    }
    if (_blurListener != null) {
      web.window.removeEventListener('blur', _blurListener!);
      _blurListener = null;
    }
    if (_beforePrintListener != null) {
      web.window.removeEventListener('beforeprint', _beforePrintListener!);
      _beforePrintListener = null;
    }
    if (_afterPrintListener != null) {
      web.window.removeEventListener('afterprint', _afterPrintListener!);
      _afterPrintListener = null;
    }
    _removeOverlay();
    _removePrintStyle();
  }

  void _onVisibilityChange() {
    if (web.document.visibilityState == 'hidden') {
      _maskAndLock();
    } else if (web.document.visibilityState == 'visible') {
      _removeOverlay();
    }
  }

  void _maskAndLock() {
    _showOverlay();
    _channel.invokeMethod('lock', 'web');
  }

  void _showOverlay() {
    if (web.document.getElementById(_overlayId) != null) return;
    final overlay = web.document.createElement('div') as web.HTMLDivElement
      ..id = _overlayId;
    overlay.style.cssText =
        'position:fixed;top:0;left:0;width:100vw;height:100vh;'
        'background-color:rgba(255,255,255,0.6);'
        'backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);'
        'z-index:2147483647;pointer-events:none;user-select:none;';
    web.document.body?.appendChild(overlay);
  }

  void _removeOverlay() {
    web.document.getElementById(_overlayId)?.remove();
  }

  void _injectPrintStyle() {
    if (web.document.getElementById(_styleId) != null) return;
    final style = web.document.createElement('style') as web.HTMLStyleElement
      ..id = _styleId
      ..textContent =
          '@media print { html, body { visibility: hidden !important; } }';
    web.document.head?.appendChild(style);
  }

  void _removePrintStyle() {
    web.document.getElementById(_styleId)?.remove();
  }

  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'secure_application',
      const StandardMethodCodec(),
      registrar,
    );

    final pluginInstance = SecureApplicationWeb(channel);
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'secure':
        secureApplication();
        return true;
      case 'open':
        unsecureApplication();
        return true;
      case 'lock':
      case 'unlock':
      case 'opacity':
        return true;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          message:
              "secure_application for web doesn't implement '${call.method}'",
        );
    }
  }

  Future<String> getPlatformVersion() {
    return Future.value(web.window.navigator.userAgent);
  }
}
