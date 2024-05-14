import 'dart:async';

import 'package:anlifecycle/anlifecycle.dart';
import 'package:cancellable/cancellable.dart';
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
  Future<LifecycleState> whenMoreThanState(LifecycleState state) =>
      currentLifecycleState >= LifecycleState.started
          ? Future.value(currentLifecycleState)
          : nextLifecycleState(LifecycleState.started);

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

  Cancellable _makeCancellableForLive({Cancellable? other}) =>
      _cancellable.makeCancellable(infectious: false, father: other);

  _CacheMapObserver(this.registryMixin) : _cancellable = Cancellable() {
    registryMixin.addLifecycleObserver(this, fullCycle: true);
    _cancellable.onCancel.then((value) => _map.remove(this));
  }

  @override
  void onDestroy(LifecycleOwner owner) {
    super.onDestroy(owner);
    _cancellable.cancel();
  }
}

extension LifecycleObserverRegistryCacnellable on LifecycleObserverRegistry {
  Cancellable makeLiveCancellable({Cancellable? other}) {
    assert(
        currentLifecycleState > LifecycleState.destroyed, '必须在destroyed之前使用');
    return _map
        .putIfAbsent(this, () => _CacheMapObserver(this))
        ._makeCancellableForLive(other: other);
  }

  void repeatOnLifecycle<T>(
      {LifecycleState targetState = LifecycleState.started,
      bool runWithDelayed = false,
      required FutureOr<T> Function(Cancellable cancellable) block}) {
    Cancellable? cancellable;
    final observer = LifecycleObserver.stateChange((state) async {
      if (state >= targetState &&
          (cancellable == null || cancellable?.isUnavailable == true)) {
        cancellable = makeLiveCancellable();
        try {
          if (runWithDelayed) {
            //转到下一个事件循环，可以过滤掉连续的状态变化
            await Future.delayed(Duration.zero);
            if (cancellable!.isUnavailable) return;
          }
          final result = block(cancellable!);
          if (result is Future<T>) {
            await Future.delayed(Duration.zero);
            if (cancellable?.isAvailable == true) await result;
          }
        } catch (_) {}
      } else if (state < targetState && cancellable?.isAvailable == true) {
        cancellable?.cancel();
        cancellable = null;
      }
    });
    addLifecycleObserver(observer, fullCycle: true);
  }

  Stream<T> collectOnLifecycle<T>(
      {LifecycleState targetState = LifecycleState.started,
      bool runWithDelayed = false,
      required FutureOr<T> Function(Cancellable cancellable) block}) {
    StreamController<T> controller = StreamController();
    controller.bindCancellable(makeLiveCancellable());

    Cancellable? cancellable;
    final observer = LifecycleObserver.stateChange((state) async {
      if (state >= targetState &&
          (cancellable == null || cancellable?.isUnavailable == true)) {
        cancellable = makeLiveCancellable();
        try {
          if (runWithDelayed) {
            //转到下一个事件循环，可以过滤掉连续的状态变化
            await Future.delayed(Duration.zero);
            if (cancellable!.isUnavailable) return;
          }
          final result = block(cancellable!);
          if (result is Future<T>) {
            await Future.delayed(Duration.zero);
            if (cancellable?.isAvailable == true) {
              final r = await result;
              if (cancellable?.isAvailable == true) controller.add(r);
            }
          } else {
            controller.add(result);
          }
        } catch (_) {}
      } else if (state < targetState && cancellable?.isAvailable == true) {
        cancellable?.cancel();
        cancellable = null;
      }
    });

    addLifecycleObserver(observer, fullCycle: true);

    return controller.stream;
  }
}

extension StreamLifecycleExt<T> on Stream<T> {
  Stream<T> bindLifecycle(LifecycleObserverRegistry registry,
      {LifecycleState state = LifecycleState.started,
      bool repeatLastOnRestart = false}) {
    StreamTransformer<T, T> transformer;
    if (repeatLastOnRestart) {
      T? cache;
      EventSink<T>? eventSink;
      transformer =
          StreamTransformer<T, T>.fromHandlers(handleData: (data, sink) {
        if (registry.currentLifecycleState >= state) {
          cache = null;
          eventSink = null;
          sink.add(data);
        } else {
          cache = data;
          eventSink = sink;
        }
      });
      registry.repeatOnLifecycle(
          targetState: state,
          block: (Cancellable cancellable) {
            if (cache != null && eventSink != null) {
              eventSink?.add(cache as T);
              eventSink = null;
              cache = null;
            }
          });
    } else {
      transformer =
          StreamTransformer<T, T>.fromHandlers(handleData: (data, sink) {
        if (registry.currentLifecycleState >= state) {
          sink.add(data);
        }
      });
    }

    return bindCancellable(registry.makeLiveCancellable(),
            closeWhenCancel: false)
        .transform(transformer);
  }
}
