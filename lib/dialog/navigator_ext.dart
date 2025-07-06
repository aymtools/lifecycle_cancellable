import 'dart:async';

import 'package:cancellable/cancellable.dart';
import 'package:flutter/material.dart';

extension NavigatorCancellableRoute on NavigatorState {
  /// 推入一个可撤销的route
  Future<T?> pushCancellableRoute<T extends Object?>(
      Route<T> route, Cancellable? cancellable) {
    if (cancellable == null) return push<T>(route);
    if (cancellable.isUnavailable == true) {
      return Future.value(null);
    }

    final Cancellable showing = Cancellable();
    // showing.bindCancellable(cancellable);
    cancellable.onCancel.then((_) {
      if (showing.isAvailable) {
        scheduleMicrotask(() {
          if (showing.isAvailable && route.isActive) {
            showing.cancel();
            route.navigator?.removeRoute(route);
          }
        });
      }
    });
    showing.onCancel.then(cancellable.cancel);

    return push<T>(route).whenComplete(() => showing.cancel());
  }

  /// 推入一个可撤销的dialog
  Future<T?> showDialog<T>({
    required WidgetBuilder builder,
    Cancellable? cancellable,
    bool barrierDismissible = true,
    Color? barrierColor = Colors.black54,
    String? barrierLabel,
    bool useSafeArea = true,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
    Offset? anchorPoint,
    // TraversalEdgeBehavior? traversalEdgeBehavior,
  }) {
    assert(debugCheckHasMaterialLocalizations(context));

    final CapturedThemes themes = InheritedTheme.capture(
      from: context,
      to: context,
    );

    final route = DialogRoute<T>(
      context: context,
      builder: builder,
      barrierColor: barrierColor,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      settings: routeSettings,
      themes: themes,
      anchorPoint: anchorPoint,
      // traversalEdgeBehavior:
      //     traversalEdgeBehavior ?? TraversalEdgeBehavior.closedLoop,
    );
    return pushCancellableRoute(route, cancellable);
  }
}
