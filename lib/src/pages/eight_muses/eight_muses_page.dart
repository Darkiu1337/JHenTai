import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/model/eight_muses_search.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/pages/eight_muses/eight_muses_logic.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/eight_muses_card.dart';
import 'package:jhentai/src/widget/eight_muses_filter_sheet.dart';
import 'package:jhentai/src/widget/eight_muses_mark.dart';
import 'package:jhentai/src/widget/eight_muses_search_bar.dart';
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
        title: Row(
          children: [
            const EightMusesMark(size: 22),
            const SizedBox(width: 10),
            Text('eightMuses'.tr),
          ],
        ),
      ),
      body: Column(
        children: [
          EightMusesSearchBar(
            logic: logic,
            onOpenFilters: () => _openFilters(context, logic),
          ),
          Expanded(
            child: GetBuilder<EightMusesLogic>(
              id: logic.bodyId,
              builder: (_) => logic.state.showSuggestions ? _buildSuggestions(context, logic) : _buildResults(context, logic),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilters(BuildContext context, EightMusesLogic logic) async {
    final EightMusesSearchConfig? config = await showEightMusesFilterSheet(
      context: context,
      config: logic.state.config,
    );

    if (config != null) {
      await logic.applyConfig(config);
    }
  }

  Widget _buildSuggestions(BuildContext context, EightMusesLogic logic) {
    final List<String> recent = logic.recentSearches;
    final List<EightMusesTag> popular = logic.popularTags;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text('search'.tr, style: Theme.of(context).textTheme.titleSmall)),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: logic.hideSuggestions,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isNotEmpty) ...[
          _sectionTitle(context, 'recentSearches'.tr),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final String keyword in recent)
                ActionChip(
                  label: Text(keyword),
                  onPressed: () => logic.submitKeyword(keyword),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        _sectionTitle(context, 'popularTags'.tr),
        if (logic.loadingTags && popular.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final EightMusesTag tag in popular)
                ActionChip(
                  label: Text(tag.label),
                  onPressed: () => logic.toggleIncludeTag(tag),
                ),
            ],
          ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  Widget _buildResults(BuildContext context, EightMusesLogic logic) {
    final EightMusesSearchConfig config = logic.state.config;

    return RefreshIndicator(
      onRefresh: logic.onRefresh,
      child: CustomScrollView(
        controller: logic.state.scrollController,
        slivers: [
          if (config.isTagMode) SliverToBoxAdapter(child: _buildFilterHint(context, logic)),
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
    );
  }

  Widget _buildFilterHint(BuildContext context, EightMusesLogic logic) {
    final EightMusesSearchConfig config = logic.state.config;
    final String tag = config.includeTags.first.label;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${'filteringWithin'.tr} "$tag" — ${logic.state.galleries.length}/${logic.state.scannedCards}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: UIConfig.galleryCardTextColor(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, EightMusesLogic logic) {
    final LoadingState state = logic.state.loadingState;

    if (state == LoadingState.loading && logic.state.galleries.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state == LoadingState.error) {
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

    if (state == LoadingState.noData) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('noData'.tr)),
      );
    }

    if (state == LoadingState.noMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('noMore'.tr)),
      );
    }

    /// A local filter can consume a whole batch of pages; offer a manual
    /// "keep scanning" when nothing survived it.
    if (logic.state.galleries.isEmpty && logic.state.config.isSearching) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: TextButton.icon(
            onPressed: logic.loadMore,
            icon: const Icon(Icons.expand_more),
            label: Text('loadMore'.tr),
          ),
        ),
      );
    }

    return const SizedBox(height: 20);
  }
}
