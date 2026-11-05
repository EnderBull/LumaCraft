import 'dart:math' as math;
import 'dart:ui';
import 'style_document.dart';

List<double> backgroundColorMatrix(
    double brightness, double contrast, double saturation) {
  final s = saturation / 100,
      c = contrast / 100,
      b = brightness * 2.55 + 127.5 * (1 - c);
  final r = .2126 * (1 - s), g = .7152 * (1 - s), l = .0722 * (1 - s);
  return [
    (r + s) * c,
    g * c,
    l * c,
    0,
    b,
    r * c,
    (g + s) * c,
    l * c,
    0,
    b,
    r * c,
    g * c,
    (l + s) * c,
    0,
    b,
    0,
    0,
    0,
    1,
    0
  ];
}

void paintStyleBackground(
    Canvas canvas, StyleDocument d, StyleGeometry g, Image photo) {
  final rect = Offset.zero & g.size, fill = d.fill;
  // A pale undercoat can bleed through fractional-scale blur layer edges.
  if (fill.mode != 'blur')
    canvas.drawRect(rect, Paint()..color = Color(d.background));
  if (fill.mode == 'gradient') {
    final a = fill.angle * math.pi / 180,
        dir = Offset(math.cos(a), math.sin(a));
    final extent =
        (g.size.width * dir.dx.abs() + g.size.height * dir.dy.abs()) / 2;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = fill.gradientType == 'radial'
              ? Gradient.radial(
                  Offset(rect.width * fill.centerX / 100,
                      rect.height * fill.centerY / 100),
                  rect.shortestSide * fill.radius / 100,
                  [Color(d.background), Color(fill.secondColor)])
              : Gradient.linear(
                  rect.center - dir * extent,
                  rect.center + dir * extent,
                  [Color(d.background), Color(fill.secondColor)]));
  } else if (fill.mode == 'blur') {
    canvas.save();
    canvas.clipRect(rect, doAntiAlias: false);
    // Overscan prevents transparent blur fringes along the outer canvas edge.
    final target = rect.inflate(fill.blur * 3 + 2);
    final imageRatio = photo.width / photo.height,
        ratio = target.width / target.height;
    final w =
        imageRatio > ratio ? photo.height * ratio : photo.width.toDouble();
    final h =
        imageRatio > ratio ? photo.height.toDouble() : photo.width / ratio;
    canvas.saveLayer(
        target,
        Paint()
          ..imageFilter = ImageFilter.blur(
              sigmaX: fill.blur, sigmaY: fill.blur, tileMode: TileMode.clamp));
    canvas.drawImageRect(
        photo,
        Rect.fromCenter(
            center: Offset(photo.width / 2, photo.height / 2),
            width: w,
            height: h),
        target,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..colorFilter = ColorFilter.matrix(backgroundColorMatrix(
              fill.brightness, fill.contrast, fill.saturation)));
    canvas.restore();
    canvas.restore();
  }
}

List<RRect> filmHoles(StyleDocument d, StyleGeometry g) {
  final f = d.film;
  if (!f.enabled) return [];
  final vertical = f.orientation == 'vertical';
  final step = (vertical ? f.height : f.width) + f.gap;
  final length = vertical ? g.size.height : g.size.width;
  final out = <RRect>[];
  // First centre is on the edge: partial holes are an intentional film detail.
  for (double p = 0;
      p < length + (vertical ? f.height : f.width) / 2;
      p += math.max(2, step)) {
    for (final near in [true, false]) {
      final available =
          vertical ? (near ? g.left : g.right) : (near ? g.top : g.bottom);
      if (available <= 0) continue;
      final cross = vertical ? f.width : f.height;
      if (f.inset + cross > available) continue;
      final rect = vertical
          ? Rect.fromLTWH(near ? f.inset : g.size.width - f.inset - f.width,
              p - f.height / 2, f.width, f.height)
          : Rect.fromLTWH(
              p - f.width / 2,
              near ? f.inset : g.size.height - f.inset - f.height,
              f.width,
              f.height);
      out.add(RRect.fromRectAndRadius(rect, Radius.circular(f.radius)));
    }
  }
  return out;
}

void paintPhotoShadow(Canvas canvas, StyleDocument d, StyleGeometry g) {
  final s = d.shadow;
  if (!s.enabled || s.opacity <= 0) return;
  final angle = s.angle * math.pi / 180;
  // Adobe-style light angle; the cast shadow lies in the opposite direction.
  final offset = Offset(-math.cos(angle), math.sin(angle)) * s.distance;
  final paint = Paint()
    ..color = Color(s.color).withValues(alpha: s.opacity / 100);
  if (s.feather > 0)
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, s.feather * .5);
  canvas.save();
  canvas.clipRect(Offset.zero & g.size);
  canvas.drawRect(g.photo.inflate(s.size).shift(offset), paint);
  canvas.restore();
}

void paintFilm(Canvas canvas, StyleDocument d, StyleGeometry g) {
  if (!d.film.enabled) return;
  canvas.save();
  canvas.clipPath(Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & g.size)
    ..addRect(g.photo));
  final paint = Paint()
    ..color = Color(d.film.color)
    ..isAntiAlias = true;
  for (final hole in filmHoles(d, g)) {
    canvas.drawRRect(hole, paint);
  }
  canvas.restore();
}
