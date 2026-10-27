import 'dart:async';
import 'dart:ui' as ui;

import 'package:jhentai/src/service/log.dart';

/// Runs the Anime4K v4.0 Restore CNN (L) as a chain of Flutter fragment shaders.
///
/// The mpv shader is split into nine passes. Every pass keeps the source
/// resolution and only touches the pixels in a 3x3 neighbourhood, so the passes
/// can be chained through offscreen images:
///
///   0, 1  : 3-channel input -> 4-channel feature maps
///   2..7  : 16-channel feature maps (two RGBA textures each)
///   8     : final 3-channel restore, added back to the original image
///
/// Intermediate feature maps contain negative values, so they are rendered to
/// `rgbaFloat32` snapshots. Quantising them to RGBA8 would destroy the
/// positive/negative split the network relies on.
class Anime4KRestoreService {
  Anime4KRestoreService._();

  static const List<String> _shaderAssets = <String>[
    'assets/shaders/anime4k/restore_L_0.frag',
    'assets/shaders/anime4k/restore_L_1.frag',
    'assets/shaders/anime4k/restore_L_2.frag',
    'assets/shaders/anime4k/restore_L_3.frag',
    'assets/shaders/anime4k/restore_L_4.frag',
    'assets/shaders/anime4k/restore_L_5.frag',
    'assets/shaders/anime4k/restore_L_6.frag',
    'assets/shaders/anime4k/restore_L_7.frag',
    'assets/shaders/anime4k/restore_L_8.frag',
  ];

  Future<List<ui.FragmentProgram>>? _programsFuture;
  Future<void> _queue = Future<void>.value();

  Future<List<ui.FragmentProgram>> _ensurePrograms() {
    return _programsFuture ??= () async {
      final List<ui.FragmentProgram> programs = <ui.FragmentProgram>[];
      for (final String asset in _shaderAssets) {
        programs.add(await ui.FragmentProgram.fromAsset(asset));
      }
      return programs;
    }();
  }

  /// Returns a restored copy of [source], or `null` when the shader pipeline
  /// cannot run on this device.
  ///
  /// Calls are serialised: each chain keeps eight float images alive until the
  /// final read-back, so running several at once would multiply GPU memory.
  Future<ui.Image?> restore(ui.Image source) {
    final Future<void> previous = _queue;
    final Completer<ui.Image?> completer = Completer<ui.Image?>();

    _queue = () async {
      await previous;
      try {
        completer.complete(await _restore(source));
      } catch (e, s) {
        completer.completeError(e, s);
      }
    }();

    return completer.future;
  }

  Future<ui.Image?> _restore(ui.Image source) async {
    final int width = source.width;
    final int height = source.height;
    if (width <= 0 || height <= 0) {
      return null;
    }

    final List<ui.Image> intermediates = <ui.Image>[];
    ui.Image? restored;
    final Stopwatch stopwatch = Stopwatch()..start();

    try {
      final List<ui.FragmentProgram> programs = await _ensurePrograms();

      /// Passes 0 and 1 both consume the original image.
      final ui.Image conv0 = _runPass(programs[0], width, height, <ui.Image>[source], floatOutput: true);
      final ui.Image conv1 = _runPass(programs[1], width, height, <ui.Image>[source], floatOutput: true);
      intermediates.addAll(<ui.Image>[conv0, conv1]);

      final ui.Image conv1a = _runPass(programs[2], width, height, <ui.Image>[conv0, conv1], floatOutput: true);
      final ui.Image conv1b = _runPass(programs[3], width, height, <ui.Image>[conv0, conv1], floatOutput: true);
      intermediates.addAll(<ui.Image>[conv1a, conv1b]);

      final ui.Image conv2a = _runPass(programs[4], width, height, <ui.Image>[conv1a, conv1b], floatOutput: true);
      final ui.Image conv2b = _runPass(programs[5], width, height, <ui.Image>[conv1a, conv1b], floatOutput: true);
      intermediates.addAll(<ui.Image>[conv2a, conv2b]);

      final ui.Image conv3a = _runPass(programs[6], width, height, <ui.Image>[conv2a, conv2b], floatOutput: true);
      final ui.Image conv3b = _runPass(programs[7], width, height, <ui.Image>[conv2a, conv2b], floatOutput: true);
      intermediates.addAll(<ui.Image>[conv3a, conv3b]);

      restored = _runPass(
        programs[8],
        width,
        height,
        <ui.Image>[source, conv3a, conv3b],
        floatOutput: false,
      );

      /// Force rasterisation of the whole chain before the intermediate images
      /// are released. `Picture.toImageSync` is lazy, so the read-back is what
      /// guarantees every queued pass has actually been executed.
      await restored.toByteData(format: ui.ImageByteFormat.rawRgba);

      for (final ui.Image image in intermediates) {
        image.dispose();
      }

      stopwatch.stop();
      log.info('Anime4K Restore L: ${width}x$height in ${stopwatch.elapsedMilliseconds}ms');

      return restored;
    } catch (e, s) {
      log.error('Anime4K Restore L failed: $e\n$s');
      restored?.dispose();
      for (final ui.Image image in intermediates) {
        image.dispose();
      }
      return null;
    }
  }

  ui.Image _runPass(
    ui.FragmentProgram program,
    int width,
    int height,
    List<ui.Image> inputs, {
    required bool floatOutput,
  }) {
    final ui.FragmentShader shader = program.fragmentShader();
    shader.setFloat(0, width.toDouble());
    shader.setFloat(1, height.toDouble());
    for (int i = 0; i < inputs.length; i++) {
      shader.setImageSampler(i, inputs[i]);
    }

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..shader = shader,
    );

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = picture.toImageSync(
      width,
      height,
      targetFormat: floatOutput ? ui.TargetPixelFormat.rgbaFloat32 : ui.TargetPixelFormat.dontCare,
    );

    picture.dispose();
    shader.dispose();
    return image;
  }
}

final Anime4KRestoreService anime4KRestoreService = Anime4KRestoreService._();

