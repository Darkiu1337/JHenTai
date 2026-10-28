import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:photo_view/photo_view.dart'
    show
        PhotoViewDoubleTapZoomEndCallback,
        PhotoViewHeroAttributes,
        PhotoViewImageScaleEndCallback,
        PhotoViewImageTapDownCallback,
        PhotoViewImageTapUpCallback,
        PhotoViewScaleState,
        ScaleStateCycle;
import 'package:photo_view/src/controller/photo_view_controller.dart';
import 'package:photo_view/src/controller/photo_view_controller_delegate.dart';
import 'package:photo_view/src/controller/photo_view_scalestate_controller.dart';
import 'package:photo_view/src/core/photo_view_gesture_detector.dart';
import 'package:photo_view/src/core/photo_view_hit_corners.dart';
import 'package:photo_view/src/utils/photo_view_utils.dart';

const _defaultDecoration = const BoxDecoration(
  color: const Color.fromRGBO(0, 0, 0, 1.0),
);

/// Scale added by a tap-drag gesture that covers the whole viewport height.
///
/// This used to be a hard-coded `5`, which made a 20% drag add a full scale
/// unit. The reader wants a fine adjustment, so a full-height drag now adds
/// about one step.
const double _kTapDragZoomScalesPerScreenHeight = 1.2;

/// Tolerance used when comparing scale values.
const double _kScaleEpsilon = 0.001;

/// Scale multiplier applied by one double tap step.
const double _kDoubleTapZoomStep = 1.5;

/// Internal widget in which controls all animations lifecycle, core responses
/// to user gestures, updates to  the controller state and mounts the entire PhotoView Layout
class PhotoViewCore extends StatefulWidget {
  const PhotoViewCore({
    Key? key,
    required this.imageProvider,
    required this.backgroundDecoration,
    required this.semanticLabel,
    required this.gaplessPlayback,
    required this.heroAttributes,
    required this.enableRotation,
    required this.onTapUp,
    required this.onTapDown,
    required this.onScaleEnd,
    this.onDoubleTapZoomEnd,
    this.enableTapDragZoom,
    required this.gestureDetectorBehavior,
    required this.controller,
    required this.scaleBoundaries,
    this.scaleStateCycle,
    required this.scaleStateController,
    required this.basePosition,
    required this.tightMode,
    required this.filterQuality,
    required this.disableGestures,
    required this.enablePanAlways,
    this.enableCtrlScrollZoom = false,
    this.ctrlScrollZoomFactor = 0.05,
  })  : customChild = null,
        super(key: key);

  const PhotoViewCore.customChild({
    Key? key,
    required this.customChild,
    required this.backgroundDecoration,
    this.heroAttributes,
    required this.enableRotation,
    this.onTapUp,
    this.onTapDown,
    this.onScaleEnd,
    this.onDoubleTapZoomEnd,
    this.enableTapDragZoom,
    this.gestureDetectorBehavior,
    required this.controller,
    required this.scaleBoundaries,
    this.scaleStateCycle,
    required this.scaleStateController,
    required this.basePosition,
    required this.tightMode,
    required this.filterQuality,
    required this.disableGestures,
    required this.enablePanAlways,
    this.enableCtrlScrollZoom = false,
    this.ctrlScrollZoomFactor = 0.05,
  })  : imageProvider = null,
        semanticLabel = null,
        gaplessPlayback = false,
        super(key: key);

  final Decoration? backgroundDecoration;
  final ImageProvider? imageProvider;
  final String? semanticLabel;
  final bool? gaplessPlayback;
  final PhotoViewHeroAttributes? heroAttributes;
  final bool enableRotation;
  final Widget? customChild;

  final PhotoViewControllerBase controller;
  final PhotoViewScaleStateController scaleStateController;
  final ScaleBoundaries scaleBoundaries;
  final ScaleStateCycle? scaleStateCycle;
  final Alignment basePosition;

  final PhotoViewImageTapUpCallback? onTapUp;
  final PhotoViewImageTapDownCallback? onTapDown;
  final PhotoViewImageScaleEndCallback? onScaleEnd;
  final bool? enableTapDragZoom;
  final PhotoViewDoubleTapZoomEndCallback? onDoubleTapZoomEnd;
  final HitTestBehavior? gestureDetectorBehavior;
  final bool tightMode;
  final bool disableGestures;
  final bool enablePanAlways;

  final FilterQuality filterQuality;

  final bool enableCtrlScrollZoom;
  final double ctrlScrollZoomFactor;

  @override
  State<StatefulWidget> createState() {
    return PhotoViewCoreState();
  }

  bool get hasCustomChild => customChild != null;
}

class PhotoViewCoreState extends State<PhotoViewCore> with TickerProviderStateMixin, PhotoViewControllerDelegate, HitCornersDetector {
  Offset? _normalizedPosition;
  double? _scaleBefore;
  double? _rotationBefore;

  late final AnimationController _scaleAnimationController;
  Animation<double>? _scaleAnimation;

  late final AnimationController _positionAnimationController;
  Animation<Offset>? _positionAnimation;

  late final AnimationController _rotationAnimationController = AnimationController(vsync: this)..addListener(handleRotationAnimation);
  Animation<double>? _rotationAnimation;

  PhotoViewHeroAttributes? get heroAttributes => widget.heroAttributes;

  late ScaleBoundaries cachedScaleBoundaries = widget.scaleBoundaries;

  Offset? _doubleTapLocation;

  bool _isCtrlPressed = false;

  void handleScaleAnimation() {
    scale = _scaleAnimation!.value;
  }

  void handlePositionAnimate() {
    controller.position = _positionAnimation!.value;
  }

  void handleRotationAnimation() {
    controller.rotation = _rotationAnimation!.value;
  }

  void onScaleStart(ScaleStartDetails details) {
    _rotationBefore = controller.rotation;
    _scaleBefore = scale;
    _normalizedPosition = details.focalPoint - controller.position;
    _scaleAnimationController.stop();
    _positionAnimationController.stop();
    _rotationAnimationController.stop();
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    final double newScale = _scaleBefore! * details.scale;
    final Offset delta = details.focalPoint - _normalizedPosition!;

    updateScaleStateFromNewScale(newScale);

    updateMultiple(
      scale: newScale,
      position: widget.enablePanAlways ? delta : clampPosition(position: delta * details.scale),
      rotation: widget.enableRotation ? _rotationBefore! + details.rotation : null,
      rotationFocusPoint: widget.enableRotation ? details.focalPoint : null,
    );
  }

  void onScaleEnd(ScaleEndDetails details) {
    final double _scale = scale;
    final Offset _position = controller.position;
    final double maxScale = scaleBoundaries.maxScale;
    final double minScale = scaleBoundaries.minScale;

    widget.onScaleEnd?.call(context, details, controller.value);

    //animate back to maxScale if gesture exceeded the maxScale specified
    if (_scale > maxScale) {
      final double scaleComebackRatio = maxScale / _scale;
      animateScale(_scale, maxScale);
      final Offset clampedPosition = clampPosition(
        position: _position * scaleComebackRatio,
        scale: maxScale,
      );
      animatePosition(_position, clampedPosition);
      return;
    }

    //animate back to minScale if gesture fell smaller than the minScale specified
    if (_scale < minScale) {
      final double scaleComebackRatio = minScale / _scale;
      animateScale(_scale, minScale);
      animatePosition(
        _position,
        clampPosition(
          position: _position * scaleComebackRatio,
          scale: minScale,
        ),
      );
      return;
    }
    // get magnitude from gesture velocity
    final double magnitude = details.velocity.pixelsPerSecond.distance;

    // animate velocity only if there is no scale change and a significant magnitude
    if (_scaleBefore! / _scale == 1.0 && magnitude >= 400.0) {
      final Offset direction = details.velocity.pixelsPerSecond / magnitude;
      animatePosition(
        _position,
        clampPosition(position: _position + direction * 100.0),
      );
    }
  }

  void onZoomStart(TapDragZoomStartDetails details) {
    _rotationBefore = controller.rotation;
    _scaleBefore = scale;
    _normalizedPosition = details.localPoint;
    _scaleAnimationController.stop();
    _positionAnimationController.stop();
    _rotationAnimationController.stop();
  }

  void onZoomUpdate(TapDragZoomUpdateDetails details) {
    final Offset delta = details.localPoint - _normalizedPosition!;
    double newScale = _scaleBefore! + delta.dy / scaleBoundaries.outerSize.height * _kTapDragZoomScalesPerScreenHeight;

    if (newScale < scaleBoundaries.minScale) {
      newScale = scaleBoundaries.minScale;
    }
    if (newScale > scaleBoundaries.maxScale) {
      newScale = scaleBoundaries.maxScale;
    }

    updateScaleStateFromNewScale(newScale);

    if (controller.position == Offset.zero && _scaleBefore! == 1) {
      animatePosition(Offset.zero, localPosition2Offset(details.localPoint, _scaleBefore!));
    }
    updateMultiple(scale: newScale);
  }

  void onZoomEnd() {
    final double _scale = scale;
    final Offset _position = controller.position;
    final double maxScale = scaleBoundaries.maxScale;
    final double minScale = scaleBoundaries.minScale;

    widget.onDoubleTapZoomEnd?.call(context, controller.value);

    //animate back to maxScale if gesture exceeded the maxScale specified
    if (_scale > maxScale) {
      final double scaleComebackRatio = maxScale / _scale;
      animateScale(_scale, maxScale);
      final Offset clampedPosition = clampPosition(
        position: _position * scaleComebackRatio,
        scale: maxScale,
      );
      animatePosition(_position, clampedPosition);
      return;
    }

    //animate back to minScale if gesture fell smaller than the minScale specified
    if (_scale < minScale) {
      final double scaleComebackRatio = minScale / _scale;
      animateScale(_scale, minScale);
      animatePosition(
        _position,
        clampPosition(
          position: _position * scaleComebackRatio,
          scale: minScale,
        ),
      );
      return;
    }
  }

  void onDoubleTap() {
    nextScaleState();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
        event.logicalKey == LogicalKeyboardKey.controlRight) {
      final ctrlPressed = event is KeyDownEvent || event is KeyRepeatEvent;
      if (_isCtrlPressed != ctrlPressed) {
        _isCtrlPressed = ctrlPressed;
        if (mounted) {
          setState(() {});
        }
      }
    }
    return false;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (!widget.enableCtrlScrollZoom || event is! PointerScrollEvent || !_isCtrlPressed) {
      return;
    }

    GestureBinding.instance.pointerSignalResolver.register(event, (PointerSignalEvent resolvedEvent) {
      _handleCtrlScrollZoom(resolvedEvent as PointerScrollEvent);
    });
  }

  void _handleCtrlScrollZoom(PointerScrollEvent event) {
    final double scrollDelta = event.scrollDelta.dy;
    if (scrollDelta == 0) {
      return;
    }

    final double currentScale = scale;

    /// One wheel notch is one event, so the step is applied per event instead of
    /// per scrolled pixel. This keeps the zoom identical on slow and fast
    /// wheels and makes every notch a small, predictable step.
    final double step = scrollDelta < 0 ? widget.ctrlScrollZoomFactor : -widget.ctrlScrollZoomFactor;
    final double newScale = (currentScale * (1 + step)).clamp(scaleBoundaries.minScale, scaleBoundaries.maxScale).toDouble();
    if ((newScale - currentScale).abs() < _kScaleEpsilon) {
      return;
    }

    final Offset center = Offset(
      scaleBoundaries.outerSize.width / 2,
      scaleBoundaries.outerSize.height / 2,
    );
    final Offset relativeMousePos = event.localPosition - center;
    final Offset candidatePosition = controller.position + relativeMousePos * (1 - newScale / currentScale);
    final Offset newPosition = widget.enablePanAlways ? candidatePosition : clampPosition(position: candidatePosition, scale: newScale);

    /// Applied immediately (no scale/position animation): several notches in a
    /// row land exactly on the requested scale instead of restarting tweens.
    _scaleAnimationController.stop();
    _positionAnimationController.stop();
    updateScaleStateFromNewScale(newScale);
    updateMultiple(scale: newScale, position: newPosition);
  }

  void animateScale(double from, double to) {
    _scaleAnimation = Tween<double>(
      begin: from,
      end: to,
    ).animate(_scaleAnimationController);
    _scaleAnimationController
      ..value = 0.0
      ..fling(velocity: 0.4);
  }

  void animatePosition(Offset from, Offset to) {
    _positionAnimation = Tween<Offset>(begin: from, end: to).animate(_positionAnimationController);
    _positionAnimationController
      ..value = 0.0
      ..fling(velocity: 0.4);
  }

  void animateRotation(double from, double to) {
    _rotationAnimation = Tween<double>(begin: from, end: to).animate(_rotationAnimationController);
    _rotationAnimationController
      ..value = 0.0
      ..fling(velocity: 0.4);
  }

  void onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      onAnimationStatusCompleted();
    }
  }

  /// Check if scale is equal to initial after scale animation update
  void onAnimationStatusCompleted() {
    if (scaleStateController.scaleState != PhotoViewScaleState.initial && scale == scaleBoundaries.initialScale) {
      scaleStateController.setInvisibly(PhotoViewScaleState.initial);
    }
  }

  @override
  void initState() {
    super.initState();
    initDelegate();
    addAnimateOnScaleStateUpdate(animateOnScaleStateUpdate);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    cachedScaleBoundaries = widget.scaleBoundaries;

    _scaleAnimationController = AnimationController(vsync: this)
      ..addListener(handleScaleAnimation)
      ..addStatusListener(onAnimationStatus);
    _positionAnimationController = AnimationController(vsync: this)..addListener(handlePositionAnimate);
  }

  void animateOnScaleStateUpdate(double prevScale, double nextScale) {
    animateScale(prevScale, nextScale);
    animatePosition(controller.position, Offset.zero);
    animateRotation(controller.rotation, 0.0);
  }

  @override
  void dispose() {
    _scaleAnimationController.removeStatusListener(onAnimationStatus);
    _scaleAnimationController.dispose();
    _positionAnimationController.dispose();
    _rotationAnimationController.dispose();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  void onTapUp(TapUpDetails details) {
    widget.onTapUp?.call(context, details, controller.value);
  }

  void onTapDown(TapDownDetails details) {
    widget.onTapDown?.call(context, details, controller.value);
  }

  @override
  Widget build(BuildContext context) {
    // Check if we need a recalc on the scale
    if (widget.scaleBoundaries != cachedScaleBoundaries) {
      markNeedsScaleRecalc = true;
      cachedScaleBoundaries = widget.scaleBoundaries;
    }

    return StreamBuilder(
        stream: controller.outputStateStream,
        initialData: controller.prevValue,
        builder: (
          BuildContext context,
          AsyncSnapshot<PhotoViewControllerValue> snapshot,
        ) {
          if (snapshot.hasData) {
            final PhotoViewControllerValue value = snapshot.data!;
            final useImageScale = widget.filterQuality != FilterQuality.none;

            final computedScale = useImageScale ? 1.0 : scale;

            final matrix = Matrix4.identity()
              ..translate(value.position.dx, value.position.dy)
              ..scale(computedScale)
              ..rotateZ(value.rotation);

            final Widget customChildLayout = CustomSingleChildLayout(
              delegate: _CenterWithOriginalSizeDelegate(
                scaleBoundaries.childSize,
                basePosition,
                useImageScale,
              ),
              child: _buildHero(),
            );

            final child = Container(
              constraints: widget.tightMode ? BoxConstraints.tight(scaleBoundaries.childSize * scale) : null,
              child: Center(
                child: Transform(
                  child: customChildLayout,
                  transform: matrix,
                  alignment: basePosition,
                ),
              ),
              decoration: widget.backgroundDecoration ?? _defaultDecoration,
            );

            if (widget.disableGestures) {
              return child;
            }

            return PhotoViewGestureDetector(
              child: child,
              onDoubleTapDown: widget.scaleStateCycle != null ? recordPointerPosition : null,
              onDoubleTap: widget.scaleStateCycle != null ? nextScaleState : null,
              onDoubleTapCancel: widget.scaleStateCycle != null ? clearPointerPosition : null,
              onScaleStart: onScaleStart,
              onScaleUpdate: onScaleUpdate,
              onScaleEnd: onScaleEnd,
              onZoomStart: widget.enableTapDragZoom == true ? onZoomStart : null,
              onZoomUpdate: widget.enableTapDragZoom == true ? onZoomUpdate : null,
              onZoomEnd: widget.enableTapDragZoom == true ? onZoomEnd : null,
              hitDetector: this,
              onTapUp: widget.onTapUp != null ? (details) => widget.onTapUp!(context, details, value) : null,
              onTapDown: widget.onTapDown != null ? (details) => widget.onTapDown!(context, details, value) : null,
              onPointerSignal: _onPointerSignal,
              absorbChildPointerEvents: _isCtrlPressed && widget.enableCtrlScrollZoom,
            );
          } else {
            return Container();
          }
        });
  }

  Widget _buildHero() {
    return heroAttributes != null
        ? Hero(
            tag: heroAttributes!.tag,
            createRectTween: heroAttributes!.createRectTween,
            flightShuttleBuilder: heroAttributes!.flightShuttleBuilder,
            placeholderBuilder: heroAttributes!.placeholderBuilder,
            transitionOnUserGestures: heroAttributes!.transitionOnUserGestures,
            child: _buildChild(),
          )
        : _buildChild();
  }

  Widget _buildChild() {
    return widget.hasCustomChild
        ? widget.customChild!
        : Image(
            image: widget.imageProvider!,
            semanticLabel: widget.semanticLabel,
            gaplessPlayback: widget.gaplessPlayback ?? false,
            filterQuality: widget.filterQuality,
            width: scaleBoundaries.childSize.width * scale,
            fit: BoxFit.contain,
          );
  }

  @override
  void nextScaleState() {
    final double currentScale = scale;
    final double initialScale = scaleBoundaries.initialScale;
    final double maxScale = scaleBoundaries.maxScale;

    final bool isZoomed = currentScale > initialScale + _kScaleEpsilon;

    /// Zoomed in: a double tap returns to the initial size. Not zoomed: it
    /// applies a single step instead of jumping straight to the max scale.
    final double nextScale =
        isZoomed ? initialScale : math.min(initialScale * _kDoubleTapZoomStep, maxScale);

    if ((nextScale - currentScale).abs() < _kScaleEpsilon) {
      return;
    }

    final Offset nextPosition = isZoomed
        ? Offset.zero
        : clampPosition(
            position: localPosition2Offset(_doubleTapLocation, currentScale),
            scale: nextScale,
          );

    scaleStateController.setInvisibly(
      nextScale > initialScale + _kScaleEpsilon ? PhotoViewScaleState.zoomedIn : PhotoViewScaleState.initial,
    );
    animatePosition(controller.position, nextPosition);
    animateScale(currentScale, nextScale);
  }

  void recordPointerPosition(TapDownDetails details) {
    _doubleTapLocation = details.localPosition;
  }

  void clearPointerPosition() {
    _doubleTapLocation = null;
  }

  Offset localPosition2Offset(Offset? position, double scale) {
    final double screenWidth = scaleBoundaries.outerSize.width;
    final double screenHeight = scaleBoundaries.outerSize.height;

    final Offset _position = position ?? Offset(screenWidth / 2, screenWidth / 2);
    return -_position * scale + Offset(screenWidth / 2, screenHeight / 2);
  }
}

class _CenterWithOriginalSizeDelegate extends SingleChildLayoutDelegate {
  const _CenterWithOriginalSizeDelegate(
    this.subjectSize,
    this.basePosition,
    this.useImageScale,
  );

  final Size subjectSize;
  final Alignment basePosition;
  final bool useImageScale;

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final childWidth = useImageScale ? childSize.width : subjectSize.width;
    final childHeight = useImageScale ? childSize.height : subjectSize.height;

    final halfWidth = (size.width - childWidth) / 2;
    final halfHeight = (size.height - childHeight) / 2;

    final double offsetX = halfWidth * (basePosition.x + 1);
    final double offsetY = halfHeight * (basePosition.y + 1);
    return Offset(offsetX, offsetY);
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return useImageScale ? const BoxConstraints() : BoxConstraints.tight(subjectSize);
  }

  @override
  bool shouldRelayout(_CenterWithOriginalSizeDelegate oldDelegate) {
    return oldDelegate != this;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CenterWithOriginalSizeDelegate &&
          runtimeType == other.runtimeType &&
          subjectSize == other.subjectSize &&
          basePosition == other.basePosition &&
          useImageScale == other.useImageScale;

  @override
  int get hashCode => subjectSize.hashCode ^ basePosition.hashCode ^ useImageScale.hashCode;
}
