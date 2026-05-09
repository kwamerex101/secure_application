import 'dart:async';

/// Lightweight broadcast stream that caches the last emitted value and
/// replays it to every new listener.
///
/// Replaces the `rxdart` `BehaviorSubject` we previously depended on. Built
/// on `Stream.multi`, which is part of the Dart core SDK.
class ValueStream<T> {
  ValueStream(this._value);

  T _value;
  final Set<MultiStreamController<T>> _listeners = <MultiStreamController<T>>{};
  bool _closed = false;

  /// The last value added (or the seed value if nothing was added yet).
  T get value => _value;

  /// Whether [close] has been called.
  bool get isClosed => _closed;

  /// Adds a new value, replacing [value] and notifying current listeners.
  void add(T newValue) {
    if (_closed) {
      throw StateError('ValueStream has been closed.');
    }
    _value = newValue;
    for (final listener in List<MultiStreamController<T>>.from(_listeners)) {
      listener.add(newValue);
    }
  }

  /// Broadcast stream that immediately emits [value] to each new listener
  /// followed by every subsequent value passed to [add].
  Stream<T> get stream {
    return Stream<T>.multi((MultiStreamController<T> controller) {
      controller.add(_value);
      if (_closed) {
        controller.close();
        return;
      }
      _listeners.add(controller);
      controller.onCancel = () {
        _listeners.remove(controller);
      };
    }, isBroadcast: true);
  }

  /// Closes the stream and detaches all current listeners.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final listener in List<MultiStreamController<T>>.from(_listeners)) {
      await listener.close();
    }
    _listeners.clear();
  }
}
