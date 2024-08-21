import 'dart:async';

import 'package:anlifecycle/lifecycle.dart';
import 'package:cancellable/cancellable.dart';
import 'package:flutter/widgets.dart';

typedef VoidCallBack = void Function();

Expando<SingleListenerManager> _singleListener = Expando('_singleListener');

class SingleListenerManager {
  final functions = <VoidCallBack>{};
  final WeakReference<Listenable> _reference;

  void callback() => functions.toSet().forEach((element) => element.call());

  SingleListenerManager._(Listenable listenable)
      : _reference = WeakReference(listenable) {
    listenable.addListener(callback);
  }

  void addListener(Cancellable cancellable, VoidCallback listener) {
    if (cancellable.isUnavailable) return;
    functions.add(listener);
    cancellable.onCancel.then(_check);
  }

  void removeListener(VoidCallback listener) {
    functions.remove(listener);
  }

  void _check(_) {
    if (functions.isEmpty) {
      final able = _reference.target;
      if (able != null) {
        able.removeListener(callback);
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

extension ListenableCancellable on Listenable {
  void addCListener(Cancellable cancellable, VoidCallback listener) {
    if (cancellable.isUnavailable) return;

    notifierCallback() {
      if (cancellable.isAvailable) listener();
    }

    addListener(notifierCallback);
    cancellable.whenCancel.then((value) => removeListener(notifierCallback));
  }

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
    lifecycle.addLifecycleObserver(LifecycleObserver.eventDestroy(dispose));
    return this;
  }
}

extension ValueNotifierCancellable<T> on ValueNotifier<T> {
  void addCVListener(Cancellable cancellable, void Function(T value) listener) {
    if (cancellable.isUnavailable) return;

    notifierCallback() {
      if (cancellable.isAvailable) listener(value);
    }

    addListener(notifierCallback);
    cancellable.whenCancel.then((value) => removeListener(notifierCallback));
  }

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

  Stream<T> asStream({Cancellable? cancellable}) {
    Stream<T>? result = _valueNotifierStream[this] as Stream<T>?;
    if (result == null) {
      var listeners = <MultiStreamController<T>>{};
      result = Stream.multi((controller) {
        if (cancellable?.isUnavailable == true) {
          controller.close();
          return;
        }
        listeners.add(controller);
        controller.add(value);
        controller.onCancel = () {
          listeners.remove(controller);
        };
      }, isBroadcast: true);
      if (cancellable != null) {
        cancellable.onCancel.then((value) {
          for (var l in listeners) {
            l.closeSync();
          }
        });
        addCVListener(cancellable, (value) {
          for (var l in listeners) {
            l.add(value);
          }
        });
      } else {
        addListener(() {
          for (var l in listeners) {
            l.add(value);
          }
        });
      }
      _valueNotifierStream[this] = result;
    }

    return result;
  }

  @Deprecated('use [firstValue]')
  Future<T> whenValue(bool Function(T value) test,
          {Cancellable? cancellable}) =>
      firstValue(test, cancellable: cancellable);

  Future<T> firstValue(bool Function(T value) test,
      {Cancellable? cancellable}) {
    final v = value;
    if (test(v)) {
      return Future.value(v);
    }

    Completer<T> completer = Completer();
    if (cancellable == null || cancellable.isAvailable) {
      Cancellable c =
          cancellable?.makeCancellable(infectious: true) ?? Cancellable();
      addCSingleVListener(c, (value) {
        final v = value;
        if (test(v)) {
          completer.complete(v);
          c.cancel();
        }
      });
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
