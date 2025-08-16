import 'package:an_lifecycle_cancellable/key/key.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:weak_collections/weak_collections.dart';

export 'package:an_lifecycle_cancellable/key/key.dart' show TypedKey;

Object _genKey<T extends Object>({Object? key}) => key == null
    ? T
    : key is TypedKey<T>
        ? key
        : TypedKey<T>(key);

/// 寄存于lifecycle的数据 基类
abstract class LifecycleExtData {
  final Map<Object, Object?> _data = {};
  bool _isDestroyed = false;

  /// 判断当前是否是已经销毁状态
  bool get isDestroyed => _isDestroyed;

  LifecycleExtData._();

  /// 根据Type + key获取，如果不存在则创建信息
  T putIfAbsent<T extends Object>(
      {Object? key, required T Function() ifAbsent}) {
    if (_isDestroyed) {
      throw Exception('extData has been destroyed.');
    }
    return _data.putIfAbsent(_genKey<T>(key: key), ifAbsent) as T;
  }

  /// 替换为新数据  返回结构为旧数据如果不存在旧数据则返回null
  T? replace<T extends Object>({Object? key, required T data}) {
    if (_isDestroyed) return null;
    final k = _genKey<T>(key: key);
    final last = _data[k] as T?;
    _data[k] = data;
    return last;
  }

  /// 根据key获取
  T? get<T extends Object>({Object? key}) => _data[_genKey<T>(key: key)] as T?;

  /// 手动移除指定的key
  T? remove<T extends Object>({Object? key}) =>
      _data.remove(_genKey<T>(key: key)) as T?;

  // 执行销毁
  void _destroy() {
    _isDestroyed = true;
    _data.clear();
  }
}

/// 寄存于lifecycle的数据
class LiveExtData extends LifecycleExtData {
  Lifecycle? _lifecycle;

  LiveExtData._(this._lifecycle) : super._();

  /// 根据Type + key获取，如果不存在则创建信息
  T getOrPut<T extends Object>(
      {Object? key, required T Function(Lifecycle lifecycle) ifAbsent}) {
    if (_isDestroyed) {
      throw Exception('extData has been destroyed.');
    }
    return _data.putIfAbsent(_genKey<T>(key: key), () => ifAbsent(_lifecycle!))
        as T;
  }

  @override
  void _destroy() {
    super._destroy();
    _lifecycle = null;
  }
}

/// 寄存于lifecycle的数据
class LifecycleRegistryExtData extends LifecycleExtData {
  ILifecycleRegistry? _lifecycle;

  LifecycleRegistryExtData._(this._lifecycle) : super._();

  /// 根据Type + key获取，如果不存在则创建信息
  T getOrPut<T extends Object>(
      {Object? key,
      required T Function(ILifecycleRegistry lifecycle) ifAbsent}) {
    if (_isDestroyed) {
      throw Exception('extData has been destroyed.');
    }
    return _data.putIfAbsent(_genKey<T>(key: key), () => ifAbsent(_lifecycle!))
        as T;
  }

  @override
  void _destroy() {
    super._destroy();
    _lifecycle = null;
  }
}

final Map<Lifecycle, LiveExtData> _liveExtDataCache = WeakHashMap();

extension LifecycleTypedDataExt on Lifecycle {
  /// 获取lifecycle管理的扩展数据 于destroy时自动清理
  @Deprecated('use extData')
  LiveExtData get lifecycleExtData => extData;

  /// 获取lifecycle管理的扩展数据 于destroy时自动清理
  LiveExtData get extData {
    assert(currentLifecycleState > LifecycleState.destroyed,
        'The currentLifecycleState state must be greater than LifecycleState.destroyed.');
    return _liveExtDataCache.putIfAbsent(this, () {
      addObserver(LifecycleObserver.onEventDestroy(
          (owner) => _liveExtDataCache.remove(owner.lifecycle)?._destroy()));
      return LiveExtData._(this);
    });
  }
}

final Map<ILifecycleRegistry, LifecycleRegistryExtData>
    _liveRegistryExtDataCache = WeakHashMap();

extension LifecycleRegistryTypedDataExt on ILifecycleRegistry {
  /// 获取lifecycle管理的扩展数据 于destroy时自动清理
  @Deprecated('use extData')
  LiveExtData get lifecycleExtData => extData;

  /// 获取lifecycle管理的扩展数据 于destroy时自动清理
  LiveExtData get extData {
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
  LifecycleRegistryExtData get extDataForRegistry {
    assert(currentLifecycleState > LifecycleState.destroyed,
        'The currentLifecycleState state must be greater than LifecycleState.destroyed.');
    return _liveRegistryExtDataCache.putIfAbsent(this, () {
      addLifecycleObserver(LifecycleObserver.onEventDestroy(
          (owner) => _liveRegistryExtDataCache.remove(this)?._destroy()));
      return LifecycleRegistryExtData._(this);
    });
  }
}
