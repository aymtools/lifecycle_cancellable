import 'package:anlifecycle/anlifecycle.dart';
import 'package:weak_collections/weak_collections.dart';

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

  /// 替换为新数据  返回结构为旧数据如果不存在旧数据则返回null
  T? replace<T>(TypedKey<T> key, T data) {
    final last = get<T>(key);
    _data[key] = data;
    return last;
  }

  /// 根据key获取
  T? get<T>(TypedKey<T> key) => _data[key] as T?;

  /// 手动移除指定的key
  T? remove<T>(TypedKey<T> key) => _data.remove(key) as T?;
}

final Map<Lifecycle, LifecycleExtData> _liveExtDataCache = WeakHashMap();

extension LifecycleTypedDataExt on Lifecycle {
  /// 获取lifecycle管理的扩展数据 于destroy时自动清理
  @Deprecated('use extData')
  LifecycleExtData get lifecycleExtData => extData;

  /// 获取lifecycle管理的扩展数据 于destroy时自动清理
  LifecycleExtData get extData {
    assert(currentLifecycleState > LifecycleState.destroyed,
        'The currentLifecycleState state must be greater than LifecycleState.destroyed.');
    return _liveExtDataCache.putIfAbsent(this, () {
      addObserver(LifecycleObserver.onEventDestroy(
          (owner) => _liveExtDataCache.remove(owner.lifecycle)?._data.clear()));
      return LifecycleExtData();
    });
  }
}

final Map<ILifecycleRegistry, LifecycleExtData> _liveRegistryExtDataCache =
    WeakHashMap();

extension LifecycleRegistryTypedDataExt on ILifecycleRegistry {
  /// 获取lifecycle管理的扩展数据 于destroy时自动清理
  @Deprecated('use extData')
  LifecycleExtData get lifecycleExtData => extData;

  /// 获取lifecycle管理的扩展数据 于destroy时自动清理
  LifecycleExtData get extData {
    assert(() {
      if (this is LifecycleRegistryState) {
        assert(currentLifecycleState > LifecycleState.initialized,
            'In LifecycleRegistryState, the currentLifecycleState must be greater than LifecycleState.initialized');
      } else {
        assert(currentLifecycleState > LifecycleState.destroyed,
            'The currentLifecycleState state must be greater than LifecycleState.destroyed.');
      }
      return true;
    }());
    return lifecycle.extData;
  }

  /// 获取 LifecycleRegistry 管理的扩展数据 于destroy时自动清理
  LifecycleExtData get extDataForRegistry {
    assert(currentLifecycleState > LifecycleState.destroyed,
        'The currentLifecycleState state must be greater than LifecycleState.destroyed.');
    return _liveRegistryExtDataCache.putIfAbsent(this, () {
      addLifecycleObserver(LifecycleObserver.onEventDestroy(
          (owner) => _liveRegistryExtDataCache.remove(this)?._data.clear()));
      return LifecycleExtData();
    });
  }
}
