import 'package:flutter/widgets.dart';
import 'package:photo_view/photo_view.dart';

class HorizontalPageLayoutState {
  /// One controller per page, created on demand.
  ///
  /// Sharing a single controller between pages is not safe: each PhotoView
  /// clamps the controller position against its own content size, so cached
  /// neighbour pages with different aspect ratios would fight over the pan
  /// offset. Instead every page gets the zoom of the reading session and its
  /// own top aligned position when it is created.
  final Map<int, PhotoViewController> photoViewControllers = <int, PhotoViewController>{};
  final Map<int, PhotoViewScaleStateController> photoViewScaleStateControllers = <int, PhotoViewScaleStateController>{};

  /// Vertical scroll position used by single-page fit-width mode.
  final Map<int, ScrollController> scrollControllers = <int, ScrollController>{};

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

  ScrollController scrollControllerOf(int pageIndex) => scrollControllers.putIfAbsent(pageIndex, () => ScrollController());
}
