import 'package:anlifecycle/anlifecycle.dart';
import 'package:weak_collections/weak_collections.dart' as weak;

final Map<Lifecycle, LifecycleExtDataObserver> _liveExtDataObserver =
    weak.WeakMap();

class TypedKey<T> {
  final Object? key;

  TypedKey([this.key]);

  @override
  int get hashCode => Object.hashAll([T, key]);

  @override
  bool operator ==(Object other) {
    return other is TypedKey<T> && key == other.key;
  }
}

/// 寄存于lifecycle的数据
class LifecycleExtData {
  final Map<TypedKey, Object?> _data = {};

  /// 根据key获取，如果不存在则创建信息
  T putIfAbsent<T>(TypedKey<T> key, T Function() ifAbsent) {
    return _data.putIfAbsent(key, ifAbsent) as T;
  }

  /// 根据key获取
  T? get<T>(TypedKey<T> key) => _data[key] as T?;

  /// 手动移除指定的key
  T? remove<T>(TypedKey<T> key) => _data.remove(key) as T?;
}

class LifecycleExtDataObserver with LifecycleEventObserver {
  late final LifecycleExtData _extData = LifecycleExtData();

  @override
  void onDestroy(LifecycleOwner owner) {
    super.onDestroy(owner);
    _extData._data.clear();
  }
}

extension LifeTypedDataExt on LifecycleObserverRegistry {
  /// 获取lifecycle管理的扩展数据 于destroy时自动清理
  LifecycleExtData get lifecycleExtData {
    assert(
        currentLifecycleState < LifecycleState.initialized, '不可知destroyed下使用');
    final observer = _liveExtDataObserver.putIfAbsent(lifecycle, () {
      final observer = LifecycleExtDataObserver();
      addLifecycleObserver(observer, fullCycle: true);
      return LifecycleExtDataObserver();
    });
    return observer._extData;
  }
}
