import 'dart:ui';

import 'package:cancellable/cancellable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dialog_ext.dart' as d;

extension BuildContextDialogCancellable on BuildContext {
  Future<T?> showCDialog<T>({
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
  }) =>
      d.showCDialog(
        builder: builder,
        context: this,
        cancellable: cancellable,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
        barrierLabel: barrierLabel,
        useSafeArea: useSafeArea,
        useRootNavigator: useRootNavigator,
        routeSettings: routeSettings,
        anchorPoint: anchorPoint,
        // traversalEdgeBehavior: traversalEdgeBehavior,
      );

  Future<T?> showCCupertinoDialog<T>({
    required WidgetBuilder builder,
    Cancellable? cancellable,
    String? barrierLabel,
    bool useRootNavigator = true,
    bool barrierDismissible = false,
    RouteSettings? routeSettings,
    Offset? anchorPoint,
  }) =>
      d.showCCupertinoDialog(
        context: this,
        builder: builder,
        cancellable: cancellable,
        barrierDismissible: barrierDismissible,
        barrierLabel: barrierLabel,
        useRootNavigator: useRootNavigator,
        routeSettings: routeSettings,
        anchorPoint: anchorPoint,
      );

  Future<T?> showCGeneralDialog<T extends Object?>({
    required RoutePageBuilder pageBuilder,
    Cancellable? cancellable,
    bool barrierDismissible = false,
    String? barrierLabel,
    Color barrierColor = const Color(0x80000000),
    Duration transitionDuration = const Duration(milliseconds: 200),
    RouteTransitionsBuilder? transitionBuilder,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
    Offset? anchorPoint,
  }) =>
      d.showCGeneralDialog(
        context: this,
        pageBuilder: pageBuilder,
        cancellable: cancellable,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
        barrierLabel: barrierLabel,
        useRootNavigator: useRootNavigator,
        routeSettings: routeSettings,
        anchorPoint: anchorPoint,
        transitionBuilder: transitionBuilder,
        transitionDuration: transitionDuration,
      );

  Future<T?> showCModalBottomSheet<T>({
    required WidgetBuilder builder,
    Cancellable? cancellable,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    Color? barrierColor,
    bool isScrollControlled = false,
    bool useRootNavigator = false,
    bool isDismissible = true,
    bool enableDrag = true,
    bool? showDragHandle,
    bool useSafeArea = false,
    RouteSettings? routeSettings,
    AnimationController? transitionAnimationController,
    Offset? anchorPoint,
  }) =>
      d.showCModalBottomSheet(
        context: this,
        builder: builder,
        cancellable: cancellable,
        backgroundColor: backgroundColor,
        elevation: elevation,
        shape: shape,
        clipBehavior: clipBehavior,
        constraints: constraints,
        barrierColor: barrierColor,
        isScrollControlled: isScrollControlled,
        useRootNavigator: useRootNavigator,
        isDismissible: isDismissible,
        enableDrag: enableDrag,
        showDragHandle: showDragHandle,
        useSafeArea: useSafeArea,
        routeSettings: routeSettings,
        transitionAnimationController: transitionAnimationController,
        anchorPoint: anchorPoint,
      );

  // PersistentBottomSheetController<T> showCBottomSheet<T>({
  //   required WidgetBuilder builder,
  //   Cancellable? cancellable,
  //   Color? backgroundColor,
  //   double? elevation,
  //   ShapeBorder? shape,
  //   Clip? clipBehavior,
  //   BoxConstraints? constraints,
  //   bool? enableDrag,
  //   AnimationController? transitionAnimationController,
  // }) =>
  //     d.showCBottomSheet(
  //       context: this,
  //       builder: builder,
  //       cancellable: cancellable,
  //       backgroundColor: backgroundColor,
  //       elevation: elevation,
  //       shape: shape,
  //       clipBehavior: clipBehavior,
  //       constraints: constraints,
  //       enableDrag: enableDrag,
  //       transitionAnimationController: transitionAnimationController,
  //     );

  void showCAboutDialog({
    Cancellable? cancellable,
    String? applicationName,
    String? applicationVersion,
    Widget? applicationIcon,
    String? applicationLegalese,
    List<Widget>? children,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
    Offset? anchorPoint,
  }) =>
      d.showCAboutDialog(
        context: this,
        cancellable: cancellable,
        applicationName: applicationName,
        applicationVersion: applicationVersion,
        applicationIcon: applicationIcon,
        applicationLegalese: applicationLegalese,
        children: children,
        useRootNavigator: useRootNavigator,
        routeSettings: routeSettings,
        anchorPoint: anchorPoint,
      );

  Future<T?> showCCupertinoModalPopup<T>({
    required WidgetBuilder builder,
    Cancellable? cancellable,
    ImageFilter? filter,
    Color barrierColor = kCupertinoModalBarrierColor,
    bool barrierDismissible = true,
    bool useRootNavigator = true,
    bool semanticsDismissible = false,
    RouteSettings? routeSettings,
    Offset? anchorPoint,
  }) =>
      d.showCCupertinoModalPopup(
        context: this,
        builder: builder,
        cancellable: cancellable,
        filter: filter,
        barrierColor: barrierColor,
        barrierDismissible: barrierDismissible,
        useRootNavigator: useRootNavigator,
        semanticsDismissible: semanticsDismissible,
        routeSettings: routeSettings,
        anchorPoint: anchorPoint,
      );

  void showCLicensePage({
    Cancellable? cancellable,
    String? applicationName,
    String? applicationVersion,
    Widget? applicationIcon,
    String? applicationLegalese,
    bool useRootNavigator = false,
  }) =>
      d.showCLicensePage(
        context: this,
        cancellable: cancellable,
        applicationName: applicationName,
        applicationVersion: applicationVersion,
        applicationIcon: applicationIcon,
        applicationLegalese: applicationLegalese,
        useRootNavigator: useRootNavigator,
      );
}
