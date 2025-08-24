import 'dart:async';

import 'package:anlifecycle/anlifecycle.dart';
import 'package:cancellable/cancellable.dart';
import 'package:flutter/widgets.dart';
import 'package:weak_collections/weak_collections.dart';

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

@Deprecated('Will be removed')
extension LifecycleObserverRegistryX on LifecycleObserverRegistry {
  @Deprecated('use [launchWhenLifecycleStateAtLeast]')
  Future<LifecycleState> whenMoreThanState(LifecycleState state) =>
      currentLifecycleState >= state
          ? Future.value(currentLifecycleState)
          : nextLifecycleState(state);

  @Deprecated('use [launchWhenLifecycleStateStarted]')
  Future<LifecycleEvent> whenFirstStart() =>
      whenMoreThanState(LifecycleState.started)
          .then((value) => LifecycleEvent.start);

  @Deprecated('use [launchWhenLifecycleStateResumed]')
  Future<LifecycleEvent> whenFirstResume() =>
      whenMoreThanState(LifecycleState.resumed)
          .then((value) => LifecycleEvent.resume);
}

@Deprecated('Will be removed')
extension LifecycleObserverRegistryMixinContextExt
    on LifecycleObserverRegistryMixin {
  @Deprecated('Will be removed')
  Future<BuildContext> get requiredContext =>
      whenMoreThanState(LifecycleState.started).then((_) => context);

  @Deprecated('Will be removed')
  Future<S> requiredState<S extends State>() => requiredContext.then((value) {
        if (value is StatefulElement && value.state is S) {
          return value.state as S;
        }
        return Future<S>.value(value.findAncestorStateOfType<S>());
      });
}

final Map<ILifecycle, _LiveCancellableManagerObserver> _map = WeakHashMap();

class _LiveCancellableManagerObserver with _LifecycleEventObserverWrapper {
  final Cancellable _cancellable;
  final WeakReference<ILifecycle> _lifecycle;

  Cancellable _makeCancellableForLive({Cancellable? other}) => _cancellable
      .makeCancellable(infectious: false, father: other, weakRef: false);

  _LiveCancellableManagerObserver(ILifecycle lifecycle)
      : _lifecycle = WeakReference(lifecycle),
        _cancellable = Cancellable() {
    if (lifecycle is LifecycleOwner) {
      final l = lifecycle.lifecycle;
      l.addLifecycleObserver(this, fullCycle: true);
    } else {
      lifecycle.addLifecycleObserver(this, fullCycle: true);
    }
  }

  @override
  void onDestroy(LifecycleOwner owner) {
    super.onDestroy(owner);
    _map.remove(_lifecycle.target);
    _cancellable.cancel();
  }
}

extension LifecycleObserverRegistryCacnellable on ILifecycle {
  /// 构建一个绑定到[lifecycle]的[Cancellable]
  Cancellable makeLiveCancellable({Cancellable? other}) {
    assert(currentLifecycleState > LifecycleState.destroyed,
        'Must be used before destroyed.');
    if (currentLifecycleState <= LifecycleState.destroyed) {
      return Cancellable()..cancel();
    }
    return _map
        .putIfAbsent(this, () => _LiveCancellableManagerObserver(this))
        ._makeCancellableForLive(other: other);
  }

  /// 当高于某个状态时执行给定的block
  /// * [ignoreBlockError]是否忽略错误 值为 false 时直接报错
  void repeatOnLifecycle<T>(
      {LifecycleState targetState = LifecycleState.started,
      bool runWithDelayed = false,
      bool ignoreBlockError = false,
      Cancellable? cancellable,
      required FutureOr<T> Function(Cancellable cancellable) block}) {
    if (cancellable?.isUnavailable == true) return;
    Cancellable? checkable;
    final observer = LifecycleObserver.stateChange((state) async {
      if (state >= targetState &&
          (checkable == null || checkable?.isUnavailable == true)) {
        final able = makeLiveCancellable(other: cancellable);
        checkable = able;
        try {
          if (runWithDelayed) {
            //转到下一个事件循环，可以过滤掉连续的状态变化
            await Future.delayed(Duration.zero);
          }
          if (able.isUnavailable) return;
          final result = block(able);
          if (result is Future<T>) {
            await Future.delayed(Duration.zero);
            if (able.isAvailable) await result;
          }
        } catch (exception, stack) {
          if (!ignoreBlockError) {
            FlutterError.reportError(FlutterErrorDetails(
              exception: exception,
              stack: stack,
              library: 'an_lifecycle_cancellable',
              context: ErrorDescription('repeatOnLifecycle run block error'),
            ));
          }
        }
      } else if (state < targetState && checkable?.isAvailable == true) {
        checkable?.cancel();
        checkable = null;
      }
    });
    addLifecycleObserver(observer, fullCycle: true);
    cancellable?.onCancel
        .then((value) => removeLifecycleObserver(observer, fullCycle: false));
  }

  ///当高于某个状态时执行给定的block,并将结果收集起来为Stream
  ///* [collectBlockError] 当发生错误时将错误也收集起来,值为 false 时[ignoreBlockError]有效
  ///* [ignoreBlockError]是否忽略错误 值为 false 时直接报错
  Stream<T> collectOnLifecycle<T>(
      {LifecycleState targetState = LifecycleState.started,
      bool runWithDelayed = false,
      bool collectBlockError = false,
      bool ignoreBlockError = false,
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
        } catch (exception, stack) {
          if (collectBlockError) {
            controller.addError(exception, stack);
          } else if (!ignoreBlockError) {
            FlutterError.reportError(FlutterErrorDetails(
              exception: exception,
              stack: stack,
              library: 'an_lifecycle_cancellable',
              context: ErrorDescription('collectOnLifecycle run block error'),
            ));
          }
        }
      } else if (state < targetState && checkable?.isAvailable == true) {
        checkable?.cancel();
        checkable = null;
      }
    });

    addLifecycleObserver(observer, fullCycle: true);

    controller.onCancel =
        () => removeLifecycleObserver(observer, fullCycle: false);

    cancellable?.onCancel
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

    cancellable?.onCancel
        .then((value) => removeLifecycleObserver(observer, fullCycle: false));
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
        return Completer<T>().future;
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

    cancellable?.onCancel
        .then((value) => removeLifecycleObserver(observer, fullCycle: false));
    return result;
  }

  void repeatOnLifecycleStarted<T>(
          {bool runWithDelayed = false,
          bool ignoreBlockError = false,
          Cancellable? cancellable,
          required FutureOr<T> Function(Cancellable cancellable) block}) =>
      repeatOnLifecycle(
          targetState: LifecycleState.started,
          runWithDelayed: runWithDelayed,
          ignoreBlockError: ignoreBlockError,
          cancellable: cancellable,
          block: block);

  void repeatOnLifecycleResumed<T>(
          {bool runWithDelayed = false,
          bool ignoreBlockError = false,
          Cancellable? cancellable,
          required FutureOr<T> Function(Cancellable cancellable) block}) =>
      repeatOnLifecycle(
          targetState: LifecycleState.resumed,
          runWithDelayed: runWithDelayed,
          ignoreBlockError: ignoreBlockError,
          cancellable: cancellable,
          block: block);

  Stream<T> collectOnLifecycleStarted<T>(
          {bool runWithDelayed = false,
          bool collectBlockError = false,
          bool ignoreBlockError = false,
          Cancellable? cancellable,
          required FutureOr<T> Function(Cancellable cancellable) block}) =>
      collectOnLifecycle(
          targetState: LifecycleState.started,
          runWithDelayed: runWithDelayed,
          collectBlockError: collectBlockError,
          ignoreBlockError: ignoreBlockError,
          cancellable: cancellable,
          block: block);

  Stream<T> collectOnLifecycleResumed<T>(
          {bool runWithDelayed = false,
          bool collectBlockError = false,
          bool ignoreBlockError = false,
          Cancellable? cancellable,
          required FutureOr<T> Function(Cancellable cancellable) block}) =>
      collectOnLifecycle(
          targetState: LifecycleState.resumed,
          runWithDelayed: runWithDelayed,
          collectBlockError: collectBlockError,
          ignoreBlockError: ignoreBlockError,
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

  Future<T> launchWhenNextLifecycleEventPause<T>(
          {bool runWithDelayed = false,
          Cancellable? cancellable,
          required FutureOr<T> Function(Cancellable cancellable) block}) =>
      launchWhenNextLifecycleEvent(
          targetEvent: LifecycleEvent.pause,
          runWithDelayed: runWithDelayed,
          cancellable: cancellable,
          block: block);

  Future<T> launchWhenNextLifecycleEventStop<T>(
          {bool runWithDelayed = false,
          Cancellable? cancellable,
          required FutureOr<T> Function(Cancellable cancellable) block}) =>
      launchWhenNextLifecycleEvent(
          targetEvent: LifecycleEvent.stop,
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
    Completer<T> completer = runWithDelayed ? Completer() : Completer.sync();
    final observer = LifecycleObserver.stateChange((state) {
      if (state == LifecycleState.destroyed &&
          !completer.isCompleted &&
          cancellable?.isUnavailable != true) {
        completer.complete(block(cancellable ?? Cancellable()));
      }
    });
    addLifecycleObserver(observer);
    cancellable?.onCancel
        .then((_) => removeLifecycleObserver(observer, fullCycle: false));
    return completer.future;
  }

  Future<T> launchWhenLifecycleEventDestroy<T>(
      {bool runWithDelayed = false,
      Cancellable? cancellable,
      required FutureOr<T> Function(Cancellable cancellable) block}) {
    Completer<T> completer = runWithDelayed ? Completer() : Completer.sync();
    final observer = LifecycleObserver.eventDestroy(() {
      if (!completer.isCompleted && cancellable?.isUnavailable != true) {
        completer.complete(block(cancellable ?? Cancellable()));
      }
    });
    addLifecycleObserver(observer);

    cancellable?.onCancel
        .then((value) => removeLifecycleObserver(observer, fullCycle: false));
    return completer.future;
  }

  Future<Cancellable> whenLifecycleStateAtLeast(LifecycleState state,
          {bool runWithDelayed = false, Cancellable? cancellable}) =>
      launchWhenLifecycleStateAtLeast(
          targetState: state,
          runWithDelayed: runWithDelayed,
          cancellable: cancellable,
          block: (c) => c);

  Future<Cancellable> whenLifecycleStateStarted(
          {bool runWithDelayed = false, Cancellable? cancellable}) =>
      whenLifecycleStateAtLeast(LifecycleState.started,
          runWithDelayed: runWithDelayed, cancellable: cancellable);

  Future<Cancellable> whenLifecycleStateResumed(
          {bool runWithDelayed = true, Cancellable? cancellable}) =>
      whenLifecycleStateAtLeast(LifecycleState.started,
          runWithDelayed: runWithDelayed, cancellable: cancellable);

  Future<Cancellable> whenLifecycleNextEvent(LifecycleEvent event,
          {bool runWithDelayed = false, Cancellable? cancellable}) =>
      launchWhenNextLifecycleEvent(
          targetEvent: event,
          runWithDelayed: runWithDelayed,
          cancellable: cancellable,
          block: (c) => c);

  Future<Cancellable> whenLifecycleNextEventStart(
          {bool runWithDelayed = false, Cancellable? cancellable}) =>
      whenLifecycleNextEvent(LifecycleEvent.start,
          runWithDelayed: runWithDelayed, cancellable: cancellable);

  Future<Cancellable> whenLifecycleNextEventResume(
          {bool runWithDelayed = true, Cancellable? cancellable}) =>
      whenLifecycleNextEvent(LifecycleEvent.resume,
          runWithDelayed: runWithDelayed, cancellable: cancellable);

  Future<Cancellable> whenLifecycleNextEventPause(
          {bool runWithDelayed = false, Cancellable? cancellable}) =>
      whenLifecycleNextEvent(LifecycleEvent.pause,
          runWithDelayed: runWithDelayed, cancellable: cancellable);

  Future<Cancellable> whenLifecycleNextEventStop(
          {bool runWithDelayed = false, Cancellable? cancellable}) =>
      whenLifecycleNextEvent(LifecycleEvent.stop,
          runWithDelayed: runWithDelayed, cancellable: cancellable);

  Future<Cancellable> whenLifecycleDestroy({Cancellable? cancellable}) =>
      launchWhenLifecycleEventDestroy(
          cancellable: cancellable, block: (c) => c);
}

extension LifecycleFinderExt on ILifecycle {
  /// 从当前环境中向上寻找特定的 [LifecycleOwner]
  LO? findLifecycleOwner<LO extends LifecycleOwner>({bool Function(LO)? test}) {
    Lifecycle? life = toLifecycle();
    if (test == null) {
      while (life != null) {
        if (life.owner is LO) {
          return (life.owner as LO);
        }
        life = life.parent;
      }
      return null;
    }
    while (life != null) {
      if (life.owner is LO && test((life.owner as LO))) {
        return (life.owner as LO);
      }
      life = life.parent;
    }
    return null;
  }
}
