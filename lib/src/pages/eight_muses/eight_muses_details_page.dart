import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/model/eight_muses_detail.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_history_model.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/network/eight_muses_request.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/gallery_download/gallery_download_service.dart';
import 'package:jhentai/src/service/history_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/read_progress_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/utils/eight_muses_parser.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_image.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Detail page of an external (8muses) gallery.
///
/// Kept separate from [DetailsPageLogic] on purpose: the E-H detail page owns
/// rating, favorites, torrents, archives, comments and thumbnails paging, none
/// of which exist on the external source.
class EightMusesDetailsPage extends StatefulWidget {
  const EightMusesDetailsPage({Key? key}) : super(key: key);

  @override
  State<EightMusesDetailsPage> createState() => _EightMusesDetailsPageState();
}

class _EightMusesDetailsPageState extends State<EightMusesDetailsPage> {
  late final Gallery gallery = Get.arguments as Gallery;

  EightMusesDetail? detail;
  LoadingState loadingState = LoadingState.idle;
  String? errorMessage;

  int get externalId => gallery.galleryUrl.externalId!;

  @override
  void initState() {
    super.initState();

    /// Set before the first build: calling setState from initState would run
    /// while the framework is still building the parent.
    loadingState = LoadingState.loading;
    _load();
  }

  Future<void> _load() async {
    if (loadingState != LoadingState.loading) {
      setState(() {
        loadingState = LoadingState.loading;
        errorMessage = null;
      });
    }

    try {
      final EightMusesDetail loaded = await eightMusesRequest.requestDetail(externalId);
      if (!mounted) {
        return;
      }

      setState(() {
        detail = loaded;
        loadingState = LoadingState.success;
      });

      historyService.record(
        GalleryHistoryModel(
          galleryUrl: gallery.galleryUrl,
          title: loaded.title,
          category: '8muses',
          coverUrl: EightMusesParser.coverUrl(externalId),
          pageCount: loaded.pageCount,
          rating: loaded.rating,
          language: 'EN',
          uploader: loaded.author,
          publishTime: loaded.publishTime,
          isExpunged: false,
          tags: loaded.genres,
        ),
      );
    } catch (e, s) {
      log.error('Load 8muses gallery #$externalId failed', e, s);
      if (!mounted) {
        return;
      }

      setState(() {
        loadingState = LoadingState.error;
        errorMessage = e.toString();
      });
    }
  }

  /// The site exposes every page through a deterministic url, so the reader
  /// receives a fully resolved image list and never parses E-H pages.
  Future<void> _openRead() async {
    final EightMusesDetail? loaded = detail;
    if (loaded == null) {
      return;
    }

    final List<GalleryImage> images = List<GalleryImage>.generate(
      loaded.pageCount,
      (int index) => GalleryImage(url: EightMusesParser.pageUrl(loaded.id, index + 1)),
    );

    final List<GalleryThumbnail> thumbnails = List<GalleryThumbnail>.generate(
      loaded.pageCount,
      (int index) => GalleryThumbnail(
        href: images[index].url,
        isLarge: true,
        thumbUrl: EightMusesParser.thumbUrl(loaded.id, index + 1),
      ),
    );

    final int recordIndex = await readProgressService.getReadProgress(gallery.galleryUrl.gid);

    toRoute(
      Routes.read,
      arguments: ReadPageInfo(
        mode: ReadMode.online,
        gid: gallery.galleryUrl.gid,
        token: gallery.galleryUrl.token,
        galleryTitle: loaded.title,
        galleryUrl: gallery.galleryUrl.url,
        initialIndex: recordIndex < loaded.pageCount ? recordIndex : 0,
        readProgressRecordStorageKey: gallery.galleryUrl.gid.toString(),
        pageCount: loaded.pageCount,
        images: images,
        thumbnails: thumbnails,
        useSuperResolution: false,
      ),
    );
  }

  Future<void> _download() async {
    final EightMusesDetail? loaded = detail;
    if (loaded == null) {
      return;
    }

    if (galleryDownloadService.containGallery(gallery.galleryUrl.gid)) {
      toast('downloaded'.tr);
      return;
    }

    galleryDownloadService.downloadGallery(
      GalleryDownloadRequest(
        gid: gallery.galleryUrl.gid,
        token: gallery.galleryUrl.token,
        title: loaded.title,
        category: '8muses',
        pageCount: loaded.pageCount,
        galleryUrl: gallery.galleryUrl.url,
        uploader: loaded.author,
        publishTime: loaded.publishTime,
        downloadOriginalImage: false,
        group: downloadSetting.defaultGalleryGroup.value ??
            (galleryDownloadService.allGroups.isNotEmpty ? galleryDownloadService.allGroups.first : 'Default'),
        tags: '',
        tagRefreshTime: DateTime.now().toString(),
      ),
    );

    toast('${'beginToDownload'.tr}: ${loaded.title}', isCenter: false);
  }

  Future<void> _openInBrowser() async {
    await launchUrlString(gallery.galleryUrl.url, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: gallery.galleryUrl.url));
    toast('copySuccess'.tr);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail?.title ?? gallery.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'openInBrowser'.tr,
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
          ),
          IconButton(
            tooltip: 'copyLink'.tr,
            icon: const Icon(Icons.link),
            onPressed: _copyLink,
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (loadingState == LoadingState.loading || loadingState == LoadingState.idle) {
      return Center(child: UIConfig.loadingAnimation(context));
    }

    if (loadingState == LoadingState.error || detail == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(errorMessage ?? 'getGalleryDetailFailed'.tr, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text('retry'.tr),
            ),
          ],
        ),
      );
    }

    final EightMusesDetail loaded = detail!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget cover = ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: EHImage(
                galleryImage: GalleryImage(url: EightMusesParser.coverUrl(loaded.id)),
                containerWidth: 200,
                containerHeight: 267,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(10),
              ),
            );

            final Widget info = _buildInfo(context, loaded);

            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: cover),
                  const SizedBox(height: 16),
                  info,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cover,
                const SizedBox(width: 16),
                Expanded(child: info),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildInfo(BuildContext context, EightMusesDetail loaded) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loaded.title, style: Theme.of(context).textTheme.titleLarge),
        if (loaded.author.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${'author'.tr}: ${loaded.author}', style: TextStyle(color: UIConfig.galleryCardTextColor(context))),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${loaded.pageCount} ${'pageCount'.tr}', style: TextStyle(color: UIConfig.galleryCardTextColor(context))),
        ),
        if (loaded.genres.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: loaded.genres.map((String genre) => Chip(label: Text(genre), visualDensity: VisualDensity.compact)).toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _openRead,
                icon: const Icon(Icons.menu_book),
                label: Text('read'.tr),
              ),
              OutlinedButton.icon(
                onPressed: _download,
                icon: const Icon(Icons.download),
                label: Text('download'.tr),
              ),
            ],
          ),
        ),
        if (loaded.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(loaded.description),
          ),
      ],
    );
  }
}
