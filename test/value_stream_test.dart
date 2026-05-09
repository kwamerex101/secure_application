import 'package:flutter_test/flutter_test.dart';
import 'package:secure_application/src/value_stream.dart';

void main() {
  group('ValueStream', () {
    test('replays seed value to new listeners', () async {
      final vs = ValueStream<int>(42);
      final received = <int>[];
      final sub = vs.stream.listen(received.add);
      await Future<void>.delayed(Duration.zero);
      expect(received, [42]);
      await sub.cancel();
      await vs.close();
    });

    test('replays latest value to late listeners', () async {
      final vs = ValueStream<int>(1);
      vs.add(2);
      vs.add(3);
      final received = <int>[];
      final sub = vs.stream.listen(received.add);
      await Future<void>.delayed(Duration.zero);
      expect(received, [3]);
      await sub.cancel();
      await vs.close();
    });

    test('multiple listeners each get all events', () async {
      final vs = ValueStream<String>('a');
      final r1 = <String>[];
      final r2 = <String>[];
      final s1 = vs.stream.listen(r1.add);
      final s2 = vs.stream.listen(r2.add);
      await Future<void>.delayed(Duration.zero);
      vs.add('b');
      vs.add('c');
      await Future<void>.delayed(Duration.zero);
      expect(r1, ['a', 'b', 'c']);
      expect(r2, ['a', 'b', 'c']);
      await s1.cancel();
      await s2.cancel();
      await vs.close();
    });

    test('value getter reflects last add', () {
      final vs = ValueStream<int>(0);
      expect(vs.value, 0);
      vs.add(7);
      expect(vs.value, 7);
    });

    test('add after close throws', () async {
      final vs = ValueStream<int>(0);
      await vs.close();
      expect(() => vs.add(1), throwsStateError);
    });
  });
}
