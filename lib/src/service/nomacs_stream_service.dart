import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:path/path.dart' as p;

typedef NomacsImageResolver = Future<GalleryImage?> Function(int index);

NomacsStreamService nomacsStreamService = NomacsStreamService.instance;

/// Streams an online gallery into a temporary folder and lets nomacs browse it.
///
/// The current page is written before nomacs starts. The remaining pages are
/// downloaded strictly in order (forward first, then backward) so the folder
/// always contains a contiguous run of pages. nomacs watches the directory and
/// picks up new files automatically.
class NomacsStreamService {
  NomacsStreamService._();

  static final NomacsStreamService instance = NomacsStreamService._();

  final Map<String, _NomacsSession> _sessions = {};

  Future<void> openOnlineGallery({
    required ReadPageInfo readPageInfo,
    required int startIndex,
    required NomacsImageResolver resolveImage,
  }) async {
    final String? viewerPath = readSetting.thirdPartyViewerPath.value;
    if (viewerPath == null || viewerPath.isEmpty || !File(viewerPath).existsSync()) {
      toast('nomacsPathNotSet'.tr, isShort: false);
      return;
    }

    final int pageCount = readPageInfo.pageCount;
    if (startIndex < 0 || startIndex >= pageCount) {
      return;
    }

    final String galleryKey = _galleryKey(readPageInfo);
    final _NomacsSession? existing = _sessions[galleryKey];
    if (existing != null && existing.isRunning) {
      toast('nomacsAlreadyOpen'.tr);
      return;
    }

    await _cleanStale();

    final Directory dir = Directory(p.join(pathService.tempDir.path, 'jhentai_nomacs', '${galleryKey}_${DateTime.now().millisecondsSinceEpoch}'));
    await dir.create(recursive: true);

    final _NomacsSession session = _NomacsSession(
      galleryKey: galleryKey,
      dir: dir,
      pageCount: pageCount,
      startIndex: startIndex,
      resolveImage: resolveImage,
    );
    _sessions[galleryKey] = session;

    toast('nomacsPreparing'.tr);

    final File? first = await _ensurePage(session, startIndex);
    if (first == null) {
      _sessions.remove(galleryKey);
      await _deleteDirectory(dir);
      toast('nomacsPrepareFailed'.tr, isShort: false);
      return;
    }

    Process process;
    try {
      process = await Process.start(
        viewerPath,
        ['--private', '--new-instance', first.path],
        workingDirectory: p.dirname(viewerPath),
        runInShell: false,
      );
    } catch (e) {
      log.error('Start nomacs failed', e);
      _sessions.remove(galleryKey);
      await _deleteDirectory(dir);
      toast('nomacsStartFailed'.tr, isShort: false);
      return;
    }

    session.process = process;
    session.isRunning = true;

    unawaited(process.exitCode.then((_) async {
      session.cancelled = true;
      await session.done.future;
      session.isRunning = false;
      if (identical(_sessions[galleryKey], session)) {
        _sessions.remove(galleryKey);
      }
      await _deleteDirectory(dir);
    }));

    unawaited(_downloadRemaining(session));
  }

  /// Opens a local file or folder directly (downloaded/archive/local modes).
  Future<void> openLocalPath(String path) async {
    final String? viewerPath = readSetting.thirdPartyViewerPath.value;
    if (viewerPath == null || viewerPath.isEmpty || !File(viewerPath).existsSync()) {
      toast('nomacsPathNotSet'.tr, isShort: false);
      return;
    }

    try {
      await Process.start(
        viewerPath,
        ['--private', '--new-instance', path],
        workingDirectory: p.dirname(viewerPath),
        runInShell: false,
      );
    } catch (e) {
      log.error('Start nomacs failed', e);
      toast('nomacsStartFailed'.tr, isShort: false);
    }
  }

  Future<void> _downloadRemaining(_NomacsSession session) async {
    try {
      /// Forward first. This keeps the pages the user is about to read ready.
      for (int i = session.startIndex + 1; i < session.pageCount; i++) {
        if (session.cancelled) {
          return;
        }
        if (await _ensurePage(session, i) == null) {
          log.warning('Nomacs stream stopped at page ${i + 1} to keep the folder contiguous');
          toast('nomacsPageFailed'.tr, isShort: false);
          return;
        }
      }

      /// Then the pages before the starting point.
      for (int i = session.startIndex - 1; i >= 0; i--) {
        if (session.cancelled) {
          return;
        }
        if (await _ensurePage(session, i) == null) {
          log.warning('Nomacs stream stopped at page ${i + 1} to keep the folder contiguous');
          toast('nomacsPageFailed'.tr, isShort: false);
          return;
        }
      }
    } finally {
      if (!session.done.isCompleted) {
        session.done.complete();
      }
    }
  }

  Future<File?> _ensurePage(_NomacsSession session, int index) async {
    final String base = (index + 1).toString().padLeft(5, '0');

    final File? existing = _findExisting(session.dir, base);
    if (existing != null) {
      return existing;
    }

    final GalleryImage? image = await session.resolveImage(index);
    if (image == null) {
      return null;
    }

    final String ext = _extensionOf(image.url);
    final File target = File(p.join(session.dir.path, '$base$ext'));
    final File part = File('${target.path}.part');
    final String url = _normalizeUrl(image.url);

    try {
      /// The reader has usually cached the image already. Using that cache
      /// avoids an extra image request (and an extra view against the image
      /// limit). If it is not cached, getNetworkImageData fetches it.
      Uint8List? data;
      try {
        data = await getNetworkImageData(url, useCache: true);
      } catch (e) {
        log.warning('Read cached image for nomacs failed, falling back to dio', e);
      }

      if (data != null && data.isNotEmpty) {
        await part.writeAsBytes(data, flush: true);
        if (await _looksLikeHtml(part)) {
          clearDiskCachedImage(url);
          await part.delete();
          data = null;
        }
      }

      if (data == null || data.isEmpty) {
        await ehRequest.download(url: url, path: part.path);
        if (!await part.exists() || await part.length() == 0) {
          return null;
        }

        /// e-hentai/exhentai return an HTML page (with HTTP 200) when the
        /// image limit is reached. Do not hand that to nomacs as an image.
        if (await _looksLikeHtml(part)) {
          clearDiskCachedImage(url);
          await part.delete();
          return null;
        }
      }

      await part.rename(target.path);
      return target;
    } catch (e) {
      log.error('Download page ${index + 1} for nomacs failed', e);
      try {
        if (await part.exists()) {
          await part.delete();
        }
      } catch (_) {}
      return null;
    }
  }

  File? _findExisting(Directory dir, String base) {
    if (!dir.existsSync()) {
      return null;
    }
    for (final FileSystemEntity entity in dir.listSync()) {
      if (entity is! File) {
        continue;
      }
      final String name = p.basename(entity.path);
      if (name.startsWith('$base.') && !name.endsWith('.part') && entity.lengthSync() > 0) {
        return entity;
      }
    }
    return null;
  }

  Future<bool> _looksLikeHtml(File file) async {
    final RandomAccessFile raf = await file.open();
    try {
      final Uint8List bytes = await raf.read(64);
      if (bytes.isEmpty) {
        return false;
      }
      final String head = String.fromCharCodes(bytes).toLowerCase();
      return head.contains('<html') || head.contains('<!doctype');
    } finally {
      await raf.close();
    }
  }

  String _extensionOf(String url) {
    String ext = p.extension(Uri.parse(url).path).toLowerCase();
    const Set<String> allowed = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.avif'};
    return allowed.contains(ext) ? ext : '.jpg';
  }

  /// Matches [EHImage]'s URL rewrite so we hit the same disk cache entry.
  String _normalizeUrl(String url) {
    Uri uri = Uri.parse(url);
    if (uri.host == 's.exhentai.org') {
      return uri.replace(host: 'ehgt.org').toString();
    }
    return url;
  }

  String _galleryKey(ReadPageInfo info) {
    final String raw = info.gid != null ? '${info.gid}_${info.token ?? ''}' : info.galleryTitle;
    final String safe = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'gallery' : safe;
  }

  Future<void> _deleteDirectory(Directory dir) async {
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      log.warning('Delete nomacs temp folder failed', e);
    }
  }

  /// Removes folders left behind by a crash or by closing JHenTai before
  /// nomacs. Only touches folders older than a day.
  Future<void> _cleanStale() async {
    final Directory root = Directory(p.join(pathService.tempDir.path, 'jhentai_nomacs'));
    if (!await root.exists()) {
      return;
    }
    final DateTime cutoff = DateTime.now().subtract(const Duration(hours: 24));
    await for (final FileSystemEntity entity in root.list()) {
      try {
        if (entity is Directory && (await entity.stat()).modified.isBefore(cutoff)) {
          await entity.delete(recursive: true);
        }
      } catch (_) {}
    }
  }
}

class _NomacsSession {
  _NomacsSession({
    required this.galleryKey,
    required this.dir,
    required this.pageCount,
    required this.startIndex,
    required this.resolveImage,
  });

  final String galleryKey;
  final Directory dir;
  final int pageCount;
  final int startIndex;
  final NomacsImageResolver resolveImage;

  final Completer<void> done = Completer<void>();

  Process? process;
  bool isRunning = false;
  bool cancelled = false;
}
