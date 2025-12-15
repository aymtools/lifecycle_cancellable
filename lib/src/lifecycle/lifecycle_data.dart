import 'dart:collection';

import 'package:an_lifecycle_cancellable/src/key/key.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:weak_collections/weak_collections.dart';

export 'package:an_lifecycle_cancellable/src/key/key.dart' show TypedKey;

Object _genKey<T extends Object>({Object? key}) => key == null
    ? T
    : key is TypedKey<T>
        ? key
        : TypedKey<T>(key);

typedef LifecycleExtDataOnDestroy<T> = void Function(T data);

class _ExtDataEntry<T> {
  T data;
  final LifecycleExtDataOnDestroy<T>? onDestroy;

  _ExtDataEntry(this.data, this.onDestroy);

  void _destroy() {
    onDestroy?.call(data);
  }
}

/// 寄存于lifecycle的数据 基类
abstract class LifecycleExtData {
  final Map<Object, _ExtDataEntry> _data = HashMap();
  bool _isDestroyed = false;

  /// 判断当前是否是已经销毁状态
  bool get isDestroyed => _isDestroyed;

  LifecycleExtData._();

  /// 根据Type + key获取，如果不存在则创建信息
  T putIfAbsent<T extends Object>({Object? key,
    required T Function() ifAbsent,
    LifecycleExtDataOnDestroy<T>? onDestroy}) {
    if (_isDestroyed) {
      throw Exception('extData has been destroyed.');
    }
    return _data
        .putIfAbsent(
            _genKey<T>(key: key), () => _ExtDataEntry<T>(ifAbsent(), onDestroy))
        .data;
  }

  /// 替换为新数据  返回结构为旧数据如果不存在旧数据则返回null
  T? replace<T extends Object>(
      {Object? key, required T data, bool callOnDestroy = true}) {
    if (_isDestroyed) return null;
    final k = _genKey<T>(key: key);
    final entry = _data[k];
    final last = entry?.data;
    entry?.data = data;
    if (callOnDestroy && last != null) {
      entry?.onDestroy?.call(last);
    }
    return last;
  }

  /// 根据key获取
  T? get<T extends Object>({Object? key}) =>
      _data[_genKey<T>(key: key)]?.data as T?;

  /// 手动移除指定的key
  T? remove<T extends Object>({Object? key, bool callOnDestroy = true}) {
    final entry = _data.remove(_genKey<T>(key: key));
    final d = entry?.data;
    if (callOnDestroy) {
      entry?._destroy();
    }
    return d as T?;
  }

  // 执行销毁
  void _destroy() {
    _isDestroyed = true;
    final values = [..._data.values];
    _data.clear();
    for (final entry in values) {
      entry._destroy();
    }
  }
}

/// 寄存于lifecycle的数据
class LiveExtData extends LifecycleExtData {
  WeakReference<Lifecycle>? _lifecycle;

  LiveExtData._(Lifecycle lifecycle)
      : _lifecycle = WeakReference(lifecycle),
        super._();

  /// 根据Type + key获取，如果不存在则创建信息
  T getOrPut<T extends Object>({Object? key,
    required T Function(Lifecycle lifecycle) ifAbsent,
    LifecycleExtDataOnDestroy<T>? onDestroy}) {
    final lifecycle = _lifecycle?.target;
    if (_isDestroyed || lifecycle == null) {
      throw Exception('extData has been destroyed.');
    }
    return _data
        .putIfAbsent(_genKey<T>(key: key),
            () => _ExtDataEntry<T>(ifAbsent(lifecycle), onDestroy))
        .data;
  }

  @override
  void _destroy() {
    super._destroy();
    _lifecycle = null;
  }
}

/// 寄存于lifecycle的数据
class LifecycleRegistryExtData extends LifecycleExtData {
  WeakReference<ILifecycleRegistry>? _lifecycle;

  LifecycleRegistryExtData._(ILifecycleRegistry lifecycle)
      : _lifecycle = WeakReference(lifecycle),
        super._();

  /// 根据Type + key获取，如果不存在则创建信息
  T getOrPut<T extends Object>(
      {Object? key,
      required T Function(ILifecycleRegistry lifecycle) ifAbsent,
      LifecycleExtDataOnDestroy<T>? onDestroy}) {
    final lifecycle = _lifecycle?.target;
    if (_isDestroyed || lifecycle == null) {
      throw Exception('extData has been destroyed.');
    }
    return _data
        .putIfAbsent(_genKey<T>(key: key),
            () => _ExtDataEntry<T>(ifAbsent(lifecycle), onDestroy))
        .data;
  }

  @override
  void _destroy() {
    super._destroy();
    _lifecycle = null;
  }
}

final Map<Lifecycle, LiveExtData> _liveExtDataCache = WeakHashMap.identity();

extension LifecycleTypedDataExt on Lifecycle {
  /// 获取[lifecycle]管理的扩展数据 于[destroy]时自动清理
  @Deprecated('use extData')
  LiveExtData get lifecycleExtData => extData;

  /// 获取[lifecycle]管理的扩展数据 于[destroy]时自动清理
  LiveExtData get extData {
    assert(currentLifecycleState > LifecycleState.destroyed,
        'The currentLifecycleState state must be greater than LifecycleState.destroyed.');
    if (currentLifecycleState == LifecycleState.destroyed) {
      return LiveExtData._(this).._destroy();
    }
    return _liveExtDataCache.putIfAbsent(this, () {
      addObserver(LifecycleObserver.onEventDestroy(
          (owner) => _liveExtDataCache.remove(owner.lifecycle)?._destroy()));
      return LiveExtData._(this);
    });
  }
}

final Map<ILifecycleRegistry, LifecycleRegistryExtData>
    _liveRegistryExtDataCache = WeakHashMap.identity();

extension LifecycleRegistryTypedDataExt on ILifecycleRegistry {
  /// 获取[lifecycle]管理的扩展数据 于[destroy]时自动清理
  @Deprecated('use extData')
  LiveExtData get lifecycleExtData => extData;

  /// 获取[lifecycle]管理的扩展数据 于[destroy]时自动清理
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

  /// 获取 [LifecycleRegistry] 管理的扩展数据 于[destroy]时自动清理
  LifecycleRegistryExtData get extDataForRegistry {
    assert(currentLifecycleState > LifecycleState.destroyed,
        'The currentLifecycleState state must be greater than LifecycleState.destroyed.');
    if (currentLifecycleState == LifecycleState.destroyed) {
      return LifecycleRegistryExtData._(this).._destroy();
    }
    return _liveRegistryExtDataCache.putIfAbsent(this, () {
      addLifecycleObserver(LifecycleObserver.onEventDestroy(
          (owner) => _liveRegistryExtDataCache.remove(this)?._destroy()));
      return LifecycleRegistryExtData._(this);
    });
  }
}
