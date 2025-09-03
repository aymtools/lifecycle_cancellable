import 'package:an_lifecycle_cancellable/an_lifecycle_cancellable.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExtData', () {
    late LifecycleOwnerMock owner;
    late Lifecycle lifecycle;
    late LifecycleRegistry registry;

    setUp(() {
      owner = LifecycleOwnerMock();
      lifecycle = owner.lifecycle;
      registry = owner.lifecycleRegistry;
      registry.handleLifecycleEvent(LifecycleEvent.create);
    });

    tearDown(() {
      if (owner.currentLifecycleState > LifecycleState.destroyed) {
        registry.handleLifecycleEvent(LifecycleEvent.destroy);
      }
    });

    test('liveData', () {
      final data1 = lifecycle.extData;
      final data2 = owner.extData;
      expect(data1, data2);
    });

    test('liveData when destroyed', () {
      final data = lifecycle.extData;

      final value = data.putIfAbsent(ifAbsent: () => 1);
      final value2 = data.putIfAbsent(ifAbsent: () => 1);
      expect(value, equals(value2));

      registry.handleLifecycleEvent(LifecycleEvent.destroy);

      final curr = data.get<int>();
      expect(curr, isNull);

      Object? error;
      try {
        owner.extData;
      } catch (e) {
        error = e;
      }
      expect(error, isNotNull);
    });

    test('liveData getByType equals', () {
      final data = lifecycle.extData;

      final value = data.putIfAbsent(ifAbsent: () => 1);
      final value2 = data.get<int>();
      expect(value, equals(value2));

      final value3 = data.putIfAbsent(ifAbsent: () => '1');
      final value4 = data.get<String>();
      expect(value3, equals(value4));
      expect(value, isNot(equals(value3)));

      final value5 = data.putIfAbsent(ifAbsent: () => '1');
      expect(value3, equals(value5));
    });

    test('liveData getByKey equals', () {
      final data = lifecycle.extData;

      final value = data.putIfAbsent(key: 'key1', ifAbsent: () => '0');
      final value2 = data.get<String>(key: 'key1');
      expect(value, equals(value2));

      final value3 = data.putIfAbsent(key: 'key2', ifAbsent: () => '1');
      final value4 = data.get<String>(key: 'key2');
      expect(value3, equals(value4));
      expect(value, isNot(equals(value3)));

      final value5 = data.putIfAbsent(key: 'key2', ifAbsent: () => '1');
      expect(value3, equals(value5));
    });

    test('liveDate recreate', () {
      final data = lifecycle.extData;

      final value = data.putIfAbsent(ifAbsent: () => 1);
      final value2 = data.get<int>();
      expect(value, equals(value2));

      registry.handleLifecycleEvent(LifecycleEvent.destroy);

      registry.handleLifecycleEvent(LifecycleEvent.create);

      final data2 = lifecycle.extData;
      expect(data, isNot(equals(data2)));

      final curr = data2.get<int>();
      expect(curr, isNull);
    });
  });
}
