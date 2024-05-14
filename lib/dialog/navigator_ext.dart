import 'package:cancellable/cancellable.dart';
import 'package:flutter/material.dart';

extension NavigatorCancellableRoute on NavigatorState {
  Future<T?> pushCancellableRoute<T extends Object?>(
      Route<T> route, Cancellable? cancellable) {
    if (cancellable == null) return push<T>(route);
    if (cancellable.isUnavailable == true) {
      return Future.value(null);
    }

    final Cancellable showing = Cancellable();

    showing.bindCancellable(cancellable);
    showing.onCancel.then((value) => route.navigator?.removeRoute(route));

    return push<T>(route).whenComplete(() => showing.cancel());
  }

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
