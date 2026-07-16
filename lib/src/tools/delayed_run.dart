import 'package:flutter/scheduler.dart' show SchedulerPhase, Priority;
import 'package:flutter/widgets.dart';

void runAfterNextFrameCallbackOrNextEventLoop(void Function() callback) {
  final bindings = WidgetsBinding.instance;

  switch (bindings.schedulerPhase) {
    case SchedulerPhase.transientCallbacks:
    case SchedulerPhase.midFrameMicrotasks:
    case SchedulerPhase.persistentCallbacks:
      bindings.addPostFrameCallback((_) => callback());
      break;
    case SchedulerPhase.postFrameCallbacks:
    // Timer.run(callback);
    // break;
    case SchedulerPhase.idle:
      // if (bindings.hasScheduledFrame) {
      //   bindings.scheduleTask(callback, Priority.animation);
      // } else {
      //   Timer.run(callback);
      // }
      bindings.scheduleTask(callback, Priority.touch);
      break;
  }
}
