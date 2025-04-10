import 'dart:async';

import 'package:an_lifecycle_cancellable/lifecycle/lifecycle_ext.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:cancellable/cancellable.dart';

extension StreamLifecycleExt<T> on Stream<T> {
  /// 将Stream关联到lifecycle
  /// [repeatLastOnRestart] 是指当重新进入到状态时，是否发射之前的数据
  Stream<T> bindLifecycle(ILifecycle lifecycle,
      {LifecycleState state = LifecycleState.created,
      @Deprecated('use repeatLastOnStateAtLeast v2.2.2')
      bool repeatLastOnRestart = false,
      bool repeatLastOnStateAtLeast = false,
      bool closeWhenCancel = false,
      bool? cancelOnError}) {
    if (state < LifecycleState.initialized) {
      /// 如果与生命周期无关 则直接返回
      return this;
    } else if (state <= LifecycleState.created) {
      // 如果是仅仅关心 当前 LifecycleState 的状态是未销毁的 则转换为 bindCancellable
      return bindCancellable(lifecycle.makeLiveCancellable(),
          closeWhenCancel: closeWhenCancel);
    }

    /// 保持旧版兼容性 未来删除
    repeatLastOnStateAtLeast = repeatLastOnStateAtLeast || repeatLastOnRestart;

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
      if (lifecycle.currentLifecycleState >= state) {
        cleanCache.call();
        sink.addError(error, stackTrace);
      } else {
        cacheError = error;
        cacheStackTrace = stackTrace;
        cacheErrorSink = sink;
      }
    }

    if (repeatLastOnStateAtLeast) {
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
            if (lifecycle.currentLifecycleState >= state) {
              sink.add(data);
            } else {
              cache = data;
              eventSink = sink;
            }
          }
        },
        handleError: handleError,
      );
      lifecycle.repeatOnLifecycle(
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
          if (!isClose && lifecycle.currentLifecycleState >= state) {
            sink.add(data);
          }
        },
        handleError: handleError,
      );
      lifecycle.repeatOnLifecycle(
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

    return bindCancellable(lifecycle.makeLiveCancellable(),
            closeWhenCancel: closeWhenCancel)
        .transform(transformer);
  }
}

extension FutureLifecycleExt<T> on Future<T> {
  /// 将future关联到lifecycle
  Future<T> bindLifecycle(ILifecycle registry, {bool throwWhenCancel = false}) {
    return bindCancellable(registry.makeLiveCancellable(),
        throwWhenCancel: throwWhenCancel);
  }
}
