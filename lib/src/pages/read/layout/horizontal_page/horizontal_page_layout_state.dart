import 'package:flutter/widgets.dart';
import 'package:photo_view/photo_view.dart';

class HorizontalPageLayoutState {
  /// One controller per page, created on demand.
  ///
  /// Sharing a single controller between pages is not safe: each PhotoView
  /// clamps the controller position against its own content size, so cached
  /// neighbour pages with different aspect ratios would fight over the pan
  /// offset. Instead the logic copies the scale from the previous page and
  /// applies the top-aligned position to the new page's controller.
  final Map<int, PhotoViewController> photoViewControllers = <int, PhotoViewController>{};
  final Map<int, PhotoViewScaleStateController> photoViewScaleStateControllers = <int, PhotoViewScaleStateController>{};

  /// Vertical scroll position used by single-page fit-width mode.
  final Map<int, ScrollController> scrollControllers = <int, ScrollController>{};

  PhotoViewController photoViewControllerOf(int pageIndex) =>
      photoViewControllers.putIfAbsent(pageIndex, () => PhotoViewController());

  PhotoViewScaleStateController photoViewScaleStateControllerOf(int pageIndex) =>
      photoViewScaleStateControllers.putIfAbsent(pageIndex, () => PhotoViewScaleStateController());

  ScrollController scrollControllerOf(int pageIndex) => scrollControllers.putIfAbsent(pageIndex, () => ScrollController());
}
