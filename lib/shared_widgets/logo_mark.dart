import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../core/theme/tokens.dart';

/// SplitMate logo: a coin split into two halves (mint = owed to you,
/// coral = you owe). [split] animates the halves apart: 0 = whole coin, 1 = split.
class LogoMark extends StatelessWidget {
  final double size;
  final double split;

  /// Draw the yellow rounded tile behind the coin (app-icon style).
  final bool tile;

  const LogoMark({super.key, this.size = 72, this.split = 1, this.tile = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter(split.clamp(0, 1.4).toDouble(), tile)),
    );
  }
}

/// One half of the logo coin (for the splash animation). [left] = mint half.
class CoinHalf extends StatelessWidget {
  final double size;
  final bool left;
  const CoinHalf({super.key, required this.size, required this.left});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _HalfPainter(left)));
}

class _HalfPainter extends CustomPainter {
  final bool left;
  _HalfPainter(this.left);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final radius = s * 0.42;
    final stroke = s * 0.034;
    final start = left ? math.pi / 2 : -math.pi / 2;
    final rect = Rect.fromCircle(center: c, radius: radius);
    final path = Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(rect, start, math.pi, false)
      ..close();
    final ink = Paint()..color = Palette.ink;
    canvas.drawPath(path.shift(Offset(s * 0.04, s * 0.04)), ink);
    canvas.drawPath(path, Paint()..color = left ? Palette.mint : Palette.coral);
    canvas.drawPath(
      path,
      Paint()
        ..color = Palette.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius * 0.62),
      start + 0.14,
      math.pi - 0.28,
      false,
      Paint()
        ..color = Palette.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_HalfPainter old) => old.left != left;
}

class _LogoPainter extends CustomPainter {
  final double split;
  final bool tile;
  _LogoPainter(this.split, this.tile);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final ink = Paint()..color = Palette.ink;
    if (tile) {
      final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.24));
      canvas.drawRRect(r.shift(Offset(s * 0.05, s * 0.05)), ink);
      canvas.drawRRect(r, Paint()..color = Palette.yellow);
      canvas.drawRRect(
        r.deflate(s * 0.012),
        Paint()
          ..color = Palette.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.024,
      );
    }
    final c = Offset(s / 2 - s * 0.015, s / 2 - s * 0.015);
    final radius = s * (tile ? 0.30 : 0.42);
    final gap = s * 0.035 * split;
    final shadow = s * 0.028;
    final stroke = s * 0.024;

    void half(Color color, double start, Offset shift) {
      final rect = Rect.fromCircle(center: c + shift, radius: radius);
      final path = Path()
        ..moveTo(rect.center.dx, rect.center.dy)
        ..arcTo(rect, start, math.pi, false)
        ..close();
      canvas.drawPath(path.shift(Offset(shadow, shadow)), ink);
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(
        path,
        Paint()
          ..color = Palette.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeJoin = StrokeJoin.round,
      );
      final inner = Rect.fromCircle(center: c + shift, radius: radius * 0.62);
      canvas.drawArc(
        inner,
        start + 0.14,
        math.pi - 0.28,
        false,
        Paint()
          ..color = Palette.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.5
          ..strokeCap = StrokeCap.round,
      );
    }

    half(Palette.mint, math.pi / 2, Offset(-gap, -gap)); // left half
    half(Palette.coral, -math.pi / 2, Offset(gap, gap)); // right half
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.split != split || old.tile != tile;
}
