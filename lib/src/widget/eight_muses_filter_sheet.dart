import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/eight_muses_search.dart';
import 'package:jhentai/src/service/eight_muses_catalog_service.dart';
import 'package:jhentai/src/setting/style_setting.dart';

/// Opens the filter panel: a dialog on desktop layouts and a bottom sheet on
/// mobile/tablet. Returns the edited config, or null when dismissed.
Future<EightMusesSearchConfig?> showEightMusesFilterSheet({
  required BuildContext context,
  required EightMusesSearchConfig config,
}) {
  if (styleSetting.isInDesktopLayout) {
    return Get.dialog<EightMusesSearchConfig>(
      Dialog(
        child: SizedBox(
          width: 560,
          height: 640,
          child: EightMusesFilterSheet(config: config),
        ),
      ),
    );
  }

  return showModalBottomSheet<EightMusesSearchConfig>(
    context: context,
    isScrollControlled: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: EightMusesFilterSheet(config: config),
    ),
  );
}

class EightMusesFilterSheet extends StatefulWidget {
  final EightMusesSearchConfig config;

  const EightMusesFilterSheet({
    Key? key,
    required this.config,
  }) : super(key: key);

  @override
  State<EightMusesFilterSheet> createState() => _EightMusesFilterSheetState();
}

class _EightMusesFilterSheetState extends State<EightMusesFilterSheet> {
  late final EightMusesSearchConfig draft = widget.config.copy();
  final TextEditingController tagFilterController = TextEditingController();

  String query = '';

  @override
  void initState() {
    super.initState();

    eightMusesCatalogService.ensureTags().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    tagFilterController.dispose();
    super.dispose();
  }

  List<EightMusesTag> get filteredTags {
    final String normalized = query.trim().toLowerCase();
    final List<EightMusesTag> tags = eightMusesCatalogService.tags;

    if (normalized.isEmpty) {
      return tags;
    }

    return tags
        .where((EightMusesTag tag) => tag.label.toLowerCase().contains(normalized) || tag.slug.contains(normalized))
        .toList();
  }

  void toggleInclude(EightMusesTag tag) {
    if (draft.includeTags.contains(tag)) {
      draft.includeTags.remove(tag);
    } else {
      draft.excludeTags.remove(tag);
      draft.includeTags.add(tag);
    }
  }

  void toggleExclude(EightMusesTag tag) {
    if (draft.excludeTags.contains(tag)) {
      draft.excludeTags.remove(tag);
    } else {
      draft.includeTags.remove(tag);
      draft.excludeTags.add(tag);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: tagFilterController,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: 'tagSearchHint'.tr,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (String value) => setState(() => query = value),
          ),
        ),
        Expanded(child: _buildTagList(context)),
        _buildOptions(context),
        if (draft.hasTags)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'tagModeHint'.tr,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        _buildActions(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          Text('filters'.tr, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTagList(BuildContext context) {
    if (eightMusesCatalogService.tags.isEmpty) {
      if (eightMusesCatalogService.loadingTags) {
        return const Center(child: CircularProgressIndicator());
      }

      return Center(
        child: TextButton.icon(
          onPressed: () async {
            await eightMusesCatalogService.ensureTags(force: true);
            if (mounted) {
              setState(() {});
            }
          },
          icon: const Icon(Icons.refresh),
          label: Text('retry'.tr),
        ),
      );
    }

    final List<EightMusesTag> tags = filteredTags;

    if (tags.isEmpty) {
      return Center(child: Text('noData'.tr));
    }

    return ListView.builder(
      itemCount: tags.length,
      itemBuilder: (BuildContext context, int index) {
        final EightMusesTag tag = tags[index];
        final bool included = draft.includeTags.contains(tag);
        final bool excluded = draft.excludeTags.contains(tag);

        return ListTile(
          dense: true,
          onTap: () => setState(() => toggleInclude(tag)),
          title: Text(tag.label),
          subtitle: tag.count > 0 ? Text(tag.count.toString()) : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'includeTag'.tr,
                icon: Icon(
                  included ? Icons.check_circle : Icons.check_circle_outline,
                  color: included ? Theme.of(context).colorScheme.primary : null,
                ),
                onPressed: () => setState(() => toggleInclude(tag)),
              ),
              IconButton(
                tooltip: 'excludeTag'.tr,
                icon: Icon(
                  excluded ? Icons.remove_circle : Icons.remove_circle_outline,
                  color: excluded ? Theme.of(context).colorScheme.error : null,
                ),
                onPressed: () => setState(() => toggleExclude(tag)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptions(BuildContext context) {
    final bool tagMode = draft.hasTags;

    return IgnorePointer(
      ignoring: tagMode,
      child: Opacity(
        opacity: tagMode ? 0.5 : 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            children: [
              _buildDropdownRow<EightMusesContentType>(
                context,
                'contentType'.tr,
                draft.contentType,
                EightMusesContentType.values,
                (EightMusesContentType value) => value == EightMusesContentType.all ? 'anyType'.tr : value.label,
                (EightMusesContentType value) => setState(() => draft.contentType = value),
              ),
              _buildDropdownRow<EightMusesLanguage>(
                context,
                'language'.tr,
                draft.language,
                EightMusesLanguage.values,
                (EightMusesLanguage value) => value == EightMusesLanguage.all ? 'anyLanguage'.tr : value.label,
                (EightMusesLanguage value) => setState(() => draft.language = value),
              ),
              _buildDropdownRow<EightMusesSort>(
                context,
                'sortBy'.tr,
                draft.sort,
                EightMusesSort.values,
                (EightMusesSort value) => value.labelKey.tr,
                (EightMusesSort value) => setState(() => draft.sort = value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownRow<T>(
    BuildContext context,
    String label,
    T value,
    List<T> values,
    String Function(T value) labelOf,
    ValueChanged<T> onChanged,
  ) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        DropdownButton<T>(
          value: value,
          items: values
              .map(
                (T item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(labelOf(item)),
                ),
              )
              .toList(),
          onChanged: (T? newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          TextButton(
            onPressed: () => setState(draft.reset),
            child: Text('clearFilters'.tr),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(draft),
            child: Text('showResults'.tr),
          ),
        ],
      ),
    );
  }
}
