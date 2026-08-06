import 'package:flutter/widgets.dart';

void runInNextFrameCallback(void Function() callback) {
  final bindings = WidgetsBinding.instance;

  bindings.addPostFrameCallback((_) => callback());

  bindings.ensureVisualUpdate();

  // switch (bindings.schedulerPhase) {
  //   case SchedulerPhase.transientCallbacks:
  //   case SchedulerPhase.midFrameMicrotasks:
  //   case SchedulerPhase.persistentCallbacks:
  //     bindings.addPostFrameCallback((_) => callback());
  //     break;
  //   case SchedulerPhase.postFrameCallbacks:
  //   // Timer.run(callback);
  //   // break;
  //   case SchedulerPhase.idle:
  //     // if (bindings.hasScheduledFrame) {
  //     //   bindings.scheduleTask(callback, Priority.animation);
  //     // } else {
  //     //   Timer.run(callback);
  //     // }
  //     bindings.scheduleTask(callback, Priority.touch);
  //     break;
  // }
}
