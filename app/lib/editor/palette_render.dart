import 'dart:math' as math;
import 'dart:ui';
import 'palette_style.dart';

Size _cellSize(PaletteStyle p) => p.mode == 'strip' || p.shape == 'roundedRect'
    ? Size(p.size, p.height)
    : p.shape == 'hexagon'
        ? Size(math.sqrt(3) * p.size, p.size * 2)
        : Size.square(p.size);

Size paletteSize(PaletteStyle p) {
  final cell = _cellSize(p), padding = _strokePadding(p);
  return Size(
      (cell.width * 6 +
              padding.width * (p.mode == 'strip' ? 2 : 12) +
              (p.mode == 'strip' ? 0 : p.gap * 5)) *
          p.scale,
      (cell.height + padding.height * 2) * p.scale);
}

double _strokeWidth(PaletteStyle p) => p.strokeWidth
    .clamp(.1, math.min(_cellSize(p).width, _cellSize(p).height) / 2);
Size _strokePadding(PaletteStyle p) {
  if (!p.stroke || p.strokeGap <= 0) return Size.zero;
  final extent = p.strokeGap + _strokeWidth(p);
  return Size(
      extent,
      p.mode != 'strip' && p.shape == 'hexagon'
          ? extent / math.cos(math.pi / 6)
          : extent);
}

/// Isolated stroke ring: clearing its interior never erases artwork beneath it.
void _outsideStroke(Canvas canvas, Path path, Rect bounds, PaletteStyle p) {
  canvas.saveLayer(bounds, Paint());
  canvas.drawPath(
      path,
      Paint()
        ..color = Color(p.strokeColor)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * (p.strokeGap + _strokeWidth(p)));
  canvas.drawPath(
      path,
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * p.strokeGap);
  canvas.drawPath(path, Paint()..blendMode = BlendMode.clear);
  canvas.restore();
}

Path _shape(PaletteStyle p, Rect r) {
  if (p.shape == 'circle') return Path()..addOval(r);
  if (p.shape != 'hexagon')
    return Path()
      ..addRRect(RRect.fromRectAndRadius(r,
          Radius.circular(p.radius.clamp(0, math.min(r.width, r.height) / 2))));
  final vertices = List.generate(6, (i) {
    final angle = -math.pi / 2 + math.pi / 3 * i;
    return r.center + Offset(math.cos(angle), math.sin(angle)) * (r.height / 2);
  });
  final cut = p.radius.clamp(0.0, p.size / 2);
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final v = vertices[i],
        previous = vertices[(i + 5) % 6],
        next = vertices[(i + 1) % 6];
    final a = v + (previous - v) / (previous - v).distance * cut;
    final b = v + (next - v) / (next - v).distance * cut;
    if (i == 0)
      path.moveTo(a.dx, a.dy);
    else
      path.lineTo(a.dx, a.dy);
    path.quadraticBezierTo(v.dx, v.dy, b.dx, b.dy);
  }
  return path..close();
}

void paintPalette(Canvas canvas, Rect bounds, PaletteStyle p, List<int> colors,
    double opacity) {
  if (colors.length != 6) return;
  final ordered = p.reversed ? colors.reversed.toList() : colors;
  final alpha = (opacity / 100).clamp(0.0, 1.0), cell = _cellSize(p);
  final width = cell.width * 6;
  final stroke = _strokeWidth(p), padding = _strokePadding(p);
  final pen = Paint()
    ..color = Color(p.strokeColor)
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke * 2
    ..isAntiAlias = true;
  if (alpha < 1) {
    canvas.saveLayer(bounds,
        Paint()..color = const Color(0xffffffff).withValues(alpha: alpha));
  } else {
    canvas.save();
  }
  canvas.translate(bounds.left, bounds.top);
  canvas.scale(p.scale);
  if (p.mode == 'strip') {
    final r = Rect.fromLTWH(padding.width, padding.height, width, cell.height);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          r,
          Radius.circular(
              p.radius.clamp(0, math.min(width, cell.height) / 2))));
    canvas.save();
    canvas.clipPath(path);
    // One hard-stop shader has no independently antialiased internal edges.
    canvas.drawRect(
        r,
        Paint()
          ..shader = Gradient.linear(
              Offset(padding.width, 0), Offset(padding.width + width, 0), [
            for (final color in ordered) ...[Color(color), Color(color)]
          ], [
            for (var i = 0; i < 6; i++) ...[i / 6, (i + 1) / 6]
          ]));
    if (p.stroke) {
      if (p.strokeGap <= 0) canvas.drawPath(path, pen);
      if (p.strokeMode == 'each') {
        pen.strokeWidth = stroke;
        for (var i = 1; i < 6; i++) {
          canvas.drawLine(
              Offset(padding.width + i * cell.width, padding.height),
              Offset(
                  padding.width + i * cell.width, padding.height + cell.height),
              pen);
        }
      }
    }
    canvas.restore();
    if (p.stroke && p.strokeGap > 0) {
      _outsideStroke(
          canvas,
          path,
          Offset.zero &
              Size(width + padding.width * 2, cell.height + padding.height * 2),
          p);
    }
  } else {
    for (var i = 0; i < 6; i++) {
      final slot = Rect.fromLTWH(i * (cell.width + padding.width * 2 + p.gap),
          0, cell.width + padding.width * 2, cell.height + padding.height * 2);
      final rect = Rect.fromLTWH(
          slot.left + padding.width, padding.height, cell.width, cell.height);
      final path = _shape(p, rect);
      canvas.drawPath(path, Paint()..color = Color(ordered[i]));
      if (p.stroke) {
        if (p.strokeGap > 0) {
          _outsideStroke(canvas, path, slot, p);
        } else {
          canvas.save();
          canvas.clipPath(path);
          canvas.drawPath(path, pen);
          canvas.restore();
        }
      }
    }
  }
  canvas.restore();
}
