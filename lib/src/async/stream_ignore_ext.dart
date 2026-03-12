import 'dart:async';

extension StreamIgnoreNoElementExt<T> on Stream<T> {
  /// 获取流中的第一个元素 如果是empty则不执行后续的 then
  Future<T> get firstIgnoreNoElement {
    Completer<T> completer = Completer();
    late StreamSubscription<T> subscription;
    subscription = listen(
      (event) {
        completer.complete(event);
        subscription.cancel();
      },
      onError: completer.completeError,
      cancelOnError: true,
    );
    return completer.future;
  }

  /// 获取流中的最后一个元素 如果是empty则不执行后续的 then
  Future<T> get lastIgnoreNoElement {
    Completer<T> completer = Completer();
    bool hasValue = false;
    T? lastValue;
    listen(
      (event) {
        lastValue = event;
        hasValue = true;
      },
      onError: completer.completeError,
      onDone: () {
        if (hasValue) {
          completer.complete(lastValue);
        }
      },
      cancelOnError: true,
    );
    return completer.future;
  }

  /// 获取流中的唯一个元素 如果是empty则不执行后续的 then
  Future<T> get singleIgnoreNoElement {
    Completer<T> completer = Completer();
    T? singleValue;
    bool hasValue = false;
    late StreamSubscription<T> subscription;
    subscription = listen(
      (event) {
        if (hasValue) {
          completer.completeError(StateError('More than one element'));
          subscription.cancel();
        } else {
          singleValue = event;
          hasValue = true;
        }
      },
      onError: completer.completeError,
      onDone: () {
        if (hasValue) {
          completer.complete(singleValue!);
        }
      },
      cancelOnError: true,
    );
    return completer.future;
  }

  /// 根据条件获取流中的第一个元素 如果是empty则不执行后续的 then
  Future<T> firstWhereIgnoreNoElement(bool Function(T element) test) {
    Completer<T> completer = Completer();
    late StreamSubscription<T> subscription;
    subscription = listen(
      (event) {
        if (test(event)) {
          completer.complete(event);
          subscription.cancel();
        }
      },
      onError: completer.completeError,
      cancelOnError: true,
    );
    return completer.future;
  }

  /// 根据条件获取流中的最后一个元素 如果是empty则不执行后续的 then
  Future<T> lastWhereIgnoreNoElement(bool Function(T element) test) {
    Completer<T> completer = Completer();
    bool hasValue = false;
    T? lastValue;
    listen(
      (event) {
        if (test(event)) {
          lastValue = event;
          hasValue = true;
        }
      },
      onError: completer.completeError,
      onDone: () {
        if (hasValue) {
          completer.complete(lastValue!);
        }
      },
      cancelOnError: true,
    );
    return completer.future;
  }

  /// 根据条件获取流中的唯一个元素 如果是empty则不执行后续的 then
  Future<T> singleWhereIgnoreNoElement(bool Function(T element) test) {
    Completer<T> completer = Completer();
    T? singleValue;
    bool hasValue = false;
    late StreamSubscription<T> subscription;
    subscription = listen(
      (event) {
        if (test(event)) {
          if (hasValue) {
            completer.completeError(StateError('More than one element'));
            subscription.cancel();
          } else {
            singleValue = event;
            hasValue = true;
          }
        }
      },
      onError: completer.completeError,
      onDone: () {
        if (hasValue) {
          completer.complete(singleValue!);
        }
      },
      cancelOnError: true,
    );
    return completer.future;
  }
}
