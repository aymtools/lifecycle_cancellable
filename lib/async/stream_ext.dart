import 'dart:async';

extension StreamDoneTimeoutExt<T> on Stream<T> {
  /// 设定stream 的 done 超时
  Stream<T> timeoutDone(Duration duration,
      {void Function(StreamSink<T> sink)? onTimeout,
      bool? cancelOnError = true}) {
    StreamController<T> controller =
        isBroadcast ? StreamController.broadcast() : StreamController();
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
          controller.close();
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
  Stream<T> onData(void Function(T event) onData) => map((event) {
        onData(event);
        return event;
      });

  /// 重复上一个
  Stream<T> repeatLatest(
      {Duration? repeatTimeout,
      T? onTimeout,
      T Function()? onRepeatTimeout,
      bool repeatError = false,
      bool? broadcast}) {
    var done = false;
    T? latest;
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
      latest = value;
    };

    Timer? timer;
    if (repeatTimeout != null && repeatTimeout > Duration.zero) {
      void Function() timeoutCallBack = () => latest = onTimeout;

      if (onRepeatTimeout != null) {
        timeoutCallBack = () => latest = onRepeatTimeout();
      }

      setLatest = (value) {
        timer?.cancel();
        cleanCache();
        latest = value;
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
          controller.add(latestValue);
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
              listener.closeSync();
            }
          }
        }
        currentListeners.clear();
      });

      controller.onCancel = () => currentListeners.remove(controller);
    }, isBroadcast: isBroadcast_);
  }
}
