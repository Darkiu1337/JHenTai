import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:jhentai/src/service/anime4k_restore_service.dart';
import 'package:jhentai/src/service/log.dart';

/// Displays [source] immediately and swaps it for the Anime4K Restore L result
/// once the shader chain finishes. While processing (or if the chain fails) the
/// original image stays visible.
class Anime4KRestoredImage extends StatefulWidget {
  final ui.Image source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double scale;

  const Anime4KRestoredImage({
    Key? key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.scale = 1.0,
  }) : super(key: key);

  @override
  State<Anime4KRestoredImage> createState() => _Anime4KRestoredImageState();
}

class _Anime4KRestoredImageState extends State<Anime4KRestoredImage> {
  ui.Image? _restored;
  bool _started = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(Anime4KRestoredImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _restored?.dispose();
      _restored = null;
      _started = false;
      _start();
    }
  }

  Future<void> _start() async {
    if (_started) {
      return;
    }
    _started = true;

    final int generation = ++_generation;
    final ui.Image source = widget.source.clone();
    log.info('Anime4K: processing ${source.width}x${source.height} image');
    final ui.Image? restored = await anime4KRestoreService.restore(source);
    source.dispose();

    if (!mounted || generation != _generation) {
      restored?.dispose();
      return;
    }

    if (restored != null) {
      setState(() => _restored = restored);
    }
  }

  @override
  void dispose() {
    _restored?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawImage(
      image: _restored ?? widget.source,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      scale: widget.scale,
      filterQuality: FilterQuality.medium,
    );
  }
}
