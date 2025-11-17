import 'package:cancellable/cancellable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Cancellable 取消后 set value 不在发出通知
class CancellableValueNotifier<T> extends ValueNotifier<T> {
  final Cancellable _cancellable;
  final bool notifyWhenEquals;
  T _value;

  CancellableValueNotifier(this._value, this._cancellable,
      [this.notifyWhenEquals = false])
      : super(_value) {
    _cancellable.whenCancel.then((_) => super.dispose());
  }

  @override
  T get value => _value;

  @override
  set value(T newValue) {
    if (_cancellable.isAvailable) {
      if (_value == newValue) {
        if (notifyWhenEquals) {
          super.notifyListeners();
        }
        return;
      }
      _value = newValue;
      super.notifyListeners();
    } else {
      // 仅仅赋值不通知
      _value = newValue;
    }
  }

  @override
  void addListener(VoidCallback listener) {
    if (_cancellable.isAvailable) {
      super.addListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_cancellable.isAvailable) {
      super.removeListener(listener);
    }
  }

  @override
  void notifyListeners() {
    if (_cancellable.isAvailable) {
      super.notifyListeners();
    }
  }

  @override
  // ignore: must_call_super
  void dispose() {
    _cancellable.cancel();
  }
}

extension ValueNotifierBuilderExt<T> on ValueListenable<T> {
  /// 快速构建一个ValueListenableBuilder
  /// ignore: non_constant_identifier_names
  Widget Builder({
    required Widget Function(BuildContext context, T value, Widget child)
        builder,
    Widget child = const SizedBox.shrink(),
    Key? key,
  }) {
    return ValueListenableBuilder<T>(
      key: key,
      valueListenable: this,
      builder: (context, value, _) {
        return builder(context, value, child);
      },
    );
  }
}
