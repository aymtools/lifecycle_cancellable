import 'dart:async';

extension StreamDoneTimeoutExt<T> on Stream<T> {
  Stream<T> timeoutDone(Duration duration,
      {void Function(StreamSink<T> sink)? onTimeout}) {
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
        cancelOnError: true,
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
