import 'dart:async';

import 'package:an_lifecycle_cancellable/an_lifecycle_cancellable.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FutureLifecycleExt', () {
    test('bindLifecycle', () async {
      LifecycleOwnerMock lifecycleOwner = LifecycleOwnerMock();
      lifecycleOwner.lifecycleRegistry
          .handleLifecycleEvent(LifecycleEvent.create);

      bool executed = false;

      final future = Future.delayed(const Duration(milliseconds: 100))
          .bindLifecycle(lifecycleOwner)
          .then((_) => executed = true);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(executed, false);
      lifecycleOwner.lifecycleRegistry
          .handleLifecycleEvent(LifecycleEvent.destroy);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(executed, false);

      // Test with lifecycle not destroyed
      lifecycleOwner = LifecycleOwnerMock();
      lifecycleOwner.lifecycleRegistry
          .handleLifecycleEvent(LifecycleEvent.create);
      executed = false;

      final future2 = Future.delayed(const Duration(milliseconds: 100))
          .bindLifecycle(lifecycleOwner)
          .then((_) => executed = true);

      await Future.delayed(const Duration(milliseconds: 150));
      expect(executed, true);
    });
  });
  group('StreamLifecycleExt', () {
    test('bindLifecycle()', () async {
      LifecycleOwnerMock lifecycleOwner = LifecycleOwnerMock();
      lifecycleOwner.lifecycleRegistry
          .handleLifecycleEvent(LifecycleEvent.create);

      final streamController = StreamController<int>();
      final stream = streamController.stream.bindLifecycle(lifecycleOwner);
      final list = <int>[];
      final subscription = stream.listen((event) {
        list.add(event);
      });

      streamController.add(1);
      streamController.add(2);
      await Future.delayed(Duration.zero);
      lifecycleOwner.lifecycleRegistry
          .handleLifecycleEvent(LifecycleEvent.destroy);
      streamController.add(3);
      await Future.delayed(Duration.zero);
      subscription.cancel();
      streamController.close();
      expect(list, [1, 2]);
    });

    test('bindLifecycle() has state=LifecycleState.destroyed', () async {
      LifecycleOwnerMock lifecycleOwner = LifecycleOwnerMock();
      final streamController = StreamController<int>();
      final stream = streamController.stream;
      final stream1 =
          stream.bindLifecycle(lifecycleOwner, state: LifecycleState.destroyed);

      expect(stream, equals(stream1));
    });

    test('bindLifecycle() has state>LifecycleState.destroyed', () async {
      LifecycleOwnerMock lifecycleOwner = LifecycleOwnerMock();
      lifecycleOwner.lifecycleRegistry
          .handleLifecycleEvent(LifecycleEvent.create);

      final streamController = StreamController<int>();
      final stream = streamController.stream
          .bindLifecycle(lifecycleOwner, state: LifecycleState.started);
      final list = <int>[];
      final subscription = stream.listen((event) {
        list.add(event);
      });
      streamController.add(1);
      streamController.add(2);
      await Future.delayed(Duration.zero);
      lifecycleOwner.lifecycleRegistry
          .handleLifecycleEvent(LifecycleEvent.start);
      streamController.add(3);
      await Future.delayed(Duration.zero);
      lifecycleOwner.lifecycleRegistry
          .handleLifecycleEvent(LifecycleEvent.stop);
      streamController.add(4);
      await Future.delayed(Duration.zero);
      lifecycleOwner.lifecycleRegistry
          .handleLifecycleEvent(LifecycleEvent.start);
      streamController.add(5);
      await Future.delayed(Duration.zero);
      lifecycleOwner.lifecycleRegistry
          .handleLifecycleEvent(LifecycleEvent.destroy);
      streamController.add(6);
      await Future.delayed(Duration.zero);
      subscription.cancel();
      streamController.close();
      expect(list, [3, 5]);
    });

    test('bindLifecycle() has state,repeatLastOnStateAtLeast=true', () async {
      LifecycleOwnerMock lifecycleOwner = LifecycleOwnerMock();
      lifecycleOwner.lifecycleRegistry
          .handleLifecycleEvent(LifecycleEvent.create);

      final streamController = StreamController<int>();
      final stream = streamController.stream.bindLifecycle(lifecycleOwner,
          state: LifecycleState.started, repeatLastOnStateAtLeast: true);
      final list = <int>[];
      final subscription = stream.listen((event) {
        list.add(event);
      });
      streamController.add(1);
      streamController.add(2);
      await Future.delayed(Duration.zero);
      lifecycleOwner.lifecycleRegistry
          .handleLifecycleEvent(LifecycleEvent.start);
      streamController.add(3);
      await Future.delayed(Duration.zero);
      lifecycleOwner.lifecycleRegistry
          .handleLifecycleEvent(LifecycleEvent.stop);
      streamController.add(4);
      await Future.delayed(Duration.zero);
      streamController.add(5);
      await Future.delayed(Duration.zero);
      lifecycleOwner.lifecycleRegistry
          .handleLifecycleEvent(LifecycleEvent.start);
      streamController.add(6);
      await Future.delayed(Duration.zero);
      lifecycleOwner.lifecycleRegistry
          .handleLifecycleEvent(LifecycleEvent.destroy);
      streamController.add(7);
      await Future.delayed(Duration.zero);
      subscription.cancel();
      streamController.close();
      expect(list, [2, 3, 5, 6]);
    });
  });
}
