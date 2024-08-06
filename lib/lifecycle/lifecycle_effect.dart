import 'dart:async';

import 'package:an_lifecycle_cancellable/lifecycle/lifecycle_data.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:flutter/widgets.dart';
import 'package:weak_collections/weak_collections.dart' as weak;

typedef Launcher<T> = FutureOr Function(T data);

class _LauncherLifecycleObserver<T>
    with LifecycleStateChangeObserver, LifecycleEventObserver {
  final T _data;
  LifecycleRegistryState? _registry;

  Launcher<T>? launchOnFirstCreate;
  Launcher<T>? launchOnFirstStart;
  Launcher<T>? launchOnFirstResume;
  Launcher<T>? launchOnDestroy;
  Map<LifecycleState, Launcher<T>> _repeatOn = {};

  _LauncherLifecycleObserver(this._data, this._registry);

  bool _firstCreate = true, _firstStart = true, _firstResume = true;

  LifecycleState _lastState = LifecycleState.destroyed;

  @override
  void onCreate(LifecycleOwner owner) {
    super.onCreate(owner);
    if (_firstCreate && launchOnFirstCreate != null) {
      _firstCreate = false;
      launchOnFirstCreate!(_data);
    }
  }

  @override
  void onStart(LifecycleOwner owner) {
    super.onStart(owner);
    if (_firstStart && launchOnFirstStart != null) {
      _firstStart = false;
      launchOnFirstStart!(_data);
    }
  }

  @override
  void onResume(LifecycleOwner owner) {
    super.onResume(owner);
    if (_firstResume && launchOnFirstResume != null) {
      _dRunOnResume(owner);
    }
  }

  @override
  void onDestroy(LifecycleOwner owner) {
    super.onDestroy(owner);
    launchOnDestroy?.call(_data);
  }

  @override
  void onStateChange(LifecycleOwner owner, LifecycleState state) {
    if (_firstCreate &&
        state == LifecycleState.created &&
        launchOnFirstCreate != null) {
      _firstCreate = false;
      launchOnFirstCreate!(_data);
    } else if (_firstStart &&
        state == LifecycleState.started &&
        launchOnFirstStart != null) {
      _firstStart = false;
      launchOnFirstStart!(_data);
    } else if (_firstResume &&
        state == LifecycleState.resumed &&
        launchOnFirstResume != null) {
      _dRunOnResume(owner);
    }
    if (_lastState < state) {
      if (state == LifecycleState.resumed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          /// 特殊情况下会resume触发在build之前故将此事件推迟
          if (owner.lifecycle.currentState >= LifecycleState.resumed) {
            _repeatOn[LifecycleState.resumed]?.call(_data);
          }
        });
      } else {
        _repeatOn[state]?.call(_data);
      }
    }
    _lastState = state;
    if (_registry != null &&
        _registry!.currentLifecycleState > LifecycleState.initialized &&
        owner.lifecycle.currentState == state) {
      //执行转移将当前的observer转移到lifecycle上 使销毁的时机绑定在lifecycle上
      _registry?.removeLifecycleObserver(this, fullCycle: false);
      _registry = null;
      owner.lifecycle.addLifecycleObserver(this, startWith: state);
    }
  }

  _dRunOnResume(LifecycleOwner owner) {
    _firstResume = false;
    final l = owner.lifecycle;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      /// 特殊情况下会resume触发在build之前故将此事件推迟
      if (l.currentState > LifecycleState.destroyed) {
        launchOnFirstResume!(_data);
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
    Launcher<T>? launchOnFirstCreate,
    Launcher<T>? launchOnFirstStart,
    Launcher<T>? launchOnFirstResume,
    Launcher<T>? repeatOnStarted,
    Launcher<T>? repeatOnResumed,
    Launcher<T>? launchOnDestroy,
  }) {
    assert(currentLifecycleState > LifecycleState.destroyed,
        'Must be used before destroyed.');
    if (currentLifecycleState <= LifecycleState.destroyed) {
      throw 'Must be used before destroyed.';
    }
    assert(data != null || factory != null,
        'data and factory cannot be null at the same time');
    if (data == null && factory == null) {
      throw 'data and factory cannot be null at the same time';
    }
    T value = data ?? factory!.call();
    assert(
        value != null, 'Unable to register LifecycleEffect with null as key');
    if (launchOnFirstCreate == null &&
        launchOnFirstStart == null &&
        launchOnFirstResume == null &&
        repeatOnStarted == null &&
        repeatOnResumed == null &&
        launchOnDestroy == null) {
      return value;
    }

    Lifecycle life;
    if (this is Lifecycle) {
      life = this as Lifecycle;
    } else if (this is ILifecycleRegistry) {
      life = (this as LifecycleOwner).lifecycle;
    } else {
      // 不应该进入此分支
      throw '';
    }

    Map<Object, _LauncherLifecycleObserver> _lifecycleEffectObservers =
        life.lifecycleExtData.putIfAbsent(
            TypedKey<Map<Object, _LauncherLifecycleObserver>>(
                _withLifecycleEffectToken),
            () => weak.WeakMap());

    _LauncherLifecycleObserver<T> observer =
        _lifecycleEffectObservers.putIfAbsent(value as Object, () {
      final o = _LauncherLifecycleObserver<T>(
          value,
          this is LifecycleRegistryState
              ? this as LifecycleRegistryState
              : null);
      o.launchOnFirstCreate = launchOnFirstCreate;
      o.launchOnFirstStart = launchOnFirstStart;
      o.launchOnFirstResume = launchOnFirstResume;
      o.launchOnDestroy = launchOnDestroy;

      if (repeatOnStarted != null)
        o._repeatOn[LifecycleState.started] = repeatOnStarted;
      if (repeatOnResumed != null)
        o._repeatOn[LifecycleState.resumed] = repeatOnResumed;

      //加入销毁的逻辑
      life.addLifecycleObserver(LifecycleObserver.eventDestroy(
          () => _lifecycleEffectObservers.remove(value)));

      life.addLifecycleObserver(o);
      return o;
    }) as _LauncherLifecycleObserver<T>;

    observer.launchOnDestroy = launchOnDestroy;
    if (repeatOnStarted != null)
      observer._repeatOn[LifecycleState.started] = repeatOnStarted;
    if (repeatOnResumed != null)
      observer._repeatOn[LifecycleState.resumed] = repeatOnResumed;
    return value;
  }
}
