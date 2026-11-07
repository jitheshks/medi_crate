import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/core/providers/mutable_state_notifier.dart';

void main() {
  group('MutableStateNotifier & mutableStateProvider Tests', () {
    test('initial state matches provided initialValue', () {
      final counterProvider = mutableStateProvider<int>(42);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(counterProvider), equals(42));
    });

    test('direct state assignment updates value and notifies listeners', () {
      final counterProvider = mutableStateProvider<int>(0);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final states = <int>[];
      container.listen(counterProvider, (prev, next) {
        states.add(next);
      }, fireImmediately: false);

      container.read(counterProvider.notifier).state = 10;
      expect(container.read(counterProvider), equals(10));
      expect(states, equals([10]));

      container.read(counterProvider.notifier).state = 25;
      expect(container.read(counterProvider), equals(25));
      expect(states, equals([10, 25]));
    });

    test('functional update callback updates value and notifies listeners', () {
      final textProvider = mutableStateProvider<String>('hello');
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final log = <String>[];
      container.listen(textProvider, (prev, next) {
        log.add(next);
      });

      container.read(textProvider.notifier).update((s) => '$s world');
      expect(container.read(textProvider), equals('hello world'));
      expect(log, equals(['hello world']));
    });

    test('select correctly filters notifications', () {
      final pairProvider = mutableStateProvider<({int a, int b})>((a: 1, b: 2));
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var notifiedCount = 0;
      container.listen(
        pairProvider.select((s) => s.a),
        (prev, next) => notifiedCount++,
      );

      // Mutate b only: selector for a should NOT notify
      container.read(pairProvider.notifier).state = (a: 1, b: 99);
      expect(notifiedCount, equals(0));

      // Mutate a: selector for a SHOULD notify
      container.read(pairProvider.notifier).state = (a: 42, b: 99);
      expect(notifiedCount, equals(1));
    });

    test('provider disposal and invalidation re-initializes cleanly without stale state', () {
      final filterProvider = mutableStateProvider<String>('ALL');
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(filterProvider.notifier).state = 'COMPLETED';
      expect(container.read(filterProvider), equals('COMPLETED'));

      // Invalidate provider: should reset to initial value 'ALL'
      container.invalidate(filterProvider);
      expect(container.read(filterProvider), equals('ALL'));
    });

    test('independent container instances do not share state', () {
      final settingProvider = mutableStateProvider<bool>(false);
      final containerA = ProviderContainer();
      final containerB = ProviderContainer();
      addTearDown(containerA.dispose);
      addTearDown(containerB.dispose);

      containerA.read(settingProvider.notifier).state = true;

      expect(containerA.read(settingProvider), isTrue);
      expect(containerB.read(settingProvider), isFalse);
    });

    test('collection state updates work safely with immutable operations', () {
      final setProvider = mutableStateProvider<Set<String>>(<String>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(setProvider.notifier).state = {'item-1'};
      expect(container.read(setProvider), equals({'item-1'}));

      container.read(setProvider.notifier).update((s) => {...s, 'item-2'});
      expect(container.read(setProvider), equals({'item-1', 'item-2'}));

      // Invalidate resets to empty set
      container.invalidate(setProvider);
      expect(container.read(setProvider), isEmpty);
    });
  });
}
