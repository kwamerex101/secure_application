import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_application/src/method_channel_secure_application.dart';
import 'package:secure_application/src/secure_application_platform.dart';

class _FakePlatform extends SecureApplicationPlatform {
  final List<String> calls = [];

  @override
  Future<void> secure() async => calls.add('secure');
  @override
  Future<void> open() async => calls.add('open');
  @override
  Future<void> lock() async => calls.add('lock');
  @override
  Future<void> unlock() async => calls.add('unlock');
  @override
  Future<void> setOpacity(double opacity) async =>
      calls.add('opacity=$opacity');
  @override
  void registerForEvents(VoidCallback onLock, VoidCallback onUnlock) {
    calls.add('registered');
  }
}

class _BadPlatform implements SecureApplicationPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default instance is MethodChannelSecureApplication', () {
    expect(SecureApplicationPlatform.instance,
        isA<MethodChannelSecureApplication>());
  });

  test('instance can be replaced for tests', () async {
    final fake = _FakePlatform();
    SecureApplicationPlatform.instance = fake;
    await SecureApplicationPlatform.instance.secure();
    await SecureApplicationPlatform.instance.setOpacity(0.5);
    expect(fake.calls, ['secure', 'opacity=0.5']);
    SecureApplicationPlatform.instance = MethodChannelSecureApplication();
  });

  test('plugin_platform_interface verifies token', () {
    expect(
      () => SecureApplicationPlatform.instance = _BadPlatform(),
      throwsA(isA<AssertionError>()),
    );
  });
}
