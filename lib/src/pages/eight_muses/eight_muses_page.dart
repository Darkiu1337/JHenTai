import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/network/eight_muses_request.dart';
import 'package:jhentai/src/pages/eight_muses/eight_muses_logic.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/eight_muses_card.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

/// Browse/search page of the external 8muses source.
class EightMusesPage extends StatelessWidget {
  const EightMusesPage({Key? key}) : super(key: key);

  EightMusesLogic get logic {
    if (Get.isRegistered<EightMusesLogic>()) {
      return Get.find<EightMusesLogic>();
    }
    return Get.put<EightMusesLogic>(EightMusesLogic(), permanent: true);
  }

  @override
  Widget build(BuildContext context) {
    final EightMusesLogic logic = this.logic;

    return Scaffold(
      appBar: AppBar(
        title: Text('eightMuses'.tr),
        actions: [
          if (logic.state.keyword.isNotEmpty)
            IconButton(
              tooltip: 'cancel'.tr,
              icon: const Icon(Icons.close),
              onPressed: logic.clearSearch,
            ),
          IconButton(
            tooltip: 'search'.tr,
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context, logic),
          ),
        ],
      ),
      body: GetBuilder<EightMusesLogic>(
        id: logic.bodyId,
        builder: (EightMusesLogic logic) => RefreshIndicator(
          onRefresh: logic.onRefresh,
          child: CustomScrollView(
            controller: logic.state.scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildListingChips(context, logic)),
              if (logic.state.keyword.isNotEmpty) SliverToBoxAdapter(child: _buildSearchInfo(context, logic)),
              if (logic.state.galleries.isEmpty && logic.state.loadingState == LoadingState.loading)
                const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator())),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.58,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      if (index == logic.state.galleries.length - 1 && logic.state.loadingState == LoadingState.idle) {
                        SchedulerBinding.instance.addPostFrameCallback((_) => logic.loadMore());
                      }

                      final Gallery gallery = logic.state.galleries[index];
                      return EightMusesCard(
                        gallery: gallery,
                        onTap: () => toRoute(Routes.eightMusesDetails, arguments: gallery),
                      );
                    },
                    childCount: logic.state.galleries.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildFooter(context, logic)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListingChips(BuildContext context, EightMusesLogic logic) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          _buildChip(context, logic, EightMusesListing.popular, 'popular'.tr),
          _buildChip(context, logic, EightMusesListing.newest, 'newest'.tr),
          _buildChip(context, logic, EightMusesListing.browse, 'browseAll'.tr),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, EightMusesLogic logic, EightMusesListing listing, String label) {
    final bool selected = logic.state.keyword.isEmpty && logic.state.listing == listing;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => logic.changeListing(listing),
    );
  }

  Widget _buildSearchInfo(BuildContext context, EightMusesLogic logic) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: UIConfig.galleryCardTextColor(context)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              logic.state.keyword,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: UIConfig.galleryCardTextColor(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, EightMusesLogic logic) {
    if (logic.state.loadingState == LoadingState.loading && logic.state.galleries.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (logic.state.loadingState == LoadingState.error) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: TextButton.icon(
            onPressed: logic.loadMore,
            icon: const Icon(Icons.refresh),
            label: Text('retry'.tr),
          ),
        ),
      );
    }

    if (logic.state.loadingState == LoadingState.noData) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('noData'.tr)),
      );
    }

    if (logic.state.loadingState == LoadingState.noMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('noMore'.tr)),
      );
    }

    return const SizedBox(height: 20);
  }

  Future<void> _showSearchDialog(BuildContext context, EightMusesLogic logic) async {
    final TextEditingController controller = TextEditingController(text: logic.state.keyword);

    final String? keyword = await Get.dialog<String>(
      AlertDialog(
        title: Text('search'.tr),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'Keyword'),
          onSubmitted: (String value) => Get.back(result: value),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
          TextButton(onPressed: () => Get.back(result: controller.text), child: Text('search'.tr)),
        ],
      ),
    );

    controller.dispose();

    if (keyword != null && keyword.trim().isNotEmpty) {
      await logic.search(keyword);
    }
  }
}
