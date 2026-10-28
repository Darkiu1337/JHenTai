import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

/// Keeps a loading/error placeholder at its natural size, centered in the
/// viewport, while its page is zoomed.
///
/// The whole page (image plus placeholders) is the child of the page's
/// PhotoView, so a plain placeholder would be scaled and pushed away by the
/// zoom. The placeholder is therefore centered in the page (whose box equals
/// the viewport) and then transformed with the inverse of the PhotoView
/// transform: scale `1 / s` and translate `-position / s`.
///
/// When [controller] is null (list layouts, whose PhotoView child is the whole
/// list rather than a viewport sized page) the child is returned untouched.
class UnzoomedPlaceholder extends StatelessWidget {
  final PhotoViewControllerBase? controller;
  final Widget child;

  const UnzoomedPlaceholder({
    Key? key,
    required this.controller,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final PhotoViewControllerBase? controller = this.controller;
    if (controller == null) {
      return child;
    }

    /// Centering it here is what makes the inverse transform below line up with
    /// the viewport center; the page child is laid out at viewport size.
    return Center(
      child: StreamBuilder<PhotoViewControllerValue>(
        stream: controller.outputStateStream,
        initialData: controller.value,
        builder: (BuildContext context, AsyncSnapshot<PhotoViewControllerValue> snapshot) {
          final PhotoViewControllerValue? value = snapshot.data;
          final double scale = value?.scale ?? 1.0;
          if (scale <= 1.001) {
            return child;
          }

          final Offset position = value?.position ?? Offset.zero;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translate(-position.dx / scale, -position.dy / scale)
              ..scale(1 / scale),
            child: child,
          );
        },
      ),
    );
  }
}
