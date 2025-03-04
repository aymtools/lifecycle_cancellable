import 'dart:async';

import 'package:an_lifecycle_cancellable/lifecycle/lifecycle_data.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:flutter/widgets.dart';
import 'package:weak_collections/weak_collections.dart';

typedef Launcher<T> = FutureOr Function(Lifecycle, T data);

class _LauncherLifecycleObserver<T> with LifecycleStateChangeObserver {
  final T _data;

  Launcher<T>? launchOnFirstCreate;
  Launcher<T>? launchOnFirstStart;
  Launcher<T>? launchOnFirstResume;
  Launcher<T>? launchOnDestroy;
  final Map<LifecycleState, Launcher<T>> _repeatOn = {};

  _LauncherLifecycleObserver(this._data);

  bool _firstCreate = true, _firstStart = true, _firstResume = true;

  LifecycleState _lastState = LifecycleState.destroyed;

  @override
  void onStateChange(LifecycleOwner owner, LifecycleState state) {
    if (state == LifecycleState.destroyed) {
      launchOnDestroy?.call(owner.lifecycle, _data);
      _lastState = state;
      return;
    }
    if (_firstCreate && state == LifecycleState.created) {
      _firstCreate = false;
      launchOnFirstCreate?.call(owner.lifecycle, _data);
    } else if (_firstStart && state == LifecycleState.started) {
      _firstStart = false;
      launchOnFirstStart?.call(owner.lifecycle, _data);
    } else if (_firstResume && state == LifecycleState.resumed) {
      _dRunOnResume(owner);
    }
    if (_lastState < state) {
      if (state == LifecycleState.resumed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          /// 特殊情况下会resume触发在build之前故将此事件推迟
          if (owner.lifecycle.currentState >= LifecycleState.resumed) {
            _repeatOn[LifecycleState.resumed]?.call(owner.lifecycle, _data);
          }
        });
      } else {
        _repeatOn[state]?.call(owner.lifecycle, _data);
      }
    }
    _lastState = state;
  }

  _dRunOnResume(LifecycleOwner owner) {
    _firstResume = false;
    final l = owner.lifecycle;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      /// 特殊情况下会resume触发在build之前故将此事件推迟
      if (l.currentState > LifecycleState.destroyed) {
        launchOnFirstResume?.call(owner.lifecycle, _data);
      }
    });
  }
}

const _withLifecycleEffectToken = Object();

extension LifecycleLauncherExt on ILifecycle {
  /// 直接使用生命周期对类对象进行操作
  T withLifecycleEffect<T extends Object>({
    T? data,
    T Function()? factory,
    T Function(Lifecycle lifecycle)? factory2,
    Launcher<T>? launchOnFirstCreate,
    Launcher<T>? launchOnFirstStart,
    Launcher<T>? launchOnFirstResume,
    Launcher<T>? repeatOnStarted,
    Launcher<T>? repeatOnResumed,
    Launcher<T>? launchOnDestroy,
  }) {
    assert(() {
      if (this is LifecycleRegistryState) {
        assert(currentLifecycleState > LifecycleState.initialized,
            'In LifecycleRegistryState, the currentLifecycleState must be greater than LifecycleState.initialized');
      } else {
        assert(currentLifecycleState > LifecycleState.destroyed,
            'The currentLifecycleState state must be greater than LifecycleState.destroyed.');
      }
      return true;
    }());

    if (currentLifecycleState <= LifecycleState.destroyed) {
      throw 'The currentLifecycleState state must be greater than LifecycleState.destroyed.';
    }
    assert(data != null || factory != null || factory2 != null,
        'data and factory cannot be null at the same time');
    if (data == null && factory == null && factory2 == null) {
      throw 'data and factory cannot be null at the same time';
    }
    T value = data ?? factory?.call() ?? factory2!.call(toLifecycle());
    if (launchOnFirstCreate == null &&
        launchOnFirstStart == null &&
        launchOnFirstResume == null &&
        repeatOnStarted == null &&
        repeatOnResumed == null &&
        launchOnDestroy == null) {
      return value;
    }

    Lifecycle life = toLifecycle();

    Map<Object, _LauncherLifecycleObserver> lifecycleEffectObservers =
        life.extData.putIfAbsent(
            key: _withLifecycleEffectToken, ifAbsent: () => WeakHashMap());

    _LauncherLifecycleObserver<T> observer =
        lifecycleEffectObservers.putIfAbsent(value as Object, () {
      final o = _LauncherLifecycleObserver<T>(value);
      o.launchOnFirstCreate = launchOnFirstCreate;
      o.launchOnFirstStart = launchOnFirstStart;
      o.launchOnFirstResume = launchOnFirstResume;
      o.launchOnDestroy = launchOnDestroy;

      if (repeatOnStarted != null) {
        o._repeatOn[LifecycleState.started] = repeatOnStarted;
      }
      if (repeatOnResumed != null) {
        o._repeatOn[LifecycleState.resumed] = repeatOnResumed;
      }

      //加入销毁的逻辑
      life.addLifecycleObserver(LifecycleObserver.eventDestroy(
          () => lifecycleEffectObservers.remove(value)));

      life.addLifecycleObserver(o);
      return o;
    }) as _LauncherLifecycleObserver<T>;

    observer.launchOnDestroy = launchOnDestroy;
    if (repeatOnStarted != null) {
      observer._repeatOn[LifecycleState.started] = repeatOnStarted;
    }
    if (repeatOnResumed != null) {
      observer._repeatOn[LifecycleState.resumed] = repeatOnResumed;
    }
    return value;
  }
}
