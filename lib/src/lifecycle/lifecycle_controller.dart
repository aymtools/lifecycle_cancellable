import 'package:an_lifecycle_cancellable/src/lifecycle/lifecycle_data.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

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
  Set<Ticker>? _tickers;
  final ValueNotifier<bool> _tickerModeNotifier = ValueNotifier(true);

  _LifecycleTickerProvider(Lifecycle lifecycle) {
    _tickerModeNotifier.addListener(_updateTickers);
    lifecycle.addLifecycleObserver(LifecycleObserver.stateChange((state) =>
        _tickerModeNotifier.value = state >= LifecycleState.started));
    lifecycle.addLifecycleObserver(LifecycleObserver.eventDestroy(dispose));
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
  /// 基于[lifecycle]来生成 [TickerProvider]
  TickerProvider get tickerProvider =>
      toLifecycle().extData.getOrPut<_LifecycleTickerProvider>(
            key: _keyLifecycleTickerProvider,
            ifAbsent: (l) => _LifecycleTickerProvider(l),
          );
}
