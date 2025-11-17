import 'package:anlifecycle/anlifecycle.dart';

/// 弱引用式的 当lifecycle destroy 时自动清理map
class MapAutoClearObserver with LifecycleStateChangeObserver {
  final WeakReference<Map> _weakReference;

  MapAutoClearObserver(Map map) : _weakReference = WeakReference(map);

  void clear() {
    _weakReference.target?.clear();
  }

  @override
  void onStateChange(LifecycleOwner owner, LifecycleState state) {
    if (state == LifecycleState.destroyed) {
      clear();
    } else if (_weakReference.target == null) {
      // 如果发现已经被销毁了 则将当前的Observer也注销掉
      owner.removeLifecycleObserver(this, fullCycle: false);
    }
  }
}
