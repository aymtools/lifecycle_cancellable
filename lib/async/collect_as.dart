import 'dart:async';

import 'package:an_lifecycle_cancellable/listenable/value_notifier.dart';
import 'package:cancellable/cancellable.dart';
import 'package:flutter/widgets.dart';

extension StreamToolsCollectAsStateExt<T> on Stream<T> {
  /// Collects the stream as a [ValueNotifier].
  ValueNotifier<T> collectAsState(
      {T? initial,
      T Function(Object error, StackTrace stackTrace)? onError,
      Cancellable? cancellable}) {
    ValueNotifier<T>? notifier;

    ValueNotifier<T> createNotifier(T value) {
      if (cancellable == null) {
        return ValueNotifier<T>(value);
      } else {
        return CancellableValueNotifier<T>(value, cancellable);
      }
    }

    late StreamSubscription<T> subscription;

    if (initial != null) {
      notifier = createNotifier(initial);
      subscription = listen((event) {
        notifier!.value = event;
      }, onError: (error, stackTrace) {
        if (onError != null) {
          notifier!.value = onError(error, stackTrace);
        }
      });
    } else {
      subscription = listen((event) {
        if (notifier == null) {
          notifier = createNotifier(event);
        } else {
          notifier!.value = event;
        }
      }, onError: (error, stackTrace) {
        if (onError != null) {
          final value = onError(error, stackTrace);
          if (notifier == null) {
            notifier = createNotifier(value);
          } else {
            notifier!.value = value;
          }
        }
      });
    }

    assert(notifier != null,
        'Stream did not emit any value and no initial value was provided.');

    cancellable?.whenCancel.then((_) => subscription.cancel());

    return notifier as ValueNotifier<T>;
  }
}

extension FutureToolsCollectAsStateExt<T> on Future<T> {
  /// Collects the future as a [ValueNotifier].
  ValueNotifier<T> collectAsState(
      {T? initial,
      T Function(Object error, StackTrace stackTrace)? onError,
      Cancellable? cancellable}) {
    ValueNotifier<T>? notifier;

    ValueNotifier<T> createNotifier(T value) {
      if (cancellable == null) {
        return ValueNotifier<T>(value);
      } else {
        return CancellableValueNotifier<T>(value, cancellable);
      }
    }

    if (initial != null) {
      notifier = createNotifier(initial);
      then((event) {
        notifier!.value = event;
      }, onError: (error, stackTrace) {
        if (onError != null) {
          notifier!.value = onError(error, stackTrace);
        }
      });
    } else {
      then((event) {
        if (notifier == null) {
          notifier = createNotifier(event);
        } else {
          notifier!.value = event;
        }
      }, onError: (error, stackTrace) {
        if (onError != null) {
          final value = onError(error, stackTrace);
          if (notifier == null) {
            notifier = createNotifier(value);
          } else {
            notifier!.value = value;
          }
        }
      });
    }

    assert(notifier != null,
        'Future is not syncFuture and no initial value was provided.');
    return notifier as ValueNotifier<T>;
  }
}
