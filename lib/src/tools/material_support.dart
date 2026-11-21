import 'package:an_lifecycle_cancellable/src/key/key.dart';
import 'package:an_lifecycle_cancellable/src/lifecycle/lifecycle_context_effect.dart';
import 'package:an_lifecycle_cancellable/src/lifecycle/lifecycle_controller.dart';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

@Deprecated('use package:remember, will remove v2.6.0')
extension BuildContextLifecycleWithControllerExt on BuildContext {
  // /// 将对象寄生在extData中并且以当前的context为key的一部分
  // T getLifecycleExtData<T extends Object>({
  //   T Function()? factory,
  //   T Function(Lifecycle lifecycle)? factory2,
  //   Object? key,
  // }) {
  //   final lifecycle = Lifecycle.of(this);
  //   final liveData = lifecycle.extData;
  //   if (factory != null) {
  //     return liveData.putIfAbsent(key: key, ifAbsent: factory);
  //   } else if (factory2 != null) {
  //     return liveData.putIfAbsent(
  //         key: key, ifAbsent: () => factory2(lifecycle));
  //   }
  //   throw 'factory and factory2 cannot be null at the same time';
  // }

  /// 获取可用的TabController
  @Deprecated('use package:remember')
  TabController withLifecycleTabController({
    int initialIndex = 0,
    Duration? animationDuration,
    required int length,
    Object? key,
  }) =>
      withLifecycleExtData<TabController>(
        factory2: (l) => TabController(
          initialIndex: initialIndex,
          length: length,
          vsync: l.tickerProvider,
        ),
        key: FlexibleKey(
            TabController, initialIndex, animationDuration, length, key),
      );

  /// 动画控制器
  @Deprecated('use package:remember')
  AnimationController withLifecycleAnimationController({
    double? value,
    Duration? duration,
    Duration? reverseDuration,
    String? debugLabel,
    double lowerBound = 0.0,
    double upperBound = 1.0,
    AnimationBehavior animationBehavior = AnimationBehavior.normal,
    Object? key,
  }) {
    return withLifecycleExtData<AnimationController>(
        factory2: (l) => AnimationController(
              value: value,
              duration: duration,
              reverseDuration: reverseDuration,
              debugLabel: debugLabel,
              lowerBound: lowerBound,
              upperBound: upperBound,
              animationBehavior: animationBehavior,
              vsync: l.tickerProvider,
            ),
        key: FlexibleKey(AnimationController, value, duration, reverseDuration,
            lowerBound, upperBound, animationBehavior, key));
  }

  /// 动画控制器
  @Deprecated('use package:remember')
  AnimationController withLifecycleAnimationControllerUnbounded({
    double value = 0.0,
    Duration? duration,
    Duration? reverseDuration,
    String? debugLabel,
    AnimationBehavior animationBehavior = AnimationBehavior.normal,
    Object? key,
  }) {
    return withLifecycleExtData<AnimationController>(
        factory2: (l) => AnimationController.unbounded(
              value: value,
              duration: duration,
              reverseDuration: reverseDuration,
              debugLabel: debugLabel,
              animationBehavior: animationBehavior,
              vsync: l.tickerProvider,
            ),
        key: FlexibleKey(AnimationController, 'Unbounded', value, duration,
            reverseDuration, animationBehavior, key));
  }
}
