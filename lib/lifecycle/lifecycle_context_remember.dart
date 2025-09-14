import 'dart:async';
import 'dart:collection';

import 'package:an_lifecycle_cancellable/key/key.dart';
import 'package:an_lifecycle_cancellable/lifecycle/lifecycle_controller.dart';
import 'package:an_lifecycle_cancellable/lifecycle/lifecycle_data.dart';
import 'package:an_lifecycle_cancellable/lifecycle/lifecycle_ext.dart';
import 'package:an_lifecycle_cancellable/listenable/change_notifier_ext.dart';
import 'package:an_lifecycle_cancellable/listenable/value_notifier.dart';
import 'package:an_lifecycle_cancellable/tools/weak_map_clear.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:flutter/material.dart';
import 'package:weak_collections/weak_collections.dart';

class _RememberEntity<T> {
  final T value;
  FutureOr<void> Function(T)? onDispose;

  _RememberEntity(this.value, this.onDispose);

  void _safeInvokeOnDispose() {
    if (onDispose != null) {
      try {
        onDispose!(value);
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'an_lifecycle_cancellable',
          context: ErrorDescription('remember $T run onDispose error'),
        ));
      }
    }
  }
}

class _RememberDisposeObserver with LifecycleStateChangeObserver {
  final _values = HashMap<Object, _RememberEntity<dynamic>>();
  final Lifecycle _lifecycle;
  final WeakReference<BuildContext> _context;
  bool _isDisposed = false;
  final _detachKey = Object();

  late final Finalizer<_RememberDisposeObserver> _finalizer =
      Finalizer<_RememberDisposeObserver>(
    (observer) {
      observer._lifecycle.removeLifecycleObserver(observer, fullCycle: false);
      observer._safeCallDisposer(callDetach: false);
    },
  );

  _RememberDisposeObserver._(BuildContext context, Lifecycle lifecycle)
      : _context = WeakReference(context),
        _lifecycle = lifecycle {
    _lifecycle.addLifecycleObserver(this);
    _finalizer.attach(context, this, detach: _detachKey);
  }

  @override
  void onStateChange(LifecycleOwner owner, LifecycleState state) {
    if (state == LifecycleState.destroyed) {
      _safeCallDisposer();
    } else if (state > LifecycleState.initialized &&
        _context.target?.mounted != true) {
      owner.removeLifecycleObserver(this, fullCycle: false);
      _safeCallDisposer();
    }
  }

  void _safeCallDisposer({bool callDetach = true}) async {
    if (_isDisposed) return;
    _isDisposed = true;
    for (var disposable in [..._values.values]) {
      disposable._safeInvokeOnDispose();
    }
    _values.clear();
    if (callDetach) _finalizer.detach(_detachKey);
  }

  T getOrCreate<T extends Object>(
    T Function()? factory,
    T Function(Lifecycle)? factory2,
    FutureOr<void> Function(T)? onDispose,
    Object? key,
  ) {
    final entity = _values.putIfAbsent(
      TypedKey.genKey<T>(key: key),
      () {
        var data = factory?.call() ?? factory2?.call(_lifecycle);
        return _RememberEntity<T>(data!, onDispose);
      },
    ) as _RememberEntity<T>;
    entity.onDispose = onDispose;
    return entity.value;
  }
}

final _keyRemember = Object();

@Deprecated('use package:remember , will remove v2.6.0')
extension BuildContextLifecycleRememberExt on BuildContext {
  /// 以当前[context]、类型[T]和[key]为索引 记住该对象，并且以后将再次返回该对象
  /// * [factory] 和 [factory2] 如何构建这个对象，不能同时为空, [factory] 优先级高于 [factory2]
  /// * [onDispose] 定义销毁时如何处理，一定晚于[context]的[dispose],非常注意不可使用[context]相关内容
  @Deprecated('use package:remember , will remove v2.6.0')
  T remember<T extends Object>({
    T Function()? factory,
    T Function(Lifecycle)? factory2,
    FutureOr<void> Function(T)? onDispose,
    Object? key,
  }) {
    if (factory == null && factory2 == null) {
      throw 'factory and factory2 cannot be null at the same time';
    }

    final lifecycle = Lifecycle.of(this);
    final managers = lifecycle.extData.getOrPut<
            Map<BuildContext, _RememberDisposeObserver>>(
        key: _keyRemember,
        ifAbsent: (l) {
          final result =
              WeakHashMap<BuildContext, _RememberDisposeObserver>.identity();

          /// 不持有 Map，防止内存泄漏
          lifecycle.addLifecycleObserver(MapAutoClearObserver(result));
          return result;
        });

    final manager = managers.putIfAbsent(
        this, () => _RememberDisposeObserver._(this, lifecycle));

    return manager.getOrCreate<T>(factory, factory2, onDispose, key);
  }

  /// 获取可用的TabController
  /// * [initialIndex], [animationDuration], [length], [key]任何一个参数发生变化就会产生新的 TabController
  @Deprecated('use package:remember , will remove v2.6.0')
  TabController rememberTabController({
    int initialIndex = 0,
    Duration? animationDuration,
    required int length,
    FutureOr<void> Function(TabController)? onDispose,
    Object? key,
  }) =>
      remember<TabController>(
        factory2: (l) => TabController(
          initialIndex: initialIndex,
          length: length,
          vsync: l.tickerProvider,
        ),
        onDispose: (c) {
          c.dispose();
          onDispose?.call(c);
        },
        key: FlexibleKey(initialIndex, animationDuration, length, key),
      );

  /// 动画控制器
  /// * 任何参数发生变化就会产生新的
  @Deprecated('use package:remember , will remove v2.6.0')
  AnimationController rememberAnimationController({
    double? value,
    Duration? duration,
    Duration? reverseDuration,
    String? debugLabel,
    double lowerBound = 0.0,
    double upperBound = 1.0,
    AnimationBehavior animationBehavior = AnimationBehavior.normal,
    FutureOr<void> Function(AnimationController)? onDispose,
    Object? key,
  }) {
    return remember<AnimationController>(
      factory2: (l) => AnimationController(
        value: value,
        duration: duration,
        reverseDuration: reverseDuration,
        debugLabel: debugLabel,
        lowerBound: lowerBound,
        upperBound: upperBound,
        animationBehavior: animationBehavior,
        vsync: l.tickerProvider,
      ),
      key: FlexibleKey(value, duration, reverseDuration, lowerBound, upperBound,
          animationBehavior, key),
      onDispose: (c) {
        c.dispose();
        onDispose?.call(c);
      },
    );
  }

  /// 动画控制器
  /// * 任何参数发生变化就会产生新的
  @Deprecated('use package:remember , will remove v2.6.0')
  AnimationController rememberAnimationControllerUnbounded({
    double value = 0.0,
    Duration? duration,
    Duration? reverseDuration,
    String? debugLabel,
    AnimationBehavior animationBehavior = AnimationBehavior.normal,
    FutureOr<void> Function(AnimationController)? onDispose,
    Object? key,
  }) {
    return remember<AnimationController>(
      factory2: (l) => AnimationController.unbounded(
        value: value,
        duration: duration,
        reverseDuration: reverseDuration,
        debugLabel: debugLabel,
        animationBehavior: animationBehavior,
        vsync: l.tickerProvider,
      ),
      key: FlexibleKey('Unbounded', value, duration, reverseDuration,
          animationBehavior, key),
      onDispose: (c) {
        c.dispose();
        onDispose?.call(c);
      },
    );
  }

  /// 滚动控制器
  /// * 任何参数发生变化就会产生新的
  @Deprecated('use package:remember , will remove v2.6.0')
  ScrollController rememberScrollController({
    double initialScrollOffset = 0.0,
    bool keepScrollOffset = true,
    String? debugLabel,
    FutureOr<void> Function(ScrollController)? onDispose,
    Object? key,
  }) =>
      remember<ScrollController>(
        factory: () => ScrollController(
          initialScrollOffset: initialScrollOffset,
          keepScrollOffset: keepScrollOffset,
          debugLabel: debugLabel,
        ),
        key:
            FlexibleKey(initialScrollOffset, keepScrollOffset, debugLabel, key),
        onDispose: (c) {
          c.dispose();
          onDispose?.call(c);
        },
      );

  /// 快速生成一个可用的类型 ValueNotifier
  /// * 确定是否需要更新对象只有 type 和 key
  /// * [value]， [factory]， [factory2] 确定如何初始化的创建一个 ValueNotifier 必须有一个不能为空 不作为更新key
  /// * [listen] 当前的 Context 自动监听生成的 ValueNotifier 不作为更新key 只有首次有效 后续变化无效
  @Deprecated('use package:remember , will remove v2.6.0')
  ValueNotifier<T> rememberValueNotifier<T>({
    T? value,
    T Function()? factory,
    T Function(Lifecycle)? factory2,
    FutureOr<void> Function(ValueNotifier<T>)? onDispose,
    bool listen = false,
    Object? key,
  }) =>
      remember<ValueNotifier<T>>(
        factory2: (l) {
          assert(value != null || factory != null || factory2 != null,
              'value and factory and factory2 cannot be null at the same time');
          value ??= factory?.call();
          value ??= factory2?.call(l);
          final r =
              CancellableValueNotifier(value as T, l.makeLiveCancellable());
          if (listen && this is Element) {
            final rContext = WeakReference(this);
            r.addCListener(l.makeLiveCancellable(), () {
              final element = rContext.target as Element?;
              if (element != null) {
                element.markNeedsBuild();
              }
            });
          }
          return r;
        },
        onDispose: (d) {
          d.dispose();
          onDispose?.call(d);
        },
        key: FlexibleKey(value, factory, factory2, key),
      );
}
