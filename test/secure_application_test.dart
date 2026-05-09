import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_application/secure_application.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('secure_application');
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('SecureApplicationController state transitions', () {
    test('starts with all flags false', () {
      final c = SecureApplicationController(SecureApplicationState());
      expect(c.locked, isFalse);
      expect(c.secured, isFalse);
      expect(c.paused, isFalse);
      expect(c.authenticated, isFalse);
      c.dispose();
    });

    test('secure() flips secured and invokes native secure', () async {
      final c = SecureApplicationController(SecureApplicationState());
      c.secure();
      expect(c.secured, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(calls.map((m) => m.method), contains('secure'));
      c.dispose();
    });

    test('open() clears secured and invokes native open', () async {
      final c =
          SecureApplicationController(SecureApplicationState(secured: true));
      c.open();
      expect(c.secured, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(calls.map((m) => m.method), contains('open'));
      c.dispose();
    });

    test('lock() emits true on lockEvents only on transition', () async {
      final c = SecureApplicationController(SecureApplicationState());
      final emitted = <bool>[];
      final sub = c.lockEvents.listen(emitted.add);
      await Future<void>.delayed(Duration.zero);
      // seeded false
      expect(emitted, [false]);

      c.lock();
      c.lock(); // should be idempotent
      await Future<void>.delayed(Duration.zero);
      expect(emitted, [false, true]);

      c.unlock();
      c.unlock();
      await Future<void>.delayed(Duration.zero);
      expect(emitted, [false, true, false]);

      await sub.cancel();
      c.dispose();
    });

    test('pause/unpause toggles paused flag', () {
      final c = SecureApplicationController(SecureApplicationState());
      c.pause();
      expect(c.paused, isTrue);
      c.unpause();
      expect(c.paused, isFalse);
      c.dispose();
    });

    test('lockIfSecured only locks when secured', () {
      final c = SecureApplicationController(SecureApplicationState());
      c.lockIfSecured();
      expect(c.locked, isFalse);
      c.secure();
      c.lockIfSecured();
      expect(c.locked, isTrue);
      c.dispose();
    });
  });

  group('Authentication events', () {
    test('authSuccess emits success and sets authenticated', () async {
      final c = SecureApplicationController(SecureApplicationState());
      final events = <SecureApplicationAuthenticationStatus>[];
      final sub = c.authenticationEvents.listen(events.add);
      await Future<void>.delayed(Duration.zero);
      c.authSuccess();
      await Future<void>.delayed(Duration.zero);
      expect(c.authenticated, isTrue);
      expect(events.last, SecureApplicationAuthenticationStatus.success);
      await sub.cancel();
      c.dispose();
    });

    test('authFailed emits failed and clears authenticated', () async {
      final c = SecureApplicationController(
          SecureApplicationState(authenticated: true));
      c.authFailed();
      expect(c.authenticated, isFalse);
      c.dispose();
    });

    test('authLogout emits logout', () async {
      final c = SecureApplicationController(SecureApplicationState());
      final events = <SecureApplicationAuthenticationStatus>[];
      final sub = c.authenticationEvents.listen(events.add);
      await Future<void>.delayed(Duration.zero);
      c.authLogout();
      await Future<void>.delayed(Duration.zero);
      expect(events.last, SecureApplicationAuthenticationStatus.logout);
      await sub.cancel();
      c.dispose();
    });
  });

  group('SecureMode derived getter', () {
    test('open when no flags set', () {
      final c = SecureApplicationController(SecureApplicationState());
      expect(c.mode, SecureMode.open);
      c.dispose();
    });

    test('secured when secured && !locked && !paused', () {
      final c =
          SecureApplicationController(SecureApplicationState(secured: true));
      expect(c.mode, SecureMode.secured);
      c.dispose();
    });

    test('locked beats secured', () {
      final c = SecureApplicationController(
          SecureApplicationState(secured: true, locked: true));
      expect(c.mode, SecureMode.locked);
      c.dispose();
    });

    test('paused beats locked', () {
      final c = SecureApplicationController(
          SecureApplicationState(locked: true, paused: true));
      expect(c.mode, SecureMode.paused);
      c.dispose();
    });
  });

  group('Method channel bridge', () {
    test('controller.secure -> "secure" method on channel', () async {
      final c = SecureApplicationController(SecureApplicationState());
      c.secure();
      await Future<void>.delayed(Duration.zero);
      expect(calls.last.method, 'secure');
      c.dispose();
    });

    test('controller.open -> "open"', () async {
      final c =
          SecureApplicationController(SecureApplicationState(secured: true));
      c.open();
      await Future<void>.delayed(Duration.zero);
      expect(calls.last.method, 'open');
      c.dispose();
    });

    test('controller.lock -> "lock"', () async {
      final c = SecureApplicationController(SecureApplicationState());
      c.lock();
      await Future<void>.delayed(Duration.zero);
      expect(calls.last.method, 'lock');
      c.dispose();
    });

    test('controller.unlock -> "unlock"', () async {
      final c =
          SecureApplicationController(SecureApplicationState(locked: true));
      c.unlock();
      await Future<void>.delayed(Duration.zero);
      expect(calls.last.method, 'unlock');
      c.dispose();
    });
  });
}
