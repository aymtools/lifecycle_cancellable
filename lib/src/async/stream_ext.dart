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
  /// * [broadcast] 是否是广播Stream
  /// * [lazyListen] 是否延迟订阅；
  /// 1. [lazyListen]值为[true]时，不会立即订阅，默认值；
  /// a. 针对[source]为[broadcast]时，直到有第一个订阅时才会开始记录最后的值，被订阅之前的值都会被丢弃，之后有变化会更新最后一个值；
  /// b. 针对[source]不是[broadcast]时，会在第一个订阅时立即订阅发布流内所有的值，然后记录最后一个值，之后有变化会更新最后一个值；
  /// 2. [lazyListen]值为false时，会进行对源立即订阅；
  /// a. 针对[source]为[broadcast]时，会立即订阅发布流，在此之前的值会被丢弃，会记录最后的一个值，之后有变化会更新最后一个值；
  /// b. 针对[source]不是[broadcast]时，会立即订阅发布流内，在此之前的值只会保留最后一个值，之后有变化会更新最后一个值；
  Stream<T> repeatLatest(
      {Duration? repeatTimeout,
      T? onTimeout,
      T Function()? onRepeatTimeout,
      bool repeatError = false,
      bool? broadcast,
      bool lazyListen = true}) {
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

    void startSubscribe() {
      if (done) return;
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
    }

    Stream<T> result = Stream.multi((controller) {
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

      startSubscribe();

      controller.onCancel = () => currentListeners.remove(controller);
    }, isBroadcast: isBroadcast_);

    if (!lazyListen) {
      startSubscribe();
    }

    return result;
  }
}

class _RepeatEntry<T> {
  final T value;

  _RepeatEntry(this.value);
}
