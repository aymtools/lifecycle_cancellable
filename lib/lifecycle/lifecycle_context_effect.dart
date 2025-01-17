import 'dart:collection';

import 'package:anlifecycle/anlifecycle.dart';
import 'package:flutter/widgets.dart';
import 'package:weak_collections/weak_collections.dart';

import 'lifecycle_data.dart';

typedef LLauncher = void Function(Lifecycle lifecycle);
typedef DLauncher<T> = void Function(Lifecycle lifecycle, T data);

class _LLauncherObserver with LifecycleStateChangeObserver {
  final WeakReference<BuildContext> _context;
  LLauncher? launchOnFirstCreate;
  LLauncher? launchOnFirstStart;
  LLauncher? launchOnFirstResume;
  LLauncher? repeatOnStarted;
  LLauncher? repeatOnResumed;
  LLauncher? launchOnDestroy;
  final Map<LifecycleState, LLauncher> _repeatOn = {};

  bool _firstCreate = true, _firstStart = true, _firstResume = true;

  LifecycleState _lastState = LifecycleState.destroyed;

  _LLauncherObserver._(BuildContext context)
      : _context = WeakReference(context) {}

  @override
  void onStateChange(LifecycleOwner owner, LifecycleState state) {
    if (state == LifecycleState.destroyed && launchOnDestroy != null) {
      launchOnDestroy!(owner.lifecycle);
    }

    if (_context.target == null || _context.target?.mounted != true) return;
    if (_firstCreate &&
        state == LifecycleState.created &&
        launchOnFirstCreate != null) {
      _firstCreate = false;
      launchOnFirstCreate!(owner.lifecycle);
    } else if (_firstStart &&
        state == LifecycleState.started &&
        launchOnFirstStart != null) {
      _firstStart = false;
      launchOnFirstStart!(owner.lifecycle);
    } else if (_firstResume &&
        state == LifecycleState.resumed &&
        launchOnFirstResume != null) {
      _dRunOnResume(owner);
    }
    if (_lastState < state) {
      if (state == LifecycleState.resumed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          /// 特殊情况下会resume触发在build之前故将此事件推迟
          if (owner.lifecycle.currentState >= LifecycleState.resumed &&
              _context.target?.mounted == true) {
            _repeatOn[LifecycleState.resumed]?.call(owner.lifecycle);
          }
        });
      } else {
        _repeatOn[state]?.call(owner.lifecycle);
      }
    }
    _lastState = state;
  }

  _dRunOnResume(LifecycleOwner owner) {
    _firstResume = false;
    final l = owner.lifecycle;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      /// 特殊情况下会resume触发在build之前故将此事件推迟
      if (l.currentState > LifecycleState.destroyed &&
          _context.target?.mounted == true) {
        launchOnFirstResume!(owner.lifecycle);
      }
    });
  }
}

class _DLauncherObserver<T extends Object> with LifecycleStateChangeObserver {
  final T _data;
  final WeakReference<BuildContext> _context;
  DLauncher<T>? launchOnFirstCreate;
  DLauncher<T>? launchOnFirstStart;
  DLauncher<T>? launchOnFirstResume;
  DLauncher<T>? repeatOnStarted;
  DLauncher<T>? repeatOnResumed;
  DLauncher<T>? launchOnDestroy;
  final Map<LifecycleState, DLauncher<T>> _repeatOn = {};

  bool _firstCreate = true, _firstStart = true, _firstResume = true;

  LifecycleState _lastState = LifecycleState.destroyed;

  _DLauncherObserver._(BuildContext context, this._data)
      : _context = WeakReference(context) {}

  @override
  void onStateChange(LifecycleOwner owner, LifecycleState state) {
    if (state == LifecycleState.destroyed && launchOnDestroy != null) {
      launchOnDestroy!(owner.lifecycle, _data);
    }

    if (_context.target == null || _context.target?.mounted != true) return;
    if (_firstCreate &&
        state == LifecycleState.created &&
        launchOnFirstCreate != null) {
      _firstCreate = false;
      launchOnFirstCreate!(owner.lifecycle, _data);
    } else if (_firstStart &&
        state == LifecycleState.started &&
        launchOnFirstStart != null) {
      _firstStart = false;
      launchOnFirstStart!(owner.lifecycle, _data);
    } else if (_firstResume &&
        state == LifecycleState.resumed &&
        launchOnFirstResume != null) {
      _dRunOnResume(owner);
    }
    if (_lastState < state) {
      if (state == LifecycleState.resumed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          /// 特殊情况下会resume触发在build之前故将此事件推迟
          if (owner.lifecycle.currentState >= LifecycleState.resumed &&
              _context.target?.mounted == true) {
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
      if (l.currentState > LifecycleState.destroyed &&
          _context.target?.mounted == true) {
        launchOnFirstResume!(owner.lifecycle, _data);
      }
    });
  }
}

final _withLifecycleKey = Object();
final _withLifecycleDataKey = Object();

extension BuildContextLifecycleWithExt on BuildContext {
  /// 从当前的Context中获取Lifecycle并使用
  void withLifecycleEffect({
    LLauncher? launchOnFirstCreate,
    LLauncher? launchOnFirstStart,
    LLauncher? launchOnFirstResume,
    LLauncher? repeatOnStarted,
    LLauncher? repeatOnResumed,
    LLauncher? launchOnDestroy,
  }) {
    final lifecycle = Lifecycle.of(this);

    final ctx = this;

    final cache = lifecycle.extData
        .putIfAbsent<Map<BuildContext, _LLauncherObserver>>(
            key: _withLifecycleKey, ifAbsent: () => WeakHashMap());
    final observer = cache.putIfAbsent(ctx, () {
      final observer = _LLauncherObserver._(ctx);
      observer.launchOnFirstCreate = launchOnFirstCreate;
      observer.launchOnFirstStart = launchOnFirstStart;
      observer.launchOnFirstResume = launchOnFirstResume;
      observer.repeatOnStarted = repeatOnStarted;
      observer.repeatOnResumed = repeatOnResumed;
      observer.launchOnDestroy = launchOnDestroy;

      lifecycle.addObserver(observer);
      lifecycle.addLifecycleObserver(
          LifecycleObserver.eventDestroy(() => cache.remove(ctx)));
      return observer;
    });

    observer.repeatOnStarted = repeatOnStarted;
    observer.repeatOnResumed = repeatOnResumed;
    observer.launchOnDestroy = launchOnDestroy;
  }

  /// 从当前的Context中获取Lifecycle使用 并且data 为key
  /// 如果使用factory 则必须保证多次调用时返回同一值 否则将会视为新建
  T withLifecycleEffectData<T extends Object>({
    T? data,
    T Function()? factory,
    T Function(Lifecycle lifecycle)? factory2,
    DLauncher<T>? launchOnFirstCreate,
    DLauncher<T>? launchOnFirstStart,
    DLauncher<T>? launchOnFirstResume,
    DLauncher<T>? repeatOnStarted,
    DLauncher<T>? repeatOnResumed,
    DLauncher<T>? launchOnDestroy,
  }) {
    assert(data != null || factory != null || factory2 != null,
        'data and factory and factory2 cannot be null at the same time');

    data ??= factory?.call();

    final lifecycle = Lifecycle.of(this);

    data ??= factory2?.call(lifecycle);

    if (data == null) {
      throw 'data and factory and factory2 cannot be null at the same time';
    }

    final ctx = this;
    final d = data;

    final cache = lifecycle.extData
        .putIfAbsent<Map<BuildContext, Map<Object, _DLauncherObserver>>>(
            key: _withLifecycleDataKey, ifAbsent: () => WeakHashMap());

    final cache2 =
        cache.putIfAbsent(ctx, () => HashMap<Object, _DLauncherObserver>());
    final observer = cache2.putIfAbsent(d, () {
      final observer = _DLauncherObserver<T>._(ctx, d);
      observer.launchOnFirstCreate = launchOnFirstCreate;
      observer.launchOnFirstStart = launchOnFirstStart;
      observer.launchOnFirstResume = launchOnFirstResume;
      observer.repeatOnStarted = repeatOnStarted;
      observer.repeatOnResumed = repeatOnResumed;
      observer.launchOnDestroy = launchOnDestroy;

      lifecycle.addObserver(observer);
      lifecycle.addLifecycleObserver(
          LifecycleObserver.eventDestroy(() => cache2.remove(d)));
      return observer;
    }) as _DLauncherObserver<T>;

    observer.repeatOnStarted = repeatOnStarted;
    observer.repeatOnResumed = repeatOnResumed;
    observer.launchOnDestroy = launchOnDestroy;

    return data;
  }
}
