import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class TestAsyncNotifier extends AsyncNotifier<int> {
  int fetchCount = 0;

  @override
  Future<int> build() async {
    fetchCount++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return fetchCount;
  }

  Future<void> refreshWithInvalidateSelf() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> refreshWithAsyncLoadingAssignment() async {
    state = const AsyncLoading<int>();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    fetchCount++;
    if (ref.mounted) {
      state = AsyncData(fetchCount);
    }
  }
}

final testAsyncNotifierProvider = AsyncNotifierProvider<TestAsyncNotifier, int>(
  TestAsyncNotifier.new,
);

void main() {
  test(
    'ref.invalidateSelf() performs seamless transition with previous value',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial load
      final initial = await container.read(testAsyncNotifierProvider.future);
      expect(initial, equals(1));
      expect(container.read(testAsyncNotifierProvider), const AsyncData(1));

      // Trigger refresh using invalidateSelf()
      final notifier = container.read(testAsyncNotifierProvider.notifier);
      final refreshFuture = notifier.refreshWithInvalidateSelf();

      // Immediately check state while loading: previous value is preserved
      final loadingState = container.read(testAsyncNotifierProvider);
      expect(loadingState.isLoading, isTrue);
      expect(loadingState.hasValue, isTrue);
      expect(
        loadingState.value,
        equals(1),
      ); // Previous data preserved seamlessly
      expect(loadingState.isRefreshing, isTrue);

      // Await completion
      await refreshFuture;
      final refreshedState = container.read(testAsyncNotifierProvider);
      expect(refreshedState.isLoading, isFalse);
      expect(refreshedState.hasValue, isTrue);
      expect(refreshedState.value, equals(2));
    },
  );

  test('state = const AsyncLoading() in Riverpod 3.5 automatically preserves previous value via asyncTransition', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Initial load
    final initial = await container.read(testAsyncNotifierProvider.future);
    expect(initial, equals(1));

    // Trigger refresh using state = const AsyncLoading<int>()
    final notifier = container.read(testAsyncNotifierProvider.notifier);
    final refreshFuture = notifier.refreshWithAsyncLoadingAssignment();

    // Immediately check state while loading:
    // In Riverpod 3.5, asyncTransition automatically merges previous state!
    final loadingState = container.read(testAsyncNotifierProvider);
    expect(loadingState.isLoading, isTrue);
    expect(loadingState.hasValue, isTrue); // Automatically preserved!
    expect(loadingState.value, equals(1)); // Still 1 during loading!
    expect(loadingState.isReloading, isTrue);

    await refreshFuture;
    final refreshedState = container.read(testAsyncNotifierProvider);
    expect(refreshedState.isLoading, isFalse);
    expect(refreshedState.value, equals(2));
  });
}
