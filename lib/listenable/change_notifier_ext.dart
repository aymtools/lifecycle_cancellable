import 'dart:async';

import 'package:anlifecycle/lifecycle.dart';
import 'package:cancellable/cancellable.dart';
import 'package:flutter/widgets.dart';

typedef VoidCallBack = void Function();

Expando<SingleListenerManager> _singleListener = Expando('_singleListener');

class SingleListenerManager {
  final functions = <VoidCallBack>{};
  final WeakReference<Listenable> _reference;

  void _callback() => functions.toSet().forEach((element) => element.call());

  SingleListenerManager._(Listenable listenable)
      : _reference = WeakReference(listenable) {
    listenable.addListener(_callback);
  }

  void addListener(Cancellable cancellable, VoidCallback listener) {
    if (cancellable.isUnavailable) return;
    functions.add(listener);
    cancellable.onCancel.then((_) {
      functions.remove(listener);
      _check();
    });
  }

  void removeListener(VoidCallback listener) {
    functions.remove(listener);
  }

  void _check() {
    if (functions.isEmpty) {
      final able = _reference.target;
      if (able != null) {
        able.removeListener(_callback);
        _singleListener.remove(able);
      }
    }
  }

  factory SingleListenerManager._of(Listenable listenable) {
    return _singleListener.getOrPut(listenable,
        defaultValue: () => SingleListenerManager._(listenable));
  }
}

Expando<VoidCallBack> _listenerConvert = Expando('_listenerConvert');

Expando<Stream> _valueNotifierStream = Expando('_valueNotifierStream');

@visibleForTesting
class CancellableListenableCallback<T extends Listenable> {
  final WeakReference<T> reference;
  final void Function(T) callback;
  final Cancellable cancellable;

  CancellableListenableCallback(
      {required T source, required this.callback, required this.cancellable})
      : reference = WeakReference(source) {
    cancellable.whenCancel.then((_) {
      reference.target?.removeListener(sourceCallback);
    });
  }

  void sourceCallback() {
    final source = reference.target;
    if (cancellable.isAvailable) {
      if (source != null) {
        callback(source);
      }
    }
  }
}

extension ListenableCancellable on Listenable {
  /// 添加 [listener], 并且当 [cancellable]执行[cancel]时自动移除[listener]
  void addCListener(Cancellable cancellable, VoidCallback listener) {
    if (cancellable.isUnavailable) return;

    final lm = CancellableListenableCallback(
        source: this, callback: (_) => listener(), cancellable: cancellable);
    addListener(lm.sourceCallback);
  }

  /// 添加 一个唯一性的 [listener], 并且当 [cancellable]执行[cancel]时自动移除[listener],
  /// 多次添加也只会执行一次[listener],
  /// 默认的 [addCListener] 如果添加多次，会多次调用 [listener]
  void addCSingleListener(Cancellable cancellable, VoidCallback listener) {
    if (cancellable.isUnavailable) return;

    final sl = SingleListenerManager._of(this);
    sl.addListener(cancellable, listener);
  }
}

extension ChangeNotifierCancellable on ChangeNotifier {
  @Deprecated('use bindCancellable')
  void disposeByCancellable(Cancellable cancellable) =>
      bindCancellable(cancellable);
}

extension ChangeNotifierCancellableV2<T extends ChangeNotifier> on T {
  /// 与Cancellable关联 当Cancellable cancel时调用dispose
  T bindCancellable(Cancellable cancellable) {
    cancellable.onCancel.then((_) => dispose());
    return this;
  }

  /// 与lifecycle关联 当lifecycle destroy时调用dispose
  T bindLifecycle(ILifecycle lifecycle) {
    lifecycle.addLifecycleObserver(LifecycleObserver.eventDestroy(() {
      try {
        dispose();
      } catch (_) {}
    }));
    return this;
  }
}

extension ValueNotifierCancellable<T> on ValueNotifier<T> {
  /// 添加一个 含当前值 [listener], 当 [cancellable]执行[cancel]时自动移除[listener]，
  void addCVListener(Cancellable cancellable, void Function(T value) listener) {
    if (cancellable.isUnavailable) return;

    late final CancellableListenableCallback<ValueNotifier<T>> lm;
    lm = CancellableListenableCallback(
        source: this,
        callback: (l) => listener(l.value),
        cancellable: cancellable);
    addListener(lm.sourceCallback);
  }

  /// 添加一个 唯一性的 含当前值[listener], 当 [cancellable]执行[cancel]时自动移除[listener]，
  /// 多次添加也只会执行一次[listener],
  void addCSingleVListener(
      Cancellable cancellable, void Function(T value) listener) {
    if (cancellable.isUnavailable) return;

    final sl = SingleListenerManager._of(this);

    final l = _listenerConvert.getOrPut(listener,
        defaultValue: () => () {
              if (cancellable.isAvailable) listener(value);
            });

    sl.addListener(cancellable, l);
  }

  /// 将ValueNotifier转换为一个Stream，
  /// listen时会立即发送当前的值
  Stream<T> asStream() {
    Stream<T>? result = _valueNotifierStream[this] as Stream<T>?;
    if (result == null) {
      var listeners = <MultiStreamController<T>>{};

      void onValueChange() {
        final ls = [...listeners];
        for (var l in ls) {
          l.add(value);
        }
      }

      result = Stream.multi((controller) {
        if (listeners.isEmpty) addListener(onValueChange);
        listeners.add(controller);
        controller.add(value);
        controller.onCancel = () {
          listeners.remove(controller);
          if (listeners.isEmpty) {
            _valueNotifierStream[this] = null;
            removeListener(onValueChange);
          }
        };
      }, isBroadcast: true);

      _valueNotifierStream[this] = result;
    }

    return result;
  }

  @Deprecated('use [firstWhereValue] , will remove v2.6.0')
  Future<T> whenValue(bool Function(T value) test,
          {Cancellable? cancellable}) =>
      firstValue(test, cancellable: cancellable);

  @Deprecated('use [firstWhereValue] , will remove v2.6.0')
  Future<T> firstValue(bool Function(T value) test,
          {Cancellable? cancellable}) =>
      firstWhereValue(test, cancellable: cancellable);

  /// 当value首次满足条件时触发， cancellable 取消时取消监听
  Future<T> firstWhereValue(bool Function(T value) test,
      {Cancellable? cancellable}) {
    final v = value;
    if (test(v)) {
      return Future.sync(() => v);
    }

    Completer<T> completer = Completer.sync();
    if (cancellable == null || cancellable.isAvailable) {
      Cancellable c = cancellable ?? Cancellable();

      void onValueChange() {
        final v = value;
        if (test(v)) {
          completer.complete(v);
          c.cancel();
        }
      }

      addListener(onValueChange);
      c.onCancel.then((_) => removeListener(onValueChange));
    }
    return completer.future;
  }
}

extension _ExpandoGetOrPut<T extends Object> on Expando<T> {
  T getOrPut(Object key, {required T Function() defaultValue}) {
    T? r = this[key];
    if (r == null) {
      r = defaultValue();
      this[key] = r;
    }
    return r;
  }

  void remove(Object key) => this[key] = null;
}
