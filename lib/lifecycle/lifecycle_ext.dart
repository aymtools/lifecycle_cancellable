import 'dart:async';

import 'package:anlifecycle/anlifecycle.dart';
import 'package:cancellable/cancellable.dart';
import 'package:cancellable/src/tools/never_exec_future.dart';
import 'package:flutter/material.dart';

abstract class _LifecycleEventObserverWrapper
    implements LifecycleEventObserver {
  @override
  void onAnyEvent(LifecycleOwner owner, LifecycleEvent event) {}

  @override
  void onCreate(LifecycleOwner owner) {}

  @override
  void onDestroy(LifecycleOwner owner) {}

  @override
  void onPause(LifecycleOwner owner) {}

  @override
  void onResume(LifecycleOwner owner) {}

  @override
  void onStart(LifecycleOwner owner) {}

  @override
  void onStop(LifecycleOwner owner) {}
}

extension LifecycleObserverRegistryX on LifecycleObserverRegistry {
  @Deprecated('use [launchWhenLifecycleStateAtLeast]')
  Future<LifecycleState> whenMoreThanState(LifecycleState state) =>
      currentLifecycleState >= state
          ? Future.value(currentLifecycleState)
          : nextLifecycleState(state);

  Future<LifecycleEvent> whenFirstStart() =>
      whenMoreThanState(LifecycleState.started)
          .then((value) => LifecycleEvent.start);

  Future<LifecycleEvent> whenFirstResume() =>
      whenMoreThanState(LifecycleState.resumed)
          .then((value) => LifecycleEvent.resume);
}

extension LifecycleObserverRegistryMixinContextExt
    on LifecycleObserverRegistryMixin {
  Future<BuildContext> get requiredContext =>
      whenMoreThanState(LifecycleState.started).then((_) => context);

  Future<S> requiredState<S extends State>() => requiredContext.then((value) {
        if (value is StatefulElement && value.state is S) {
          return value.state as S;
        }
        return Future<S>.value(value.findAncestorStateOfType<S>());
      });
}

final Map<LifecycleObserverRegistry, _CacheMapObserver> _map = {};

class _CacheMapObserver with _LifecycleEventObserverWrapper {
  final Cancellable _cancellable;
  final LifecycleObserverRegistry registryMixin;
  final Set<Cancellable> _liveCancellable = {};

  Cancellable _makeCancellableForLive({Cancellable? other}) {
    final cancellable =
        _cancellable.makeCancellable(infectious: false, father: other);

    if (cancellable.isAvailable) {
      cancellable.whenCancel
          .bindCancellable(_cancellable)
          .then((_) => _liveCancellable.remove(cancellable));
      _liveCancellable.add(cancellable);
    }

    return cancellable;
  }

  _CacheMapObserver(this.registryMixin) : _cancellable = Cancellable() {
    registryMixin.addLifecycleObserver(this, fullCycle: true);
    _cancellable.onCancel.then((value) => _map.remove(registryMixin));
  }

  @override
  void onDestroy(LifecycleOwner owner) {
    super.onDestroy(owner);
    _cancellable.cancel();
    _liveCancellable.clear();
  }
}

extension LifecycleObserverRegistryCacnellable on LifecycleObserverRegistry {
  /// 构建一个绑定到lifecycle的Cancellable
  Cancellable makeLiveCancellable({Cancellable? other}) {
    assert(currentLifecycleState > LifecycleState.destroyed,
        'Must be used before destroyed.');
    if (currentLifecycleState <= LifecycleState.destroyed) {
      return Cancellable()..cancel();
    }
    return _map
        .putIfAbsent(this, () => _CacheMapObserver(this))
        ._makeCancellableForLive(other: other);
  }

  /// 当高于某个状态时执行给定的block
  void repeatOnLifecycle<T>(
      {LifecycleState targetState = LifecycleState.started,
      bool runWithDelayed = false,
      Cancellable? cancellable,
      required FutureOr<T> Function(Cancellable cancellable) block}) {
    if (cancellable?.isUnavailable == true) return;
    Cancellable? checkable;
    final observer = LifecycleObserver.stateChange((state) async {
      if (state >= targetState &&
          (checkable == null || checkable?.isUnavailable == true)) {
        checkable = makeLiveCancellable(other: cancellable);
        try {
          if (runWithDelayed) {
            //转到下一个事件循环，可以过滤掉连续的状态变化
            await Future.delayed(Duration.zero);
          }
          if (checkable!.isUnavailable) return;
          final result = block(checkable!);
          if (result is Future<T>) {
            await Future.delayed(Duration.zero);
            if (checkable?.isAvailable == true) await result;
          }
        } catch (_) {}
      } else if (state < targetState && checkable?.isAvailable == true) {
        checkable?.cancel();
        checkable = null;
      }
    });
    addLifecycleObserver(observer, fullCycle: true);
    cancellable?.whenCancel
        .then((value) => removeLifecycleObserver(observer, fullCycle: false));
  }

  ///当高于某个状态时执行给定的block,并将结构收集起来为Stream
  Stream<T> collectOnLifecycle<T>(
      {LifecycleState targetState = LifecycleState.started,
      bool runWithDelayed = false,
      Cancellable? cancellable,
      required FutureOr<T> Function(Cancellable cancellable) block}) {
    if (cancellable?.isUnavailable == true) return Stream<T>.empty();

    StreamController<T> controller = StreamController();
    controller.bindCancellable(makeLiveCancellable(other: cancellable));

    Cancellable? checkable;
    final observer = LifecycleObserver.stateChange((state) async {
      if (state >= targetState &&
          (checkable == null || checkable?.isUnavailable == true)) {
        checkable = makeLiveCancellable(other: cancellable);
        try {
          if (runWithDelayed) {
            //转到下一个事件循环，可以过滤掉连续的状态变化
            await Future.delayed(Duration.zero);
          }
          if (checkable!.isUnavailable) return;
          final result = block(checkable!);
          if (result is Future<T>) {
            await Future.delayed(Duration.zero);
            if (checkable?.isAvailable == true) {
              final r = await result;
              if (checkable?.isAvailable == true) controller.add(r);
            }
          } else {
            controller.add(result);
          }
        } catch (_) {}
      } else if (state < targetState && checkable?.isAvailable == true) {
        checkable?.cancel();
        checkable = null;
      }
    });

    addLifecycleObserver(observer, fullCycle: true);

    cancellable?.whenCancel
        .then((value) => removeLifecycleObserver(observer, fullCycle: false));

    return controller.stream;
  }

  /// 当下一个事件分发时，执行一次给定的block
  Future<T> launchWhenNextLifecycleEvent<T>(
      {LifecycleEvent targetEvent = LifecycleEvent.start,
      bool runWithDelayed = false,
      Cancellable? cancellable,
      required FutureOr<T> Function(Cancellable cancellable) block}) {
    Completer<T> completer = Completer();
    late final LifecycleObserver observer;
    Cancellable? checkable;
    observer = LifecycleObserver.eventAny((event) async {
      if (event == targetEvent && checkable == null) {
        checkable = makeLiveCancellable(other: cancellable);
        try {
          if (runWithDelayed) {
            await Future.delayed(Duration.zero);
          }
          if (checkable!.isUnavailable) {
            removeLifecycleObserver(observer, fullCycle: false);
            return;
          }
          checkable!.whenCancel.then(
              (value) => removeLifecycleObserver(observer, fullCycle: false));

          final result = block(checkable!);
          if (result is Future<T>) {
            await Future.delayed(Duration.zero);
            if (checkable?.isAvailable == true) {
              final r = await result;
              if (checkable?.isAvailable == true && !completer.isCompleted) {
                completer.complete(r);
              }
            }
          } else {
            completer.complete(result);
          }
        } catch (error, stackTree) {
          if (error != checkable?.reasonAsException && !completer.isCompleted) {
            completer.completeError(error, stackTree);
          }
        }
      } else if (checkable?.isAvailable == true) {
        checkable?.cancel();
      }
    });

    addLifecycleObserver(observer,
        startWith: currentLifecycleState, fullCycle: true);

    final result = completer.future;

    result.whenComplete(
        () => removeLifecycleObserver(observer, fullCycle: false));
    return result;
  }

  /// 当高于某个状态时，执行一次给定的block
  Future<T> launchWhenLifecycleStateAtLeast<T>(
      {LifecycleState targetState = LifecycleState.started,
      bool runWithDelayed = false,
      Cancellable? cancellable,
      required FutureOr<T> Function(Cancellable cancellable) block}) {
    if (runWithDelayed == true && currentLifecycleState >= targetState) {
      Cancellable checkable = makeLiveCancellable(other: cancellable);
      if (checkable.isUnavailable) {
        return NeverExecFuture();
      }
      var result = block(checkable);
      if (result is Future<T>) {
        late final LifecycleObserver observer;
        observer = LifecycleObserver.stateChange((state) {
          if (state < targetState && checkable.isAvailable == true) {
            checkable.cancel();
            removeLifecycleObserver(observer, fullCycle: false);
          }
        });
        addLifecycleObserver(observer,
            fullCycle: true, startWith: currentLifecycleState);
        result.whenComplete(
            () => removeLifecycleObserver(observer, fullCycle: false));
        return result;
      } else {
        return Future.sync(() => result);
      }
    }

    Completer<T> completer = runWithDelayed ? Completer() : Completer.sync();

    Cancellable? checkable;
    late final LifecycleObserver observer;
    observer = LifecycleObserver.stateChange((state) async {
      if (state >= targetState && checkable == null) {
        checkable = makeLiveCancellable(other: cancellable);
        try {
          if (runWithDelayed) {
            await Future.delayed(Duration.zero);
          }
          if (checkable!.isUnavailable) {
            removeLifecycleObserver(observer, fullCycle: false);
            return;
          }
          checkable!.whenCancel.then(
              (value) => removeLifecycleObserver(observer, fullCycle: false));

          final result = block(checkable!);
          if (result is Future<T>) {
            await Future.delayed(Duration.zero);
            if (checkable?.isAvailable == true) {
              final r = await result;
              if (checkable?.isAvailable == true && !completer.isCompleted) {
                completer.complete(r);
              }
            }
          } else {
            completer.complete(result);
          }
        } catch (error, stackTree) {
          if (error != checkable?.reasonAsException && !completer.isCompleted) {
            completer.completeError(error, stackTree);
          }
        }
      } else if (state < targetState && checkable?.isAvailable == true) {
        checkable?.cancel();
      }
    });

    addLifecycleObserver(observer, fullCycle: true);
    final result = completer.future;
    result.whenComplete(
        () => removeLifecycleObserver(observer, fullCycle: false));
    return result;
  }

  void repeatOnLifecycleStarted<T>(
          {bool runWithDelayed = false,
          Cancellable? cancellable,
          required FutureOr<T> Function(Cancellable cancellable) block}) =>
      repeatOnLifecycle(
          targetState: LifecycleState.started,
          runWithDelayed: runWithDelayed,
          cancellable: cancellable,
          block: block);

  void repeatOnLifecycleResumed<T>(
          {bool runWithDelayed = false,
          Cancellable? cancellable,
          required FutureOr<T> Function(Cancellable cancellable) block}) =>
      repeatOnLifecycle(
          targetState: LifecycleState.resumed,
          runWithDelayed: runWithDelayed,
          cancellable: cancellable,
          block: block);

  Stream<T> collectOnLifecycleStarted<T>(
          {bool runWithDelayed = false,
          Cancellable? cancellable,
          required FutureOr<T> Function(Cancellable cancellable) block}) =>
      collectOnLifecycle(
          targetState: LifecycleState.started,
          runWithDelayed: runWithDelayed,
          cancellable: cancellable,
          block: block);

  Stream<T> collectOnLifecycleResumed<T>(
          {bool runWithDelayed = false,
          Cancellable? cancellable,
          required FutureOr<T> Function(Cancellable cancellable) block}) =>
      collectOnLifecycle(
          targetState: LifecycleState.resumed,
          runWithDelayed: runWithDelayed,
          cancellable: cancellable,
          block: block);

  Future<T> launchWhenNextLifecycleEventStart<T>(
          {bool runWithDelayed = false,
          Cancellable? cancellable,
          required FutureOr<T> Function(Cancellable cancellable) block}) =>
      launchWhenNextLifecycleEvent(
          targetEvent: LifecycleEvent.start,
          runWithDelayed: runWithDelayed,
          cancellable: cancellable,
          block: block);

  Future<T> launchWhenNextLifecycleEventResume<T>(
          {bool runWithDelayed = false,
          Cancellable? cancellable,
          required FutureOr<T> Function(Cancellable cancellable) block}) =>
      launchWhenNextLifecycleEvent(
          targetEvent: LifecycleEvent.resume,
          runWithDelayed: runWithDelayed,
          cancellable: cancellable,
          block: block);

  Future<T> launchWhenLifecycleStateStarted<T>(
          {bool runWithDelayed = false,
          Cancellable? cancellable,
          required FutureOr<T> Function(Cancellable cancellable) block}) =>
      launchWhenLifecycleStateAtLeast(
          targetState: LifecycleState.started,
          runWithDelayed: runWithDelayed,
          cancellable: cancellable,
          block: block);

  Future<T> launchWhenLifecycleStateResumed<T>(
          {bool runWithDelayed = false,
          Cancellable? cancellable,
          required FutureOr<T> Function(Cancellable cancellable) block}) =>
      launchWhenLifecycleStateAtLeast(
          targetState: LifecycleState.resumed,
          runWithDelayed: runWithDelayed,
          cancellable: cancellable,
          block: block);

  Future<T> launchWhenLifecycleStateDestroyed<T>(
      {bool runWithDelayed = false,
      Cancellable? cancellable,
      required FutureOr<T> Function(Cancellable cancellable) block}) {
    Completer<T> completer = Completer.sync();
    addLifecycleObserver(LifecycleObserver.stateChange((state) {
      if (state == LifecycleState.destroyed &&
          !completer.isCompleted &&
          cancellable?.isUnavailable != true) {
        completer.complete(block(cancellable ?? Cancellable()));
      }
    }));
    return completer.future;
  }

  Future<T> launchWhenLifecycleEventDestroy<T>(
      {bool runWithDelayed = false,
      Cancellable? cancellable,
      required FutureOr<T> Function(Cancellable cancellable) block}) {
    Completer<T> completer = Completer.sync();
    addLifecycleObserver(LifecycleObserver.eventDestroy(() {
      if (!completer.isCompleted && cancellable?.isUnavailable != true) {
        completer.complete(block(cancellable ?? Cancellable()));
      }
    }));
    return completer.future;
  }
}
