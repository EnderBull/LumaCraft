import 'dart:math' as math;
import 'dart:ui';
import 'style_document.dart';
import 'texture_render.dart';

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

/// 底色只铺在边框区域，不铺在照片下面。
/// 缩放到小数比例时，照片边缘像素只有部分覆盖；如果下面铺着浅色底色，
/// 这些像素就会混入底色，在深色照片边缘形成一圈白边。
/// 有边框的一边让底色向照片内多伸几个像素，保证照片与边框交界平滑；
/// 边框为 0 的一边（照片贴着画布边缘）不铺底色，边缘像素只会与画布外部混合。
Path _borderArea(StyleGeometry g) {
  // 重叠部分被不透明的照片盖住，看不见；取 4 是为了缩小显示（每个画布单位不足 1 像素）时也不留缝。
  const overlap = 4.0, outside = 2.0;
  final photo = g.photo;
  final hole = Rect.fromLTRB(
      g.left > 0 ? photo.left + overlap : photo.left - outside,
      g.top > 0 ? photo.top + overlap : photo.top - outside,
      g.right > 0 ? photo.right - overlap : photo.right + outside,
      g.bottom > 0 ? photo.bottom - overlap : photo.bottom + outside);
  return Path.combine(PathOperation.difference,
      Path()..addRect(Offset.zero & g.size), Path()..addRect(hole));
}

void paintStyleBackground(
    Canvas canvas, StyleDocument d, StyleGeometry g, Image photo) {
  final rect = Offset.zero & g.size, fill = d.fill;
  final clipped = fill.mode != 'blur';
  if (clipped) {
    canvas.save();
    canvas.clipPath(_borderArea(g));
  }
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
  if (clipped) canvas.restore();
  if (fill.hasTexture && (g.top > 0 || g.bottom > 0 || g.left > 0 || g.right > 0)) {
    canvas.save();
    canvas.clipPath(_borderArea(g));
    paintTexture(canvas, fill, rect, g.photo);
    canvas.restore();
  }
}

List<RRect> filmHoles(StyleDocument d, StyleGeometry g) {
  final f = d.film;
  if (!f.enabled) return [];
  final vertical = f.verticalFor(g.photo), hole = f.holeFor(g.photo);
  final w = hole.width, h = hole.height;
  final step = (vertical ? h : w) + f.gap;
  final length = vertical ? g.size.height : g.size.width;
  final out = <RRect>[];
  // First centre is on the edge: partial holes are an intentional film detail.
  for (double p = 0;
      p < length + (vertical ? h : w) / 2;
      p += math.max(2, step)) {
    for (final near in [true, false]) {
      final available =
          vertical ? (near ? g.left : g.right) : (near ? g.top : g.bottom);
      if (available <= 0) continue;
      final cross = vertical ? w : h;
      if (f.inset + cross > available) continue;
      final rect = vertical
          ? Rect.fromLTWH(near ? f.inset : g.size.width - f.inset - w,
              p - h / 2, w, h)
          : Rect.fromLTWH(
              p - w / 2, near ? f.inset : g.size.height - f.inset - h, w, h);
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
