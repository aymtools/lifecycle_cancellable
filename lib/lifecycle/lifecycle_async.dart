import 'dart:async';

import 'package:an_lifecycle_cancellable/lifecycle/lifecycle_ext.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:cancellable/cancellable.dart';

extension StreamLifecycleExt<T> on Stream<T> {
  /// 将Stream关联到lifecycle
  /// [repeatLastOnRestart] 是指当从新进入到状态时，是否发射之前的数据
  Stream<T> bindLifecycle(LifecycleObserverRegistry registry,
      {LifecycleState state = LifecycleState.started,
      bool repeatLastOnRestart = false,
      bool closeWhenCancel = false,
      bool? cancelOnError}) {
    StreamTransformer<T, T> transformer;
    bool isClose = false;

    Object? cacheError;
    StackTrace? cacheStackTrace;
    EventSink<T>? cacheErrorSink;

    void Function() cleanCache = () {
      cacheError = null;
      cacheStackTrace = null;
      cacheErrorSink = null;
    };

    handleError(Object error, StackTrace stackTrace, EventSink<T> sink) {
      if (isClose) return;
      if (cancelOnError == true && cacheError != null) return;
      if (registry.currentLifecycleState >= state) {
        cleanCache.call();
        sink.addError(error, stackTrace);
      } else {
        cacheError = error;
        cacheStackTrace = stackTrace;
        cacheErrorSink = sink;
      }
    }

    if (repeatLastOnRestart) {
      T? cache;
      EventSink<T>? eventSink;
      final lastCleanCache = cleanCache;
      cleanCacheDate() {
        lastCleanCache.call();
        cache = null;
        eventSink = null;
      }

      cleanCache = cleanCacheDate;

      transformer = StreamTransformer<T, T>.fromHandlers(
        handleData: (data, sink) {
          if (cancelOnError == true && cacheError != null) return;
          cleanCache.call();
          if (!isClose) {
            if (registry.currentLifecycleState >= state) {
              sink.add(data);
            } else {
              cache = data;
              eventSink = sink;
            }
          }
        },
        handleError: handleError,
      );
      registry.repeatOnLifecycle(
          targetState: state,
          block: (_) {
            if (!isClose && cacheError != null && cacheErrorSink != null) {
              cacheErrorSink?.addError(cacheError!, cacheStackTrace);
              if (cancelOnError == true) {
                isClose = true;
                cacheErrorSink?.close();
              }
            } else if (!isClose && cache != null && eventSink != null) {
              eventSink?.add(cache as T);
            }
            cleanCache.call();
          });
    } else {
      transformer = StreamTransformer<T, T>.fromHandlers(
        handleData: (data, sink) {
          if (cancelOnError == true && cacheError != null) return;
          cleanCache.call();
          if (!isClose && registry.currentLifecycleState >= state) {
            sink.add(data);
          }
        },
        handleError: handleError,
      );
      registry.repeatOnLifecycle(
          targetState: state,
          block: (_) {
            if (!isClose && cacheError != null && cacheErrorSink != null) {
              cacheErrorSink?.addError(cacheError!, cacheStackTrace);
              if (cancelOnError == true) {
                isClose = true;
                cacheErrorSink?.close();
              }
            }
            cleanCache.call();
          });
    }

    return bindCancellable(registry.makeLiveCancellable(),
            closeWhenCancel: closeWhenCancel)
        .transform(transformer);
  }
}

extension FutureLifecycleExt<T> on Future<T> {
  /// 将future关联到lifecycle
  Future<T> bindLifecycle(LifecycleObserverRegistry registry,
      {bool throwWhenCancel = false}) {
    return bindCancellable(registry.makeLiveCancellable(),
        throwWhenCancel: throwWhenCancel);
  }
}
