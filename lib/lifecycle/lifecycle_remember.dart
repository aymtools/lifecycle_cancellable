import 'dart:async';
import 'dart:collection';

import 'package:an_lifecycle_cancellable/an_lifecycle_cancellable.dart';
import 'package:an_lifecycle_cancellable/key/key.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:flutter/widgets.dart';
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
  final WeakReference<BuildContext> _context;
  final _values = HashMap<Object, _RememberEntity<dynamic>>();
  final Lifecycle _lifecycle;
  LifecycleState _lastState = LifecycleState.initialized;

  _RememberDisposeObserver._(BuildContext context, Lifecycle lifecycle)
      : _context = WeakReference(context),
        _lifecycle = lifecycle {
    _lifecycle.addLifecycleObserver(this);
  }

  @override
  void onStateChange(LifecycleOwner owner, LifecycleState state) {
    if (state == LifecycleState.destroyed) {
      _lastState = state;
      _safeCallDisposer(owner.lifecycle);
      return;
    }

    if (_lastState > LifecycleState.destroyed &&
        (_context.target == null || _context.target?.mounted != true)) {
      _lastState = LifecycleState.destroyed;
      owner.removeLifecycleObserver(this, fullCycle: true);
      return;
    }
    _lastState = state;
  }

  void _safeCallDisposer(Lifecycle lifecycle) async {
    for (var disposable in [..._values.values]) {
      disposable._safeInvokeOnDispose();
    }
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

extension BuildContextLifecycleRememberExt on BuildContext {
  /// 以当前[context]、[T]类型和[key]为索引 记住该对象，并且以后将再次返回该对象
  ///  [factory] 和 [factory2] 不能同时为空 [factory] 优先级高于 [factory2]
  ///  [onDispose] 当执行清理时的回调[context]一定已经销毁了，不可使用[context]相关内容
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
    final managers = lifecycle.extData.getOrPut(
        key: _keyRemember,
        ifAbsent: (l) => WeakHashMap<BuildContext, _RememberDisposeObserver>());
    final manager = managers.putIfAbsent(
        this, () => _RememberDisposeObserver._(this, lifecycle));

    return manager.getOrCreate<T>(factory, factory2, onDispose, key);
  }
}
