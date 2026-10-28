import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/network/eight_muses_request.dart';
import 'package:jhentai/src/pages/eight_muses/eight_muses_state.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/snack_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

/// Lists https://8muses.io galleries (popular / newest / browse / search).
///
/// Pagination is page-number based (`/browse/page/2`), so the page is tracked
/// locally instead of the E-H prev/next gid cursors.
class EightMusesLogic extends GetxController {
  final String bodyId = 'eightMusesBodyId';

  final EightMusesState state = EightMusesState();

  @override
  void onInit() {
    super.onInit();
    loadMore();
  }

  @override
  void onClose() {
    state.scrollController.dispose();
    super.onClose();
  }

  Future<void> onRefresh() async {
    state.nextPage = 1;
    state.galleries.clear();
    state.loadingState = LoadingState.idle;
    update([bodyId]);

    await loadMore();
  }

  Future<void> changeListing(EightMusesListing listing) async {
    if (state.listing == listing && state.keyword.isEmpty) {
      return;
    }

    state.listing = listing;
    state.keyword = '';
    await onRefresh();
  }

  Future<void> search(String keyword) async {
    final String normalized = keyword.trim();
    if (normalized.isEmpty) {
      return;
    }

    state.keyword = normalized;
    await onRefresh();
  }

  Future<void> clearSearch() async {
    if (state.keyword.isEmpty) {
      return;
    }

    state.keyword = '';
    await onRefresh();
  }

  Future<void> loadMore() async {
    if (state.loadingState == LoadingState.loading || state.loadingState == LoadingState.noMore) {
      return;
    }

    state.loadingState = LoadingState.loading;
    update([bodyId]);

    try {
      final List<Gallery> galleries = state.keyword.isEmpty
          ? await eightMusesRequest.requestListing(listing: state.listing, page: state.nextPage)
          : await eightMusesRequest.search(keyword: state.keyword, page: state.nextPage);

      if (galleries.isEmpty) {
        state.loadingState = state.galleries.isEmpty ? LoadingState.noData : LoadingState.noMore;
      } else {
        state.galleries.addAll(galleries);
        state.nextPage += 1;
        state.loadingState = LoadingState.idle;
      }
    } on DioException catch (e) {
      log.error('Load 8muses page failed', e.error);
      state.loadingState = LoadingState.error;
      snack('refreshGalleryFailed'.tr, e.message ?? '', isShort: true);
    } catch (e, s) {
      log.error('Load 8muses page failed', e, s);
      state.loadingState = LoadingState.error;
    }

    update([bodyId]);
  }
}
