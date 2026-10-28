import 'package:flutter/material.dart';

/// The 8muses brand mark: two red rings forming an "8".
///
/// The original logo is a small SVG (two circles with holes on a rounded dark
/// square). Drawing it keeps it crisp at any size and avoids shipping an asset
/// that would look like a dark blob on a light theme.
class EightMusesMark extends StatelessWidget {
  /// Brand red used by the site's logo.
  static const Color brandColor = Color(0xFFEE001B);

  final double size;
  final Color color;

  const EightMusesMark({
    Key? key,
    this.size = 22,
    this.color = brandColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _EightMusesMarkPainter(color: color),
      ),
    );
  }
}

class _EightMusesMarkPainter extends CustomPainter {
  final Color color;

  const _EightMusesMarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    /// Geometry taken from the site's favicon (64x64 viewBox):
    /// top ring: center y=21, outer r=14, hole r=5.5
    /// bottom ring: center y=43, outer r=15, hole r=6.5
    final double side = size.shortestSide;
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeWidth = side * 8.5 / 64;

    canvas.drawCircle(Offset(side / 2, side * 21 / 64), side * 9.75 / 64, paint);
    canvas.drawCircle(Offset(side / 2, side * 43 / 64), side * 10.75 / 64, paint);
  }

  @override
  bool shouldRepaint(covariant _EightMusesMarkPainter oldDelegate) => oldDelegate.color != color;
}
