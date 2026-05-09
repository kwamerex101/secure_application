import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:secure_application/secure_application_state.dart';
import 'package:secure_application/src/secure_application_platform.dart';
import 'package:secure_application/src/secure_application_restoration.dart';
import 'package:secure_application/src/value_stream.dart';

/// Authentication outcome reported via
/// [SecureApplicationController.authenticationEvents].
///
/// **Breaking change in 5.0.0:** values are now lowerCamelCase. Replace
/// `SUCCESS` → `success`, `FAILED` → `failed`, `LOGOUT` → `logout`,
/// `NONE` → `none`.
enum SecureApplicationAuthenticationStatus {
  success,
  failed,
  logout,
  none,
}

/// High-level mode summarising the four boolean flags. Useful for `switch`
/// statements when you don't need to consume each axis individually.
enum SecureMode {
  /// Not secured — content visible everywhere, no native protection.
  open,

  /// Secured but unlocked — native protection on, gate not displayed.
  secured,

  /// Locked — gate is displayed; user must satisfy `onNeedUnlock` to pass.
  locked,

  /// Auto-lock temporarily suppressed (e.g. while a file picker is open).
  paused,
}

/// Main controller for the library.
///
/// "Secured" means the app should hide content when the user switches away.
/// On Android this also enables FLAG_SECURE (blocks screenshots / screen
/// recording). On iOS/Android it hides content in the OS app switcher.
/// On iOS/Android the controller is automatically locked when the app
/// becomes active again, so any [SecureGate] tied to this controller will
/// display a frost overlay.
class SecureApplicationController
    extends ValueNotifier<SecureApplicationState> {
  SecureApplicationController(SecureApplicationState value) : super(value);

  final ValueStream<SecureApplicationAuthenticationStatus> _authEvents =
      ValueStream<SecureApplicationAuthenticationStatus>(
          SecureApplicationAuthenticationStatus.none);

  /// Broadcast stream of authentication outcomes. New listeners are
  /// immediately notified with the most recent value (default
  /// [SecureApplicationAuthenticationStatus.none]).
  Stream<SecureApplicationAuthenticationStatus> get authenticationEvents =>
      _authEvents.stream;

  final ValueStream<bool> _lockEvents = ValueStream<bool>(false);

  /// Broadcast stream that emits `true` when locked and `false` when
  /// unlocked. New listeners are immediately notified with the current
  /// value.
  Stream<bool> get lockEvents => _lockEvents.stream;

  /// Whether the app is currently locked.
  bool get locked => value.locked;

  /// Whether native protection is currently engaged.
  bool get secured => value.secured;

  /// Whether auto-lock is temporarily suppressed (used to keep the app
  /// unlocked while a file/image picker, OAuth flow, etc. is on screen).
  bool get paused => value.paused;

  /// Whether the user has authenticated at least once in this session.
  /// Reset to `false` by [authFailed] / [authLogout].
  bool get authenticated => value.authenticated;

  /// Derived high-level mode. See [SecureMode] for semantics.
  SecureMode get mode {
    if (value.paused) return SecureMode.paused;
    if (value.locked) return SecureMode.locked;
    if (value.secured) return SecureMode.secured;
    return SecureMode.open;
  }

  /// Notify [authenticationEvents] subscribers with [status]. Useful for
  /// integrating non-trivial auth flows that do not call [authSuccess] /
  /// [authFailed] / [authLogout] directly.
  void sendAuthenticationEvent(SecureApplicationAuthenticationStatus status) {
    _authEvents.add(status);
  }

  void authFailed({bool unlock = false}) {
    value = value.copyWith(authenticated: false);
    _authEvents.add(SecureApplicationAuthenticationStatus.failed);
    if (unlock) this.unlock();
    notifyListeners();
  }

  void authSuccess({bool unlock = false}) {
    value = value.copyWith(authenticated: true);
    _authEvents.add(SecureApplicationAuthenticationStatus.success);
    if (unlock) this.unlock();
    notifyListeners();
  }

  void authLogout({bool unlock = false}) {
    value = value.copyWith(authenticated: false);
    _authEvents.add(SecureApplicationAuthenticationStatus.logout);
    if (unlock) this.unlock();
    notifyListeners();
  }

  /// Lock the app — content under any [SecureGate] is hidden.
  void lock() {
    SecureApplicationPlatform.instance.lock();
    if (!value.locked) {
      value = value.copyWith(locked: true);
      notifyListeners();
      _lockEvents.add(true);
    }
  }

  /// Lock only if currently secured.
  void lockIfSecured() {
    if (value.secured) lock();
  }

  /// Unlock the app — content under any [SecureGate] is visible again.
  void unlock() {
    SecureApplicationPlatform.instance.unlock();
    if (value.locked) {
      value = value.copyWith(locked: false);
      notifyListeners();
      _lockEvents.add(false);
    }
  }

  /// Suppress the next auto-lock (e.g. before opening a file picker so the
  /// app does not immediately lock when the picker takes focus).
  void pause() {
    SecureApplicationPlatform.instance.lock();
    if (!value.paused) {
      value = value.copyWith(paused: true);
      notifyListeners();
    }
  }

  /// Re-enable auto-lock.
  void unpause() {
    if (value.paused) {
      value = value.copyWith(paused: false);
      notifyListeners();
    }
  }

  /// Notify gates that the app resumed. Used internally.
  void resumed() {
    notifyListeners();
  }

  /// Engage native protection.
  ///
  /// On Android this also blocks screenshots / screen recording via
  /// FLAG_SECURE. On Windows 10+ this enables `WDA_MONITOR`.
  void secure() {
    SecureApplicationPlatform.instance.secure();
    SecureApplicationRestoration.writeSecured(true);
    if (!value.secured) {
      value = value.copyWith(secured: true);
      notifyListeners();
    }
  }

  /// Configure the iOS resign-active cover. No-op on other platforms.
  ///
  /// [color] is the solid background color drawn over the app windows.
  /// [useBlur] toggles the iOS `UIBlurEffect` (default `true`). [imageName]
  /// is an optional asset resolved from the host app's main bundle (e.g.
  /// `"LaunchImage"`); when provided it is rendered centered.
  void setCover({
    required Color color,
    bool useBlur = true,
    String? imageName,
  }) {
    SecureApplicationPlatform.instance.setCover(
      argb: _argbFromColor(color),
      useBlur: useBlur,
      imageName: imageName,
    );
  }

  /// Disengage native protection.
  void open() {
    SecureApplicationPlatform.instance.open();
    SecureApplicationRestoration.writeSecured(false);
    if (value.secured) {
      value = value.copyWith(secured: false);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authEvents.close();
    _lockEvents.close();
    super.dispose();
  }

  static int _argbFromColor(Color color) {
    final int a = (color.a * 255.0).round() & 0xFF;
    final int r = (color.r * 255.0).round() & 0xFF;
    final int g = (color.g * 255.0).round() & 0xFF;
    final int b = (color.b * 255.0).round() & 0xFF;
    return (a << 24) | (r << 16) | (g << 8) | b;
  }
}
