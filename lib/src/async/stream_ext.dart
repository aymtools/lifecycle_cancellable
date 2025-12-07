import 'dart:async';

import 'package:an_lifecycle_cancellable/an_lifecycle_cancellable.dart';
import 'package:cancellable/cancellable.dart';

extension StreamDoneTimeoutExt<T> on Stream<T> {
  /// 设定stream 的 done 超时
  /// * [duration] 超时时间
  /// * [onTimeout] 超时时返回的值
  /// * [cancelOnError] 发生错误时 取消
  Stream<T> timeoutDone(Duration duration,
      {void Function(StreamSink<T> sink)? onTimeout,
      bool? cancelOnError = true}) {
    StreamController<T> controller = isBroadcast
        ? StreamController.broadcast(sync: true)
        : StreamController(sync: true);
    Timer? time;

    void onDone() {
      if (time?.isActive == true) time?.cancel();
      if (!controller.isClosed) {
        controller.close();
      }
    }

    controller.onListen = () {
      final subscription = listen(
        controller.add,
        onError: controller.addError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
      time = Timer(duration, () {
        if (!controller.isClosed) {
          onTimeout?.call(controller.sink);
          if (!controller.isClosed) {
            controller.close();
          }
        }
      });
      controller.onCancel = () {
        subscription.cancel();
        if (time?.isActive == true) time?.cancel();
      };
    };

    return controller.stream;
  }
}

extension StreamToolsExt<T> on Stream<T> {
  /// 每次触发数据时
  /// * [onData] 回调
  Stream<T> onData(void Function(T event) onData) => map((event) {
        onData(event);
        return event;
      });

  /// 重复上一个，对源stream会一直保持订阅，永远不会取消，建议前向使用[bindCancellable]或者[bindLifecycle]，来自动解除订阅
  /// * [repeatTimeout] 重复上一个的超时时间，如果[onTimeout]和[onRepeatTimeout]都不设置时，表示超时后清除重复数据
  /// * [onTimeout] 超时时返回的值,仅支持非[null]的值
  /// * [onRepeatTimeout] 超时时返回的值,允许[null]值
  /// * [repeatError] 是否重复错误
  /// * [broadcast] 是否广播
  Stream<T> repeatLatest(
      {Duration? repeatTimeout,
      T? onTimeout,
      T Function()? onRepeatTimeout,
      bool repeatError = false,
      bool? broadcast}) {
    var done = false;
    _RepeatEntry<T>? latest;
    Object? cacheError;
    StackTrace? cacheStackTrace;

    cleanCache() {
      latest = null;
      cacheError = null;
      cacheStackTrace = null;
    }

    handleError(Object error, StackTrace stackTrace) {
      cleanCache();
      cacheError = error;
      cacheStackTrace = stackTrace;
    }

    void Function(T value) setLatest = (value) {
      cleanCache();
      latest = _RepeatEntry(value);
    };

    Timer? timer;
    if (repeatTimeout != null && repeatTimeout > Duration.zero) {
      void Function() timeoutCallBack = cleanCache;
      if (onTimeout != null) {
        timeoutCallBack = () {
          cleanCache();
          latest = _RepeatEntry(onTimeout);
        };
      }

      if (onRepeatTimeout != null) {
        timeoutCallBack = () {
          cleanCache();
          latest = _RepeatEntry(onRepeatTimeout());
        };
      }

      setLatest = (value) {
        timer?.cancel();
        cleanCache();
        latest = _RepeatEntry(value);
        if (!done) {
          timer = Timer(repeatTimeout, timeoutCallBack);
        }
      };
    }

    var currentListeners = <MultiStreamController<T>>{};
    final isBroadcast_ = broadcast ?? isBroadcast;
    StreamSubscription<T>? sub;

    return Stream.multi((controller) {
      var latestValue = latest;
      if (latestValue != null) {
        if (!controller.isClosed) {
          controller.add(latestValue.value);
        }
      } else if (cacheError != null) {
        if (!controller.isClosed) {
          controller.addError(cacheError!, cacheStackTrace);
        }
      }
      if (done) {
        if (!controller.isClosed) {
          controller.close();
        }
        return;
      }
      currentListeners.add(controller);
      sub ??= listen((event) {
        setLatest(event);
        if (currentListeners.isNotEmpty) {
          for (var listener in [...currentListeners]) {
            if (!listener.isClosed) {
              listener.addSync(event);
            }
          }
        }
      }, onError: (Object error, StackTrace stack) {
        if (repeatError) {
          handleError(error, stack);
        }
        if (currentListeners.isNotEmpty) {
          for (var listener in [...currentListeners]) {
            if (!listener.isClosed) {
              listener.addErrorSync(error, stack);
            }
          }
        }
      }, onDone: () {
        done = true;
        if (currentListeners.isNotEmpty) {
          for (var listener in [...currentListeners]) {
            if (!listener.isClosed) {
              listener.close();
            }
          }
        }
        currentListeners.clear();
      });

      controller.onCancel = () => currentListeners.remove(controller);
    }, isBroadcast: isBroadcast_);
  }
}

class _RepeatEntry<T> {
  final T value;

  _RepeatEntry(this.value);
}
