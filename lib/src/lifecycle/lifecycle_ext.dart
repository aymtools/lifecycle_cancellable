import 'dart:async';

import 'package:anlifecycle/anlifecycle.dart';
import 'package:cancellable/cancellable.dart';
import 'package:flutter/foundation.dart';
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
        // ignore: use_build_context_synchronously
        return Future<S>.value(value.findAncestorStateOfType<S>());
      });
}

final Map<ILifecycle, _LiveCancellableManagerObserver> _map =
    WeakHashMap.identity();

class _LiveCancellableManagerObserver with _LifecycleEventObserverWrapper {
  final Cancellable _cancellable;
  final WeakReference<ILifecycle> _lifecycle;

  Cancellable _makeCancellableForLive(Cancellable? other, bool weakRef) =>
      _cancellable.makeCancellable(
          infectious: false, father: other, weakRef: weakRef);

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
  /// *[weakRef] 是否是弱引用的 保持兼容性为 false 将在3.0版本改为 true
  Cancellable makeLiveCancellable({Cancellable? other, bool weakRef = false}) {
    // 不在需要进行断言 destroy 时返回一个已经cancel的cancellable
    // assert(currentLifecycleState > LifecycleState.destroyed,
    //     'Must be used before destroyed.');
    //  放开assert允许当前已经销毁的状态下 直接返回一个 cancelled的
    if (currentLifecycleState <= LifecycleState.destroyed ||
        other?.isUnavailable == true) {
      return Cancellable()..cancel();
    }
    return _map
        .putIfAbsent(this, () => _LiveCancellableManagerObserver(this))
        ._makeCancellableForLive(other, weakRef);
  }

  /// 当高于某个状态时执行给定的block
  /// * [ignoreBlockError]是否忽略错误 值为 false 时直接报错
  void repeatOnLifecycle<T>(
      {LifecycleState targetState = LifecycleState.started,
      bool runWithDelayed = false,
      bool ignoreBlockError = false,
      Cancellable? cancellable,
      required FutureOr<T> Function(Cancellable cancellable) block}) {
    if (currentLifecycleState == LifecycleState.destroyed ||
        cancellable?.isUnavailable == true) {
      return;
    }

    /// 调用一下makeLiveCancellable 保证makeLiveCancellable 一定会在observer之前生成
    final liveable = makeLiveCancellable(other: cancellable);

    assert(targetState > LifecycleState.initialized,
        'targetState must be greater than initialized');
    if (targetState < LifecycleState.created) {
      launchWhenLifecycleStateAtLeast(
        targetState: LifecycleState.created,
        runWithDelayed: runWithDelayed,
        cancellable: cancellable,
        block: block,
      );
      return;
    }

    Cancellable? checkable;
    final observer = LifecycleObserver.stateChange((state) async {
      if (state >= targetState &&
          liveable.isAvailable &&
          (checkable == null || checkable?.isUnavailable == true)) {
        final able = liveable.makeCancellable();
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
    if (this is LifecycleRegistryState) {
      /// 由于代管理者会直接销毁 需要特殊处理
      liveable.onCancel
          .then((value) => removeLifecycleObserver(observer, fullCycle: false));
    } else {
      cancellable?.onCancel
          .then((value) => removeLifecycleObserver(observer, fullCycle: false));
    }
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
    if (currentLifecycleState == LifecycleState.destroyed ||
        cancellable?.isUnavailable == true) {
      return Stream<T>.empty();
    }

    assert(targetState > LifecycleState.destroyed,
        'targetState must be greater than initialized');

    /// 调用一下makeLiveCancellable 保证makeLiveCancellable 一定会在observer之前生成 保证优先级
    final liveable = makeLiveCancellable(other: cancellable);

    StreamController<T> controller = StreamController();
    controller.bindCancellable(liveable);

    if (targetState < LifecycleState.created) {
      launchWhenLifecycleStateAtLeast(
        targetState: LifecycleState.created,
        runWithDelayed: runWithDelayed,
        cancellable: cancellable,
        block: block,
      ).then(controller.add).catchError(controller.addError);
      return controller.stream;
    }

    Cancellable? checkable;
    final observer = LifecycleObserver.stateChange((state) async {
      if (state >= targetState &&
          (checkable == null || checkable?.isUnavailable == true)) {
        final able = liveable.makeCancellable();
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
            if (able.isAvailable == true) {
              final r = await result;
              if (able.isAvailable == true) controller.add(r);
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

    if (this is LifecycleRegistryState) {
      /// 由于代管理者会直接销毁 需要特殊处理
      liveable.onCancel
          .then((value) => removeLifecycleObserver(observer, fullCycle: false));
    } else {
      cancellable?.onCancel
          .then((value) => removeLifecycleObserver(observer, fullCycle: false));
    }
    return controller.stream;
  }

  /// 当下一个事件分发时，执行一次给定的block
  Future<T> launchWhenNextLifecycleEvent<T>(
      {LifecycleEvent targetEvent = LifecycleEvent.start,
      bool runWithDelayed = false,
      Cancellable? cancellable,
      required FutureOr<T> Function(Cancellable cancellable) block}) {
    if (currentLifecycleState == LifecycleState.destroyed ||
        cancellable?.isUnavailable == true) {
      return Completer<T>().future;
    }

    assert(targetEvent != LifecycleEvent.destroy,
        'must use launchWhenLifecycleEventDestroy');

    /// 调用一下makeLiveCancellable 保证makeLiveCancellable 一定会在observer之前生成 保证优先级
    final liveable = makeLiveCancellable(other: cancellable);

    if (targetEvent == LifecycleEvent.destroy) {
      return launchWhenLifecycleEventDestroy(
          runWithDelayed: runWithDelayed,
          cancellable: cancellable,
          block: block);
    }

    Completer<T> completer = runWithDelayed ? Completer() : Completer.sync();
    late final LifecycleObserver observer;
    Cancellable? checkable;
    observer = LifecycleObserver.eventAny((event) async {
      if (event == targetEvent && liveable.isAvailable && checkable == null) {
        final able = liveable.makeCancellable();
        checkable = able;
        try {
          if (runWithDelayed) {
            await Future.delayed(Duration.zero);
          }
          if (able.isUnavailable) {
            // removeLifecycleObserver(observer, fullCycle: false);
            return;
          }
          able.whenCancel.then(
              (value) => removeLifecycleObserver(observer, fullCycle: false));

          final result = block(able);
          if (result is Future<T>) {
            await Future.delayed(Duration.zero);
            if (able.isAvailable == true) {
              final r = await result;
              if (able.isAvailable == true && !completer.isCompleted) {
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
        checkable = null;
      }
    });

    addLifecycleObserver(observer,
        startWith: currentLifecycleState, fullCycle: true);

    final result = completer.future;

    result.whenComplete(
        () => removeLifecycleObserver(observer, fullCycle: false));

    if (this is LifecycleRegistryState) {
      /// 由于代管理者会直接销毁 需要特殊处理
      liveable.onCancel
          .then((value) => removeLifecycleObserver(observer, fullCycle: false));
    } else {
      cancellable?.onCancel
          .then((value) => removeLifecycleObserver(observer, fullCycle: false));
    }
    return result;
  }

  /// 当高于某个状态时，执行一次给定的block
  Future<T> launchWhenLifecycleStateAtLeast<T>(
      {LifecycleState targetState = LifecycleState.started,
      bool runWithDelayed = false,
      Cancellable? cancellable,
      required FutureOr<T> Function(Cancellable cancellable) block}) {
    assert(targetState > LifecycleState.initialized,
        'targetState must be greater than initialized');
    if (currentLifecycleState == LifecycleState.destroyed ||
        cancellable?.isUnavailable == true) {
      return Completer<T>().future;
    }

    if (targetState < LifecycleState.created) {
      targetState = LifecycleState.created;
    }

    final liveable = makeLiveCancellable(other: cancellable);

    Completer<T> completer = runWithDelayed ? Completer() : Completer.sync();
    late final LifecycleObserver observer;

    void runBlock(Cancellable checkable) async {
      try {
        if (runWithDelayed) {
          await Future.delayed(Duration.zero);
        }
        if (checkable.isUnavailable) {
          // removeLifecycleObserver(observer, fullCycle: false);
          return;
        }
        checkable.whenCancel.then(
            (value) => removeLifecycleObserver(observer, fullCycle: false));

        final result = block(checkable);
        if (result is Future<T>) {
          await Future.delayed(Duration.zero);
          if (checkable.isAvailable == true) {
            final r = await result;
            if (checkable.isAvailable == true && !completer.isCompleted) {
              completer.complete(r);
            }
          }
        } else {
          completer.complete(result);
        }
      } catch (error, stackTree) {
        if (error != checkable.reasonAsException && !completer.isCompleted) {
          completer.completeError(error, stackTree);
        }
      }
    }

    Cancellable? checkable;

    if (currentLifecycleState >= targetState &&
        liveable.isAvailable &&
        !runWithDelayed) {
      checkable = liveable;
      observer = LifecycleObserver.stateChange((state) {
        if (state < targetState && liveable.isAvailable == true) {
          removeLifecycleObserver(observer, fullCycle: false);
          liveable.cancel();
        }
      });
      addLifecycleObserver(observer,
          fullCycle: true, startWith: currentLifecycleState);
      runBlock(liveable);
    } else {
      observer = LifecycleObserver.stateChange((state) async {
        if (state >= targetState && liveable.isAvailable && checkable == null) {
          checkable = liveable.makeCancellable();
          runBlock(checkable!);
        } else if (state < targetState && checkable?.isAvailable == true) {
          checkable?.cancel();
          checkable = null;
        }
      });
      addLifecycleObserver(observer, fullCycle: true);
    }

    final result = completer.future;
    result.whenComplete(
        () => removeLifecycleObserver(observer, fullCycle: false));

    if (this is LifecycleRegistryState) {
      /// 由于代管理者会直接销毁 需要特殊处理
      liveable.onCancel
          .then((value) => removeLifecycleObserver(observer, fullCycle: false));
    } else {
      cancellable?.onCancel
          .then((value) => removeLifecycleObserver(observer, fullCycle: false));
    }
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
    if (cancellable?.isUnavailable == true) {
      return Completer<T>().future;
    }
    if (currentLifecycleState == LifecycleState.destroyed) {
      if (runWithDelayed) {
        return Future.delayed(Duration.zero)
            .then((value) => block(cancellable ?? Cancellable()));
      } else {
        try {
          final result = block(cancellable ?? Cancellable());
          if (result is Future<T>) {
            return result;
          }
          return SynchronousFuture(result);
        } catch (e, st) {
          return Future.error(e, st);
        }
      }
    }

    Completer<T> completer = runWithDelayed ? Completer() : Completer.sync();
    final observer = LifecycleObserver.stateChange((state) {
      if (state == LifecycleState.destroyed &&
          !completer.isCompleted &&
          cancellable?.isUnavailable != true) {
        if (runWithDelayed) {
          completer.complete(Future(() => block(cancellable ?? Cancellable())));
        } else {
          completer.complete(block(cancellable ?? Cancellable()));
        }
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
    if (cancellable?.isUnavailable == true) {
      return Completer<T>().future;
    }
    if (currentLifecycleState == LifecycleState.destroyed) {
      if (runWithDelayed) {
        return Future.delayed(Duration.zero)
            .then((value) => block(cancellable ?? Cancellable()));
      } else {
        try {
          final result = block(cancellable ?? Cancellable());
          if (result is Future<T>) {
            return result;
          }
          return SynchronousFuture(result);
        } catch (e, st) {
          return Future.error(e, st);
        }
      }
    }

    Completer<T> completer = runWithDelayed ? Completer() : Completer.sync();
    final observer = LifecycleObserver.eventDestroy(() {
      if (!completer.isCompleted && cancellable?.isUnavailable != true) {
        if (runWithDelayed) {
          completer.complete(Future(() => block(cancellable ?? Cancellable())));
        } else {
          completer.complete(block(cancellable ?? Cancellable()));
        }
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
      whenLifecycleStateAtLeast(LifecycleState.resumed,
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
