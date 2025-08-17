import 'dart:async';
import 'dart:collection';

import 'package:an_lifecycle_cancellable/tools/weak_map_clear.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:flutter/widgets.dart';
import 'package:weak_collections/weak_collections.dart';

import 'lifecycle_data.dart';
import 'lifecycle_effect.dart';

typedef LLauncher = FutureOr<void> Function(Lifecycle lifecycle);

class _LLauncherObserver with LifecycleStateChangeObserver {
  final WeakReference<BuildContext> _context;
  LLauncher? launchOnFirstCreate;
  LLauncher? launchOnFirstStart;
  LLauncher? launchOnFirstResume;
  LLauncher? launchOnDestroy;
  LLauncher? repeatOnStarted;
  LLauncher? repeatOnResumed;

  bool _firstCreate = true, _firstStart = true, _firstResume = true;

  LifecycleState _lastState = LifecycleState.destroyed;

  _LLauncherObserver._(BuildContext context)
      : _context = WeakReference(context);

  @override
  void onStateChange(LifecycleOwner owner, LifecycleState state) {
    if (state == LifecycleState.destroyed) {
      _lastState = state;
      _safeCallLauncher(launchOnDestroy, owner.lifecycle, 'launchOnDestroy');
      return;
    }

    if (_context.target == null || _context.target?.mounted != true) return;
    if (_firstCreate && state == LifecycleState.created) {
      _firstCreate = false;
      _safeCallLauncher(
          launchOnFirstCreate, owner.lifecycle, 'launchOnFirstCreate');
    } else if (_firstStart && state == LifecycleState.started) {
      _firstStart = false;
      _safeCallLauncher(
          launchOnFirstStart, owner.lifecycle, 'launchOnFirstStart');
    } else if (_firstResume && state == LifecycleState.resumed) {
      _dRunOnResume(owner);
    }
    if (_lastState < state) {
      if (state == LifecycleState.resumed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          /// 特殊情况下会resume触发在build之前故将此事件推迟
          if (owner.lifecycle.currentState >= LifecycleState.resumed &&
              _context.target?.mounted == true) {
            _safeCallLauncher(
                repeatOnResumed, owner.lifecycle, 'repeatOnResumed');
          }
        });
      } else if (state == LifecycleState.started) {
        _safeCallLauncher(repeatOnStarted, owner.lifecycle, 'repeatOnStarted');
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
        _safeCallLauncher(
            launchOnFirstResume, owner.lifecycle, 'launchOnFirstResume');
      }
    });
  }

  void _safeCallLauncher(
      LLauncher? launcher, Lifecycle lifecycle, String method) async {
    if (launcher == null) return;
    try {
      await launcher.call(lifecycle);
    } catch (exception, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'an_lifecycle_cancellable',
        context: ErrorDescription('withLifecycleEffect run $method error'),
      ));
    }
  }
}

class _DLauncherObserver<T extends Object> with LifecycleStateChangeObserver {
  final T _data;
  final WeakReference<BuildContext> _context;
  Launcher<T>? launchOnFirstCreate;
  Launcher<T>? launchOnFirstStart;
  Launcher<T>? launchOnFirstResume;
  Launcher<T>? launchOnDestroy;
  Launcher<T>? repeatOnStarted;
  Launcher<T>? repeatOnResumed;

  bool _firstCreate = true, _firstStart = true, _firstResume = true;

  LifecycleState _lastState = LifecycleState.destroyed;

  _DLauncherObserver._(BuildContext context, this._data)
      : _context = WeakReference(context);

  @override
  void onStateChange(LifecycleOwner owner, LifecycleState state) {
    if (state == LifecycleState.destroyed) {
      _lastState = state;
      _safeCallLauncher(launchOnDestroy, owner.lifecycle, 'launchOnDestroy');
      return;
    }

    if (_context.target == null || _context.target?.mounted != true) return;
    if (_firstCreate && state == LifecycleState.created) {
      _firstCreate = false;
      _safeCallLauncher(
          launchOnFirstCreate, owner.lifecycle, 'launchOnFirstCreate');
    } else if (_firstStart && state == LifecycleState.started) {
      _firstStart = false;
      _safeCallLauncher(
          launchOnFirstStart, owner.lifecycle, 'launchOnFirstStart');
    } else if (_firstResume && state == LifecycleState.resumed) {
      _dRunOnResume(owner);
    }
    if (_lastState < state) {
      if (state == LifecycleState.resumed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          /// 特殊情况下会resume触发在build之前故将此事件推迟
          if (owner.lifecycle.currentState >= LifecycleState.resumed &&
              _context.target?.mounted == true) {
            _safeCallLauncher(
                repeatOnResumed, owner.lifecycle, 'repeatOnResumed');
          }
        });
      } else if (state == LifecycleState.started) {
        _safeCallLauncher(repeatOnStarted, owner.lifecycle, 'repeatOnStarted');
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
        _safeCallLauncher(
            launchOnFirstResume, owner.lifecycle, 'launchOnFirstResume');
      }
    });
  }

  void _safeCallLauncher(
      Launcher<T>? launcher, Lifecycle lifecycle, String method) async {
    if (launcher == null) return;
    try {
      await launcher.call(lifecycle, _data);
    } catch (exception, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'an_lifecycle_cancellable',
        context:
            ErrorDescription('withLifecycleAndDataEffect run $method error'),
      ));
    }
  }
}

final _withLifecycleKey = Object();
// final _withLifecycleDataKey = Object();
final _withLifecycleAndDataKey = Object();
final _withLifecycleAndExtDataKey = Object();

// class _BuildContextLifecycleWithDataKey {
//   final Object? key;
//
//   _BuildContextLifecycleWithDataKey({this.key});
//
//   @override
//   int get hashCode => Object.hash(_BuildContextLifecycleWithDataKey, key);
//
//   @override
//   bool operator ==(Object other) {
//     return other is _BuildContextLifecycleWithDataKey && other.key == key;
//   }
// }

extension BuildContextLifecycleWithExt on BuildContext {
  /// 从当前的[Context]中获取[Lifecycle]并使用
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
      observer.launchOnDestroy = launchOnDestroy;

      if (repeatOnStarted != null) {
        observer.repeatOnStarted = repeatOnStarted;
      }
      if (repeatOnResumed != null) {
        observer.repeatOnResumed = repeatOnResumed;
      }

      lifecycle.addObserver(observer);
      lifecycle.addLifecycleObserver(
          LifecycleObserver.eventDestroy(() => cache.remove(ctx)));
      return observer;
    });

    if (repeatOnStarted != null) {
      observer.repeatOnStarted = repeatOnStarted;
    }
    if (repeatOnResumed != null) {
      observer.repeatOnResumed = repeatOnResumed;
    }

    if (launchOnDestroy != null) {
      observer.launchOnDestroy = launchOnDestroy;
    }
  }

  /// 从当前的[Context]中获取[Lifecycle]使用 并且data 同属于 key的一部分
  /// * 如果使用[factory],[factory2] 则必须保证多次调用时返回同一值 否则将会视为新建
  @Deprecated('use withLifecycleAndDataEffect')
  T withLifecycleEffectData<T extends Object>({
    T? data,
    T Function()? factory,
    T Function(Lifecycle lifecycle)? factory2,
    Launcher<T>? launchOnFirstCreate,
    Launcher<T>? launchOnFirstStart,
    Launcher<T>? launchOnFirstResume,
    Launcher<T>? repeatOnStarted,
    Launcher<T>? repeatOnResumed,
    Launcher<T>? launchOnDestroy,
    Object? key,
  }) =>
      withLifecycleAndDataEffect(
        data: data,
        factory: factory,
        factory2: factory2,
        launchOnFirstCreate: launchOnFirstCreate,
        launchOnFirstStart: launchOnFirstStart,
        launchOnFirstResume: launchOnFirstResume,
        repeatOnStarted: repeatOnStarted,
        repeatOnResumed: repeatOnResumed,
        launchOnDestroy: launchOnDestroy,
        key: key,
      );

  // {
  //   assert(data != null || factory != null || factory2 != null,
  //       'data and factory and factory2 cannot be null at the same time');
  //
  //   data ??= factory?.call();
  //
  //   final lifecycle = Lifecycle.of(this);
  //
  //   data ??= factory2?.call(lifecycle);
  //
  //   if (data == null) {
  //     throw 'data and factory and factory2 cannot be null at the same time';
  //   }
  //
  //   final ctx = this;
  //   final d = data;
  //
  //   final cache = lifecycle.extData
  //       .putIfAbsent<Map<BuildContext, Map<Object, _DLauncherObserver>>>(
  //           key: key == null
  //               ? _withLifecycleDataKey
  //               : _BuildContextLifecycleWithDataKey(key: key),
  //           ifAbsent: () => WeakHashMap());
  //
  //   final cache2 =
  //       cache.putIfAbsent(ctx, () => HashMap<Object, _DLauncherObserver>());
  //   final observer = cache2.putIfAbsent(d, () {
  //     final observer = _DLauncherObserver<T>._(ctx, d);
  //     observer.launchOnFirstCreate = launchOnFirstCreate;
  //     observer.launchOnFirstStart = launchOnFirstStart;
  //     observer.launchOnFirstResume = launchOnFirstResume;
  //     observer.launchOnDestroy = launchOnDestroy;
  //     if (repeatOnStarted != null) {
  //       observer._repeatOn[LifecycleState.started] = repeatOnStarted;
  //     }
  //     if (repeatOnResumed != null) {
  //       observer._repeatOn[LifecycleState.resumed] = repeatOnResumed;
  //     }
  //
  //     lifecycle.addObserver(observer);
  //     lifecycle.addLifecycleObserver(
  //         LifecycleObserver.eventDestroy(() => cache2.remove(d)));
  //     return observer;
  //   }) as _DLauncherObserver<T>;
  //
  //   if (repeatOnStarted != null) {
  //     observer._repeatOn[LifecycleState.started] = repeatOnStarted;
  //   }
  //   if (repeatOnResumed != null) {
  //     observer._repeatOn[LifecycleState.resumed] = repeatOnResumed;
  //   }
  //   if (launchOnDestroy != null) {
  //     observer.launchOnDestroy = launchOnDestroy;
  //   }
  //   return data;
  // }

  /// 从当前的[Context]中获取[Lifecycle]使用 并且data 同属于 key的一部分
  /// * 如果使用[factory],[factory2] 则必须保证多次调用时返回同一值 否则将会视为新建
  T withLifecycleAndDataEffect<T extends Object>({
    T? data,
    T Function()? factory,
    T Function(Lifecycle lifecycle)? factory2,
    Launcher<T>? launchOnFirstCreate,
    Launcher<T>? launchOnFirstStart,
    Launcher<T>? launchOnFirstResume,
    Launcher<T>? repeatOnStarted,
    Launcher<T>? repeatOnResumed,
    Launcher<T>? launchOnDestroy,
    Object? key,
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
            key: _withLifecycleAndDataKey, ifAbsent: () => WeakHashMap());

    final cache2 = cache.putIfAbsent(ctx, () {
      final result = HashMap<Object, _DLauncherObserver>();
      lifecycle.addLifecycleObserver(MapAutoClearObserver(result));
      return result;
    });

    final observer =
        cache2.putIfAbsent(key == null ? d : _LifecycleAndDataKey(d, key), () {
      final observer = _DLauncherObserver<T>._(ctx, d);
      observer.launchOnFirstCreate = launchOnFirstCreate;
      observer.launchOnFirstStart = launchOnFirstStart;
      observer.launchOnFirstResume = launchOnFirstResume;
      observer.launchOnDestroy = launchOnDestroy;
      if (repeatOnStarted != null) {
        observer.repeatOnStarted = repeatOnStarted;
      }
      if (repeatOnResumed != null) {
        observer.repeatOnResumed = repeatOnResumed;
      }

      lifecycle.addObserver(observer);
      return observer;
    }) as _DLauncherObserver<T>;

    if (repeatOnStarted != null) {
      observer.repeatOnStarted = repeatOnStarted;
    }
    if (repeatOnResumed != null) {
      observer.repeatOnResumed = repeatOnResumed;
    }
    if (launchOnDestroy != null) {
      observer.launchOnDestroy = launchOnDestroy;
    }
    return data;
  }

  /// 从当前[context]生成一个绑定到[liveDate]内部的缓存数据
  /// * [context] 销毁时自动清理
  /// * 与 [withLifecycleAndExtDataEffect] 数据相同
  T withLifecycleExtData<T extends Object>({
    T Function()? factory,
    T Function(Lifecycle lifecycle)? factory2,
    Object? key,
  }) {
    final lifecycle = Lifecycle.of(this);
    factory ??= () => factory2!(lifecycle);

    final Map<BuildContext, Map<Object, Object?>> contextExtData =
        lifecycle.extData.putIfAbsent(
            key: _withLifecycleAndExtDataKey, ifAbsent: WeakHashMap.new);

    final data = contextExtData.putIfAbsent(this, () {
      final result = HashMap<Object, Object?>();

      /// 不持有 Map，防止内存泄漏
      lifecycle.addLifecycleObserver(MapAutoClearObserver(result));
      return result;
    });

    return data.putIfAbsent(key == null ? T : TypedKey<T>(key), factory) as T;
  }

  /// 从当前[context]生成一个绑定到[liveDate]内部的缓存数据 并提供生命周期的相关函数
  /// * [context] 销毁时自动清理
  /// * 与 [withLifecycleExtData] 数据相同
  T withLifecycleAndExtDataEffect<T extends Object>({
    T Function()? factory,
    T Function(Lifecycle lifecycle)? factory2,
    Launcher<T>? launchOnFirstCreate,
    Launcher<T>? launchOnFirstStart,
    Launcher<T>? launchOnFirstResume,
    Launcher<T>? repeatOnStarted,
    Launcher<T>? repeatOnResumed,
    Launcher<T>? launchOnDestroy,
    Object? key,
  }) {
    final data = withLifecycleExtData(
      factory: factory,
      factory2: factory2,
      key: key,
    );
    return withLifecycleAndDataEffect(
      data: data,
      launchOnFirstCreate: launchOnFirstCreate,
      launchOnFirstStart: launchOnFirstStart,
      launchOnFirstResume: launchOnFirstResume,
      repeatOnStarted: repeatOnStarted,
      repeatOnResumed: repeatOnResumed,
      launchOnDestroy: launchOnDestroy,
    );
  }
}

class _LifecycleAndDataKey {
  final Object data;
  final Object? key;

  _LifecycleAndDataKey(this.data, this.key);

  @override
  int get hashCode => Object.hash(data, key);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _LifecycleAndDataKey &&
        other.data == data &&
        other.key == key;
  }
}
