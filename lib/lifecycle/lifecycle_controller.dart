import 'package:an_lifecycle_cancellable/lifecycle/lifecycle_context_effect.dart';
import 'package:an_lifecycle_cancellable/lifecycle/lifecycle_data.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class _LifecycleTicker extends Ticker {
  final _LifecycleTickerProvider _creator;

  _LifecycleTicker(super.onTick, this._creator, {super.debugLabel});

  @override
  void dispose() {
    _creator._removeTicker(this);
    super.dispose();
  }
}

class _LifecycleTickerProvider implements TickerProvider {
  final Lifecycle lifecycle;
  Set<Ticker>? _tickers;
  final ValueNotifier<bool> _tickerModeNotifier = ValueNotifier(true);

  _LifecycleTickerProvider(this.lifecycle) {
    _tickerModeNotifier.addListener(_updateTickers);
    lifecycle.addLifecycleObserver(LifecycleObserver.eventDestroy(dispose));
    lifecycle.addLifecycleObserver(LifecycleObserver.stateChange((state) =>
        _tickerModeNotifier.value = state >= LifecycleState.started));
  }

  @override
  Ticker createTicker(TickerCallback onTick) {
    _tickers ??= <_LifecycleTicker>{};
    final _LifecycleTicker result = _LifecycleTicker(onTick, this,
        debugLabel: kDebugMode ? 'created by ${describeIdentity(this)}' : null)
      ..muted = !_tickerModeNotifier.value;
    _tickers!.add(result);
    return result;
  }

  void _removeTicker(_LifecycleTicker ticker) {
    assert(_tickers != null);
    assert(_tickers!.contains(ticker));
    _tickers!.remove(ticker);
  }

  void _updateTickers() {
    if (_tickers != null) {
      final bool muted = !_tickerModeNotifier.value;
      for (final Ticker ticker in _tickers!) {
        ticker.muted = muted;
      }
    }
  }

  void dispose() {
    assert(() {
      if (_tickers != null) {
        for (final Ticker ticker in _tickers!) {
          if (ticker.isActive) {
            throw FlutterError.fromParts(<DiagnosticsNode>[
              ErrorSummary('$this was disposed with an active Ticker.'),
              ErrorDescription(
                '$runtimeType created a Ticker via its Lifecycle, but at the time '
                'dispose() was called on the mixin, that Ticker was still active. All Tickers must '
                'be disposed before calling super.dispose().',
              ),
              ErrorHint(
                'Tickers used by AnimationControllers '
                'should be disposed by calling dispose() on the AnimationController itself. '
                'Otherwise, the ticker will leak.',
              ),
              ticker.describeForError('The offending ticker was'),
            ]);
          }
        }
      }
      return true;
    }());
    _tickerModeNotifier.removeListener(_updateTickers);
  }
}

final _keyLifecycleTickerProvider = Object();

extension LifecycleTickerProviderExt on ILifecycle {
  /// 基于lifecycle来生成 TickerProvider
  TickerProvider get tickerProvider =>
      toLifecycle().extData.getOrPut<_LifecycleTickerProvider>(
            key: _keyLifecycleTickerProvider,
            ifAbsent: (l) => _LifecycleTickerProvider(l),
          );
}

extension BuildContextLifecycleWithControllerExt on BuildContext {
  /// 将对象寄生在extData中并且以当前的context为key的一部分
  T getLifecycleExtData<T extends Object>({
    T Function()? factory,
    T Function(Lifecycle lifecycle)? factory2,
    Object? key,
  }) {
    final lifecycle = Lifecycle.of(this);
    final liveData = lifecycle.extData;
    if (factory != null) {
      return liveData.putIfAbsent(key: key, ifAbsent: factory);
    } else if (factory2 != null) {
      return liveData.putIfAbsent(
          key: key, ifAbsent: () => factory2(lifecycle));
    }
    throw 'factory and factory2 cannot be null at the same time';
  }

  /// 获取可用的TabController
  TabController withLifecycleTabController({
    int initialIndex = 0,
    Duration? animationDuration,
    required int length,
    Object? key,
  }) =>
      withLifecycleExtData<TabController>(
        factory2: (l) => TabController(
          initialIndex: initialIndex,
          length: length,
          vsync: l.tickerProvider,
        ),
        key: _TabControllerKey(initialIndex, animationDuration, length, key),
      );
}

class _TabControllerKey {
  final int initialIndex;

  final Duration? animationDuration;
  final int length;
  final Object? key;

  _TabControllerKey(
      this.initialIndex, this.animationDuration, this.length, this.key);

  @override
  int get hashCode => Object.hash(initialIndex, animationDuration, length, key);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _TabControllerKey &&
        other.initialIndex == initialIndex &&
        other.animationDuration == animationDuration &&
        other.length == length &&
        other.key == key;
  }
}
