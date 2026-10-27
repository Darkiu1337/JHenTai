import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:photo_view/photo_view.dart';

import '../base/base_layout_logic.dart';
import 'horizontal_page_layout_state.dart';

class HorizontalPageLayoutLogic extends BaseLayoutLogic {
  HorizontalPageLayoutState state = HorizontalPageLayoutState();

  late PageController pageController;

  int _lastPage = -1;

  int get currentPageIndex {
    final int fallback = readPageState.readPageInfo.initialIndex;
    final int index = pageController.hasClients && pageController.page != null ? pageController.page!.round() : fallback;
    return index.clamp(0, readPageState.readPageInfo.pageCount - 1).toInt();
  }

  @override
  PhotoViewControllerBase? get activePhotoViewController => state.photoViewControllerOf(currentPageIndex);

  @override
  Size? get activeContentSize => readPageState.imageContainerSizes[currentPageIndex];

  @override
  void onInit() {
    super.onInit();

    pageController = PageController(initialPage: readPageState.readPageInfo.currentImageIndex);

    /// record reading progress and sync thumbnails list index
    pageController.addListener(_readProgressListener);
  }

  @override
  void toLeft() {
    if (readPageLogic.isInRight2LeftDirection) {
      toNext();
    } else {
      toPrev();
    }
  }

  @override
  void toRight() {
    if (readPageLogic.isInRight2LeftDirection) {
      toPrev();
    } else {
      toNext();
    }
  }

  @override
  void toPrev() {
    int targetIndex = (pageController.page! - 1).toInt();
    toImageIndex(max(targetIndex, 0));
  }

  @override
  void toNext() {
    int targetIndex = (pageController.page! + 1).toInt();
    toImageIndex(min(targetIndex, readPageState.readPageInfo.pageCount - 1));
  }

  @override
  void jump2ImageIndex(int pageIndex) {
    pageController.jumpToPage(pageIndex);
    super.jump2ImageIndex(pageIndex);
  }

  @override
  void scroll2ImageIndex(int pageIndex, [Duration? duration]) {
    pageController.animateToPage(
      pageIndex,
      duration: duration ?? const Duration(milliseconds: 200),
      curve: Curves.ease,
    );
    super.scroll2ImageIndex(pageIndex, duration);
  }

  @override
  void enterAutoMode() {
    _enterAutoModeByTurnPage();
  }

  void _enterAutoModeByTurnPage() {
    readPageLogic.toggleMenu();

    autoModeTimer = Timer.periodic(
      Duration(milliseconds: (readSetting.autoModeInterval.value * 1000).toInt()),
      (_) {
        /// changed read setting
        if (!readPageLogic.isInSinglePageReadDirection) {
          Get.engine.addPostFrameCallback((_) {
            readPageLogic.closeAutoMode();
          });
          autoModeTimer?.cancel();
          return;
        }

        /// stop when at last
        if (readPageState.readPageInfo.currentImageIndex == readPageState.readPageInfo.pageCount - 1) {
          Get.engine.addPostFrameCallback((_) {
            readPageLogic.closeAutoMode();
          });
          autoModeTimer?.cancel();
          return;
        }

        toNext();
      },
    );
  }

  void _readProgressListener() {
    if (!pageController.hasClients || pageController.page == null) {
      return;
    }

    int currentPage = pageController.page!.toInt();
    readPageLogic.recordReadProgress(currentPage);
    readPageLogic.syncThumbnails(currentPage);

    if (currentPage == _lastPage) {
      return;
    }

    final int? previousPage = _lastPage >= 0 ? _lastPage : null;
    _lastPage = currentPage;
    _copyZoomAndAlignToTop(previousPage, currentPage);
  }

  /// Keeps the zoom level of the page the reader is leaving and starts the new
  /// page at its top edge.
  void _copyZoomAndAlignToTop(int? previousPage, int currentPage) {
    final double scale = previousPage == null ? 1.0 : (state.photoViewControllerOf(previousPage).scale ?? 1.0);
    final Size? contentSize = readPageState.imageContainerSizes[currentPage];
    final Offset position = scale > 1.001 ? computeTopAlignedPosition(scale, contentSize) : Offset.zero;

    final PhotoViewController controller = state.photoViewControllerOf(currentPage);
    final PhotoViewScaleStateController scaleStateController = state.photoViewScaleStateControllerOf(currentPage);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lastPage != currentPage) {
        return;
      }
      controller.updateMultiple(scale: scale, position: position);
      scaleStateController.setInvisibly(scale > 1.001 ? PhotoViewScaleState.zoomedIn : PhotoViewScaleState.initial);

      // Fit-width pages scroll vertically inside the page; start the new page
      // at the top of the image too.
      if (readPageLogic.isInFitWidthReadDirection) {
        final ScrollController scrollController = state.scrollControllerOf(currentPage);
        if (scrollController.hasClients) {
          scrollController.jumpTo(0);
        }
      }
    });
  }
}
