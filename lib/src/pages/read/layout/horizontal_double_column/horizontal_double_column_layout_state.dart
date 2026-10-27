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

  PhotoViewController photoViewControllerOf(int pageIndex) =>
      photoViewControllers.putIfAbsent(pageIndex, () => PhotoViewController());

  PhotoViewScaleStateController photoViewScaleStateControllerOf(int pageIndex) =>
      photoViewScaleStateControllers.putIfAbsent(pageIndex, () => PhotoViewScaleStateController());
}
