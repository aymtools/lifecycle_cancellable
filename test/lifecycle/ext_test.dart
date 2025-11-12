import 'package:an_lifecycle_cancellable/an_lifecycle_cancellable.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:cancellable/cancellable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  group('ILifecycleExt', () {
    test('.makeLiveCancellable()', () {
      final cancellable = lifecycle.makeLiveCancellable();
      final cancellable2 = owner.makeLiveCancellable();
      expect(cancellable.isAvailable, true);
      expect(cancellable2.isAvailable, true);
      registry.handleLifecycleEvent(LifecycleEvent.destroy);
      expect(cancellable.isAvailable, false);
      expect(cancellable2.isAvailable, false);

      expect(registry.observers, isEmpty);
    });

    test('.makeLiveCancellable() and other', () {
      final cancellable = Cancellable();
      final liveCancellable = lifecycle.makeLiveCancellable(other: cancellable);
      expect(cancellable.isAvailable, true);
      expect(liveCancellable.isAvailable, true);
      cancellable.cancel();
      expect(cancellable.isAvailable, false);
      expect(liveCancellable.isAvailable, false);
      registry.handleLifecycleEvent(LifecycleEvent.destroy);
      expect(cancellable.isAvailable, false);
    });
    test('.makeLiveCancellable() and other.cancelled', () {
      final cancellable = Cancellable.cancelled();
      final liveCancellable = lifecycle.makeLiveCancellable(other: cancellable);
      expect(cancellable.isAvailable, false);
      expect(liveCancellable.isAvailable, false);
      cancellable.cancel();
      expect(cancellable.isAvailable, false);
      expect(liveCancellable.isAvailable, false);
      registry.handleLifecycleEvent(LifecycleEvent.destroy);
      expect(cancellable.isAvailable, false);
    });

    test('.launchWhenNextLifecycleEvent()', () {
      var called = false;
      lifecycle.launchWhenNextLifecycleEvent(
          targetEvent: LifecycleEvent.start, block: (_) => called = true);
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, true);
      registry.handleLifecycleEvent(LifecycleEvent.resume);
      expect(called, true);
    });

    test('.launchWhenNextLifecycleEvent() owner', () {
      var called = false;
      owner.launchWhenNextLifecycleEvent(
          targetEvent: LifecycleEvent.start, block: (_) => called = true);
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, true);
      registry.handleLifecycleEvent(LifecycleEvent.resume);
      expect(called, true);
    });

    test('.launchWhenNextLifecycleEvent() twice', () {
      var called = 0;
      lifecycle.launchWhenNextLifecycleEvent(
          targetEvent: LifecycleEvent.start, block: (_) => called++);
      lifecycle.launchWhenNextLifecycleEvent(
          targetEvent: LifecycleEvent.start, block: (_) => called++);
      expect(called, 0);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, 2);
      registry.handleLifecycleEvent(LifecycleEvent.resume);
      expect(called, 2);
    });

    test('.launchWhenNextLifecycleEvent() not tigger', () {
      var called = false;
      lifecycle.launchWhenNextLifecycleEvent(
          targetEvent: LifecycleEvent.resume, block: (_) => called = true);
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.stop);
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.destroy);
      expect(called, false);

      expect(registry.observers, isEmpty);
    });

    test('.launchWhenNextLifecycleEvent() cancel', () {
      var called = false;
      final cancellable = Cancellable();
      lifecycle.launchWhenNextLifecycleEvent(
          targetEvent: LifecycleEvent.start,
          cancellable: cancellable,
          block: (_) => called = true);
      expect(called, false);
      cancellable.cancel();
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, false);
    });

    test('.launchWhenNextLifecycleEvent() currStateAtLast', () {
      registry.handleLifecycleEvent(LifecycleEvent.start);
      var called = false;
      lifecycle.launchWhenNextLifecycleEvent(
          targetEvent: LifecycleEvent.start, block: (_) => called = true);
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.resume);
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.stop);
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, true);
    });

    test('.launchWhenNextLifecycleEvent() runWithDelayed=true', () async {
      var called = false;
      lifecycle.launchWhenNextLifecycleEvent(
          targetEvent: LifecycleEvent.start,
          runWithDelayed: true,
          block: (_) => called = true);

      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, false);
      await Future.delayed(Duration.zero);
      expect(called, true);
    });

    test('.launchWhenNextLifecycleEvent() block cancellable.cancel()', () {
      var called = 0;
      lifecycle.launchWhenNextLifecycleEvent(
          targetEvent: LifecycleEvent.start,
          block: (cancellable) {
            called++;
            cancellable.cancel();
          });

      expect(called, 0);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, 1);
      registry.handleLifecycleEvent(LifecycleEvent.stop);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, 1);
    });

    test('.launchWhenNextLifecycleEvent() block cancel run', () async {
      var called = false;
      lifecycle.launchWhenNextLifecycleEvent(
          targetEvent: LifecycleEvent.start,
          runWithDelayed: true,
          block: (cancellable) {
            called = true;
          });

      expect(called, isFalse);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, isFalse);
      registry.handleLifecycleEvent(LifecycleEvent.resume);
      expect(called, isFalse);
      await Future.delayed(Duration.zero);
      expect(called, isFalse,
          reason: 'now event is resume, not start, block not run');
    });

    test('.launchWhenNextLifecycleEvent() block cancel check', () async {
      var called = false;
      var calledWhere = false;
      lifecycle.launchWhenNextLifecycleEvent(
        targetEvent: LifecycleEvent.start,
        runWithDelayed: true,
        block: (cancellable) async {
          called = true;
          await Future.delayed(const Duration(milliseconds: 100));
          if (cancellable.isAvailable) {
            calledWhere = true;
          }
        },
      );
      expect(called, isFalse);
      expect(calledWhere, isFalse);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, isFalse);
      expect(calledWhere, isFalse);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(called, isTrue);
      expect(calledWhere, isFalse);

      registry.handleLifecycleEvent(LifecycleEvent.resume);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(called, isTrue);
      expect(calledWhere, isFalse);
    });

    test('.launchWhenLifecycleEventDestroy()', () {
      var called = false;
      var check = true;
      lifecycle.launchWhenLifecycleEventDestroy(block: (cancellable) {
        called = true;
        check = cancellable.isAvailable;
      });

      expect(called, false);
      expect(check, true);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, false);
      expect(check, true);
      registry.handleLifecycleEvent(LifecycleEvent.destroy);
      expect(called, true);
      expect(check, true);
    });

    test('.launchWhenLifecycleEventDestroy() runWithDelayed=true', () async {
      var called = false;
      var check = true;
      lifecycle.launchWhenLifecycleEventDestroy(
        runWithDelayed: true,
        block: (cancellable) {
          called = true;
          check = cancellable.isAvailable;
        },
      );

      expect(called, false);
      expect(check, true);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, false);
      expect(check, true);
      registry.handleLifecycleEvent(LifecycleEvent.destroy);
      expect(called, false);
      expect(check, true);
      await Future.delayed(Duration.zero);
      expect(called, true);
      expect(check, true);
    });

    test('.launchWhenLifecycleStateAtLeast()', () {
      var called = false;
      lifecycle.launchWhenLifecycleStateAtLeast(
          targetState: LifecycleState.started, block: (_) => called = true);
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, true);
      registry.handleLifecycleEvent(LifecycleEvent.resume);
      expect(called, true);
    });

    test('.launchWhenLifecycleStateAtLeast() owner', () {
      var called = false;
      owner.launchWhenLifecycleStateAtLeast(
          targetState: LifecycleState.started, block: (_) => called = true);
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, true);
      registry.handleLifecycleEvent(LifecycleEvent.resume);
      expect(called, true);
    });

    test('.launchWhenLifecycleStateAtLeast() twice', () {
      var called = 0;
      lifecycle.launchWhenLifecycleStateAtLeast(
          targetState: LifecycleState.started, block: (_) => called++);
      lifecycle.launchWhenLifecycleStateAtLeast(
          targetState: LifecycleState.started, block: (_) => called++);
      expect(called, 0);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, 2);
      registry.handleLifecycleEvent(LifecycleEvent.resume);
      expect(called, 2);
    });

    test('.launchWhenLifecycleStateAtLeast() not tigger', () {
      var called = false;
      lifecycle.launchWhenLifecycleStateAtLeast(
          targetState: LifecycleState.resumed, block: (_) => called = true);
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.stop);
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.destroy);
      expect(called, false);

      expect(registry.observers, isEmpty);
    });

    test('.launchWhenLifecycleStateAtLeast() cancel', () {
      var called = false;
      final cancellable = Cancellable();
      lifecycle.launchWhenLifecycleStateAtLeast(
          targetState: LifecycleState.started,
          cancellable: cancellable,
          block: (_) => called = true);
      expect(called, false);
      cancellable.cancel();
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, false);
    });

    test('.launchWhenLifecycleStateAtLeast() currStateAtLast', () {
      registry.handleLifecycleEvent(LifecycleEvent.start);
      var called = false;
      lifecycle.launchWhenLifecycleStateAtLeast(
          targetState: LifecycleState.started, block: (_) => called = true);
      expect(called, true);
      registry.handleLifecycleEvent(LifecycleEvent.resume);
      expect(called, true);
      registry.handleLifecycleEvent(LifecycleEvent.stop);
      expect(called, true);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, true);
    });

    test('.launchWhenLifecycleStateAtLeast() runWithDelayed=true', () async {
      var called = false;
      lifecycle.launchWhenLifecycleStateAtLeast(
          targetState: LifecycleState.started,
          runWithDelayed: true,
          block: (_) => called = true);

      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, false);
      await Future.delayed(Duration.zero);
      expect(called, true);
    });

    test('.launchWhenLifecycleStateAtLeast() block cancellable.cancel()', () {
      var called = 0;
      lifecycle.launchWhenLifecycleStateAtLeast(
          targetState: LifecycleState.started,
          block: (cancellable) {
            called++;
            cancellable.cancel();
          });

      expect(called, 0);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, 1);
      registry.handleLifecycleEvent(LifecycleEvent.stop);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, 1);
    });

    test('.launchWhenLifecycleStateAtLeast() block cancel run', () async {
      var called = false;
      lifecycle.launchWhenLifecycleStateAtLeast(
          targetState: LifecycleState.started,
          runWithDelayed: true,
          block: (cancellable) {
            called = true;
          });

      expect(called, isFalse);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, isFalse);
      registry.handleLifecycleEvent(LifecycleEvent.resume);
      expect(called, isFalse);
      await Future.delayed(Duration.zero);
      expect(called, isTrue);
    });

    test('.launchWhenLifecycleStateAtLeast() block cancel check', () async {
      var called = false;
      var calledWhere = false;
      lifecycle.launchWhenLifecycleStateAtLeast(
        targetState: LifecycleState.started,
        runWithDelayed: true,
        block: (cancellable) async {
          called = true;
          await Future.delayed(const Duration(milliseconds: 100));
          if (cancellable.isAvailable) {
            calledWhere = true;
          }
        },
      );
      expect(called, isFalse);
      expect(calledWhere, isFalse);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, isFalse);
      expect(calledWhere, isFalse);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(called, isTrue);
      expect(calledWhere, isFalse);

      registry.handleLifecycleEvent(LifecycleEvent.resume);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(called, isTrue);
      expect(calledWhere, isTrue);
    });

    test('.launchWhenLifecycleStateDestroyed()', () {
      var called = false;
      var check = true;
      lifecycle.launchWhenLifecycleStateDestroyed(block: (cancellable) {
        called = true;
        check = cancellable.isAvailable;
      });

      expect(called, false);
      expect(check, true);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, false);
      expect(check, true);
      registry.handleLifecycleEvent(LifecycleEvent.destroy);
      expect(called, true);
      expect(check, true);
    });

    test('.launchWhenLifecycleStateDestroyed() runWithDelayed=true', () async {
      var called = false;
      var check = true;
      lifecycle.launchWhenLifecycleStateDestroyed(
        runWithDelayed: true,
        block: (cancellable) {
          called = true;
          check = cancellable.isAvailable;
        },
      );

      expect(called, false);
      expect(check, true);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, false);
      expect(check, true);
      registry.handleLifecycleEvent(LifecycleEvent.destroy);
      expect(called, false);
      expect(check, true);
      await Future.delayed(Duration.zero);
      expect(called, true);
      expect(check, true);
    });

    test('.whenLifecycleStateAtLeast()', () async {
      var called = false;
      lifecycle
          .whenLifecycleStateAtLeast(LifecycleState.started)
          .then((cancellable) {
        called = true;
      });
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, true);
      expect(called, true);
      registry.handleLifecycleEvent(LifecycleEvent.resume);
      expect(called, true);
    });

    test('.whenLifecycleStateAtLeast() runWithDelayed=true', () async {
      var called = false;
      lifecycle
          .whenLifecycleStateAtLeast(LifecycleState.started,
              runWithDelayed: true)
          .then((cancellable) {
        called = true;
      });
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, false);
      await Future.delayed(Duration.zero);
      expect(called, true);
    });

    test('.whenLifecycleStateAtLeast() cancel', () async {
      var called = false;
      final cancellable = Cancellable();
      lifecycle
          .whenLifecycleStateAtLeast(LifecycleState.resumed,
              cancellable: cancellable)
          .then((cancellable) {
        called = true;
      });
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, false);
      cancellable.cancel();

      expect(registry.observers, isEmpty);
      registry.handleLifecycleEvent(LifecycleEvent.resume);
      expect(called, false);
    });

    test('.whenLifecycleNextEvent()', () {
      var called = false;
      lifecycle
          .whenLifecycleNextEvent(LifecycleEvent.start)
          .then((cancellable) {
        called = true;
      });
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, true);
      registry.handleLifecycleEvent(LifecycleEvent.resume);
      expect(called, true);
    });

    test('.whenLifecycleNextEvent() runWithDelayed=true', () async {
      var called = false;
      lifecycle
          .whenLifecycleNextEvent(LifecycleEvent.start, runWithDelayed: true)
          .then((cancellable) {
        called = true;
      });
      expect(called, false);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(called, false);
      await Future.delayed(Duration.zero);
      expect(called, true);
    });

    test('.repeatOnLifecycle()', () {
      var count = 0;
      lifecycle.repeatOnLifecycle(
          targetState: LifecycleState.started,
          block: (cancellable) {
            count++;
          });
      expect(count, 0);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(count, 1);
      registry.handleLifecycleEvent(LifecycleEvent.resume);
      expect(count, 1);
      registry.handleLifecycleEvent(LifecycleEvent.stop);
      expect(count, 1);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(count, 2);
      registry.handleLifecycleEvent(LifecycleEvent.destroy);
      expect(count, 2);

      expect(registry.observers, isEmpty);
    });

    test('.repeatOnLifecycle() runWithDelayed=true', () async {
      var count = 0;
      lifecycle.repeatOnLifecycle(
          targetState: LifecycleState.started,
          runWithDelayed: true,
          block: (cancellable) {
            count++;
          });
      expect(count, 0);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(count, 0);
      await Future.delayed(Duration.zero);
      expect(count, 1);
      registry.handleLifecycleEvent(LifecycleEvent.resume);
      expect(count, 1);
      registry.handleLifecycleEvent(LifecycleEvent.stop);
      expect(count, 1);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(count, 1);
      await Future.delayed(Duration.zero);
      expect(count, 2);
      registry.handleLifecycleEvent(LifecycleEvent.destroy);
      expect(count, 2);

      expect(registry.observers, isEmpty);
    });

    test('.repeatOnLifecycle() cancel', () {
      var count = 0;
      final cancellable = Cancellable();
      lifecycle.repeatOnLifecycle(
          targetState: LifecycleState.started,
          cancellable: cancellable,
          block: (cancellable) {
            count++;
          });
      expect(count, 0);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(count, 1);
      cancellable.cancel();
      registry.handleLifecycleEvent(LifecycleEvent.stop);
      expect(count, 1);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(count, 1);
      registry.handleLifecycleEvent(LifecycleEvent.destroy);
      expect(count, 1);

      expect(registry.observers, isEmpty);
    });

    test('.repeatOnLifecycle()  block cancel run', () async {
      var count = 0;
      lifecycle.repeatOnLifecycle(
          targetState: LifecycleState.started,
          runWithDelayed: true,
          block: (cancellable) {
            count++;
          });
      expect(count, 0);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(count, 0);
      registry.handleLifecycleEvent(LifecycleEvent.resume);
      expect(count, 0);
      await Future.delayed(Duration.zero);
      expect(count, 1);
      registry.handleLifecycleEvent(LifecycleEvent.stop);
      expect(count, 1);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(count, 1);
      registry.handleLifecycleEvent(LifecycleEvent.stop);
      expect(count, 1);
      await Future.delayed(Duration.zero);
      expect(count, 1);
      registry.handleLifecycleEvent(LifecycleEvent.destroy);
      expect(count, 1);

      expect(registry.observers, isEmpty);
    });

    test('.repeatOnLifecycle() block cancel check', () async {
      var count = 0;
      var countWhere = 0;
      lifecycle.repeatOnLifecycle(
        targetState: LifecycleState.started,
        block: (cancellable) async {
          count++;
          await Future.delayed(const Duration(milliseconds: 100));
          if (cancellable.isAvailable) {
            countWhere++;
          }
        },
      );
      expect(count, 0);
      expect(countWhere, 0);
      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(count, 1);
      expect(countWhere, 0);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(count, 1);
      expect(countWhere, 0);
      registry.handleLifecycleEvent(LifecycleEvent.resume);
      expect(count, 1);
      expect(countWhere, 0);
      await Future.delayed(const Duration(milliseconds: 150));
      expect(count, 1);
      expect(countWhere, 1);

      registry.handleLifecycleEvent(LifecycleEvent.stop);
      expect(count, 1);
      expect(countWhere, 1);

      registry.handleLifecycleEvent(LifecycleEvent.start);
      expect(count, 2);
      expect(countWhere, 1);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(count, 2);
      expect(countWhere, 1);
      registry.handleLifecycleEvent(LifecycleEvent.stop);
      expect(count, 2);
      expect(countWhere, 1);
      await Future.delayed(const Duration(milliseconds: 150));
      expect(count, 2);
      expect(countWhere, 1);

      registry.handleLifecycleEvent(LifecycleEvent.destroy);
      expect(count, 2);
      expect(countWhere, 1);

      expect(registry.observers, isEmpty);
    });

    test('.findLifecycleOwner()', () {
      final scop = LifecycleOwnerMock('scop');
      scop.lifecycleRegistry.handleLifecycleEvent(LifecycleEvent.create);
      scop.lifecycleRegistry.bindParentLifecycle(lifecycle);
      final scop2 = LifecycleOwnerMock('scop2');
      scop2.lifecycleRegistry.handleLifecycleEvent(LifecycleEvent.create);
      scop2.lifecycleRegistry.bindParentLifecycle(lifecycle);

      final scop3 = LifecycleOwnerMock('scop3');
      scop3.lifecycleRegistry.handleLifecycleEvent(LifecycleEvent.create);
      scop3.lifecycleRegistry.bindParentLifecycle(scop2.lifecycle);

      var find = scop3.findLifecycleOwner();
      expect(find, scop3);

      find = scop3.findLifecycleOwner(test: (owner) => owner.scope == 'scop2');
      expect(find, scop2);

      final top = scop3.findLifecycleOwner<LifecycleOwner>(
          test: (owner) => owner.lifecycle.parent == null);
      expect(top, owner);

      find = scop3.findLifecycleOwner(test: (owner) => owner.scope == 'scop');
      expect(find, isNull);
    });
  });
}
