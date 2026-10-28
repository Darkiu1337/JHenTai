import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:photo_view/photo_view.dart';

class HorizontalDoubleColumnLayoutState {
  late PageController pageController;

  late int pageCount;

  late List<bool> isSpreadPage;
  Completer<void> isSpreadPageCompleter = Completer();

  /// One controller per page, created on demand. See
  /// [HorizontalPageLayoutState] for why controllers are not shared.
  final Map<int, PhotoViewController> photoViewControllers = <int, PhotoViewController>{};
  final Map<int, PhotoViewScaleStateController> photoViewScaleStateControllers = <int, PhotoViewScaleStateController>{};

  /// Returns the controller of [pageIndex], creating it with [initialScale] and
  /// [initialPosition] when it does not exist yet.
  PhotoViewController photoViewControllerOf(
    int pageIndex, {
    double? initialScale,
    Offset initialPosition = Offset.zero,
  }) =>
      photoViewControllers.putIfAbsent(
        pageIndex,
        () => PhotoViewController(initialScale: initialScale, initialPosition: initialPosition),
      );

  PhotoViewScaleStateController photoViewScaleStateControllerOf(int pageIndex) =>
      photoViewScaleStateControllers.putIfAbsent(pageIndex, () => PhotoViewScaleStateController());
}
