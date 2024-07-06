import 'dart:async';

import 'package:an_lifecycle_cancellable/lifecycle/lifecycle_data.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:weak_collections/weak_collections.dart' as weak;

typedef Launcher<T> = FutureOr Function(T data);

class _LauncherLifecycleObserver<T>
    with LifecycleStateChangeObserver, LifecycleEventObserver {
  final T _data;
  final void Function() callDestroyData;

  Launcher<T>? launchOnFirstCreate;
  Launcher<T>? launchOnFirstStart;
  Launcher<T>? launchOnFirstResume;
  Map<LifecycleState, Launcher<T>> _repeatOn = {};

  _LauncherLifecycleObserver(this._data, this.callDestroyData);

  bool _firstCreate = true, _firstStart = true, _firstResume = true;

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
      _firstCreate = false;
      launchOnFirstStart!(_data);
    }
  }

  @override
  void onResume(LifecycleOwner owner) {
    super.onResume(owner);
    if (_firstResume && launchOnFirstStart != null) {
      _firstResume = false;
      launchOnFirstStart!(_data);
    }
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
      _firstResume = false;
      launchOnFirstResume!(_data);
    }
    _repeatOn[state]?.call(_data);
    if (state == LifecycleState.destroyed) {
      callDestroyData();
    }
  }
}

extension LifecycleLauncherExt on LifecycleObserverRegistry {
  /// 直接使用生命周期对类对象进行操作
  T withLifecycleEffect<T extends Object>({
    T? data,
    T Function()? factory,
    Launcher<T>? launchOnFirstCreate,
    Launcher<T>? launchOnFirstStart,
    Launcher<T>? launchOnFirstResume,
    Launcher<T>? repeatOnStarted,
    Launcher<T>? repeatOnResumed,
  }) {
    assert(currentLifecycleState > LifecycleState.destroyed,
        'Must be used before destroyed.');
    if (currentLifecycleState > LifecycleState.destroyed) {
      throw 'Must be used before destroyed.';
    }
    assert(data == null && factory == null,
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
        repeatOnResumed == null) {
      return value;
    }

    Map<Object, _LauncherLifecycleObserver> _lifecycleEffectObservers =
        lifecycleExtData.putIfAbsent(
            TypedKey<Map<Object, _LauncherLifecycleObserver>>(
                'LifecycleEffect'),
            () => weak.WeakMap());

    _LauncherLifecycleObserver<T> observer =
        _lifecycleEffectObservers.putIfAbsent(value as Object, () {
      final o = _LauncherLifecycleObserver<T>(
          value, () => _lifecycleEffectObservers.remove(value));
      o.launchOnFirstCreate = launchOnFirstCreate;
      o.launchOnFirstStart = launchOnFirstStart;
      o.launchOnFirstResume = launchOnFirstResume;

      if (repeatOnStarted != null)
        o._repeatOn[LifecycleState.started] = repeatOnStarted;
      if (repeatOnResumed != null)
        o._repeatOn[LifecycleState.resumed] = repeatOnResumed;

      addLifecycleObserver(o);
      return o;
    }) as _LauncherLifecycleObserver<T>;

    if (repeatOnStarted != null)
      observer._repeatOn[LifecycleState.started] = repeatOnStarted;
    if (repeatOnResumed != null)
      observer._repeatOn[LifecycleState.resumed] = repeatOnResumed;
    return value;
  }
}
