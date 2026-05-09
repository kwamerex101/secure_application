import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_application/secure_application.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('secure_application');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('SecureGate renders child when unlocked', (tester) async {
    final controller = SecureApplicationController(SecureApplicationState());
    await tester.pumpWidget(MaterialApp(
      home: SecureApplication(
        secureApplicationController: controller,
        child: const SecureGate(child: Text('SECRET')),
      ),
    ));
    expect(find.text('SECRET'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('SecureGate shows lockedBuilder overlay when locked',
      (tester) async {
    final controller = SecureApplicationController(SecureApplicationState());
    await tester.pumpWidget(MaterialApp(
      home: SecureApplication(
        secureApplicationController: controller,
        child: SecureGate(
          lockedBuilder: (ctx, c) => const Text('LOCKED'),
          child: const Text('SECRET'),
        ),
      ),
    ));

    controller.lock();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('LOCKED'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
  });
}
