import 'package:flutter_riverpod/flutter_riverpod.dart';

/// MutableStateNotifier is a modern Riverpod 3.5 [Notifier] implementation
/// replacing legacy StateProvider.
///
/// It provides a clean, reactive state container with:
/// - Direct state mutation via `.state = value`
/// - Functional updates via `.update((s) => ...)`
/// - Full compatibility with modern Riverpod 3 NotifierProvider architecture
class MutableStateNotifier<T> extends Notifier<T> {
  final T _initialValue;

  MutableStateNotifier(this._initialValue);

  @override
  T build() => _initialValue;

  @override
  set state(T value) => super.state = value;

  /// Updates current state using a transformation callback.
  void update(T Function(T state) cb) => state = cb(state);
}

/// Factory helper creating a modern Riverpod 3.5 [NotifierProvider] with mutable state.
NotifierProvider<MutableStateNotifier<T>, T> mutableStateProvider<T>(
  T initialValue, {
  String? name,
}) {
  return NotifierProvider<MutableStateNotifier<T>, T>(
    () => MutableStateNotifier<T>(initialValue),
    name: name,
  );
}
