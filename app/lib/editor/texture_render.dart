import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'background_style.dart';

// 边框纹理全部由程序生成，不依赖外部图片。
// 图案类（点阵、网格、星星、电路……）直接画矢量，任何导出尺寸都锐利；
// 材质类（纸张、织物、大理石……）用可无缝平铺的灰度图块，按需在后台生成一次。

const _tile = 512;

/// 材质图块在 100% 大小时覆盖的画布单位（照片短边 = 1000）。
const rasterTextureSpan = <String, double>{
  'finePaper': 260,
  'kraft': 300,
  'xuan': 420,
  'watercolor': 240,
  'linen': 150,
  'canvas': 220,
  'marble': 700,
  'grain': 120,
  'brushed': 320,
};

/// 每次有材质图块生成完成时加一，预览据此重绘。
final textureTiles = ValueNotifier<int>(0);
final _tiles = <String, Image>{};
final _pending = <String, Future<void>>{};

bool textureReady(String kind) =>
    !rasterTextureSpan.containsKey(kind) || _tiles.containsKey(kind);

Future<void> ensureTexture(String kind) {
  if (textureReady(kind)) return Future.value();
  return _pending[kind] ??= () async {
    try {
      final pixels = await compute(textureTilePixels, kind);
      final done = Completer<Image>();
      decodeImageFromPixels(
          pixels, _tile, _tile, PixelFormat.rgba8888, done.complete);
      _tiles[kind] = await done.future;
      textureTiles.value++;
    } finally {
      _pending.remove(kind);
    }
  }();
}

/// 在当前裁切区域（边框）内铺纹理；canvas 为画布单位坐标。
void paintTexture(Canvas canvas, BackgroundStyle f, Rect area, Rect photo) {
  final kind = f.texture;
  if (!f.hasTexture || f.textureOpacity <= 0) return;
  final color = Color(f.textureColor).withValues(alpha: f.textureOpacity / 100);
  final s = f.textureScale / 100;
  final span = rasterTextureSpan[kind];
  if (span != null) {
    final tile = _tiles[kind];
    if (tile == null) {
      unawaited(ensureTexture(kind));
      return;
    }
    final k = span * s / _tile;
    canvas.drawRect(
        area,
        Paint()
          ..shader = ImageShader(
              tile,
              TileMode.repeated,
              TileMode.repeated,
              Float64List.fromList(
                  [k, 0, 0, 0, 0, k, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
              filterQuality: FilterQuality.medium)
          ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn));
    return;
  }
  _paintPattern(canvas, kind, area, photo, s, color);
}

double _hash(int i, int j, int k) {
  var x = (i * 374761393 + j * 668265263 + k * 1442695041) & 0xffffffff;
  x = ((x ^ (x >> 13)) * 1274126177) & 0xffffffff;
  x ^= x >> 16;
  return x / 0xffffffff;
}

void _paintPattern(Canvas canvas, String kind, Rect area, Rect photo, double s,
    Color color) {
  final origin = area.center;
  final fill = Paint()
    ..color = color
    ..isAntiAlias = true;
  Paint stroke(double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..isAntiAlias = true;
  // 完全落在照片内的图元会被照片盖住，跳过以减少绘制量。
  final hidden = photo.deflate(2);
  Iterable<(int, int, Offset)> cells(double sx, double sy,
      {bool stagger = false, double pad = 0}) sync* {
    final i0 = ((area.left - origin.dx) / sx).floor() - 1,
        i1 = ((area.right - origin.dx) / sx).ceil() + 1,
        j0 = ((area.top - origin.dy) / sy).floor() - 1,
        j1 = ((area.bottom - origin.dy) / sy).ceil() + 1;
    for (var j = j0; j <= j1; j++) {
      for (var i = i0; i <= i1; i++) {
        final p = origin +
            Offset(i * sx + (stagger && j.isOdd ? sx / 2 : 0), j * sy);
        if (hidden.deflate(pad).contains(p)) continue;
        yield (i, j, p);
      }
    }
  }

  Float32List points(Iterable<Offset> list) =>
      Float32List.fromList([for (final p in list) ...[p.dx, p.dy]]);

  switch (kind) {
    case 'dots':
      final sp = 14 * s;
      canvas.drawRawPoints(
          PointMode.points,
          points(cells(sp, sp, pad: sp).map((c) => c.$3)),
          stroke(2.4 * s)..strokeCap = StrokeCap.round);
    case 'polka':
      final sp = 34 * s;
      canvas.drawRawPoints(
          PointMode.points,
          points(cells(sp, sp * .87, stagger: true, pad: sp).map((c) => c.$3)),
          stroke(13 * s)..strokeCap = StrokeCap.round);
    case 'diagonal':
      final sp = 9 * s, path = Path(), size = area.width + area.height;
      for (var d = -size; d <= size; d += sp) {
        path
          ..moveTo(area.left + d, area.top)
          ..lineTo(area.left + d + area.height, area.bottom);
      }
      canvas.drawPath(path, stroke(.8 * s));
    case 'grid':
      final sp = 22 * s, path = Path();
      for (var x = origin.dx - ((origin.dx - area.left) / sp).ceil() * sp;
          x <= area.right;
          x += sp) {
        path
          ..moveTo(x, area.top)
          ..lineTo(x, area.bottom);
      }
      for (var y = origin.dy - ((origin.dy - area.top) / sp).ceil() * sp;
          y <= area.bottom;
          y += sp) {
        path
          ..moveTo(area.left, y)
          ..lineTo(area.right, y);
      }
      canvas.drawPath(path, stroke(.7 * s));
    case 'scanlines':
      final sp = 4.5 * s, thin = Path(), bold = Path();
      var row = 0;
      for (var y = area.top; y <= area.bottom; y += sp, row++) {
        (row % 12 == 0 ? bold : thin)
          ..moveTo(area.left, y)
          ..lineTo(area.right, y);
      }
      canvas.drawPath(thin, stroke(1.4 * s));
      canvas.drawPath(bold, stroke(2.4 * s));
    case 'gingham':
      final period = 30 * s, band = 15 * s, rows = Path(), columns = Path();
      for (var y = area.top - period; y <= area.bottom; y += period) {
        rows.addRect(Rect.fromLTWH(area.left, y, area.width, band));
      }
      for (var x = area.left - period; x <= area.right; x += period) {
        columns.addRect(Rect.fromLTWH(x, area.top, band, area.height));
      }
      // 两层分别绘制，交叉处颜色叠深，形成格纹。
      canvas.drawPath(rows, fill);
      canvas.drawPath(columns, fill);
    case 'stars':
      final sp = 46 * s, path = Path();
      void star(Offset c, double r, int tips, double turn) {
        for (var k = 0; k < tips * 2; k++) {
          final a = turn - math.pi / 2 + k * math.pi / tips;
          final p = c +
              Offset(math.cos(a), math.sin(a)) * (k.isEven ? r : r * .45);
          k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
      }

      for (final (i, j, p) in cells(sp, sp * .87, stagger: true, pad: sp)) {
        final h = _hash(i, j, 1);
        if (h < .62) {
          star(p, (6 + _hash(i, j, 2) * 2.5) * s, 5, (h - .3) * .8);
        } else {
          star(p, 3.6 * s, 4, 0);
        }
      }
      canvas.drawPath(path, fill);
    case 'honeycomb':
      final r = 15 * s, w = math.sqrt(3) * r, path = Path();
      for (final (_, _, c) in cells(w, r * 1.5, stagger: true, pad: r * 2)) {
        for (var k = 0; k <= 6; k++) {
          final a = math.pi / 6 + k * math.pi / 3;
          final p = c + Offset(math.cos(a), math.sin(a)) * r;
          k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, stroke(.9 * s));
    case 'circuit':
      final c = 26 * s, traces = Path(), pads = Path();
      for (final (i, j, start) in cells(c, c, pad: c * 5)) {
        if (_hash(i, j, 1) > .3) continue;
        final down = _hash(i, j, 6) < .35;
        Offset step(double along, double across) =>
            down ? Offset(across, along) * c : Offset(along, across) * c;
        final first = start + step((1 + (_hash(i, j, 2) * 3).floor()) * 1.0, 0);
        var end = first;
        if (_hash(i, j, 3) < .6) {
          final side = _hash(i, j, 4) < .5 ? -1.0 : 1.0;
          end = first +
              step(1, side) +
              step((1 + (_hash(i, j, 5) * 2).floor()) * 1.0, 0);
          traces
            ..moveTo(start.dx, start.dy)
            ..lineTo(first.dx, first.dy)
            ..lineTo((first + step(1, side)).dx, (first + step(1, side)).dy)
            ..lineTo(end.dx, end.dy);
        } else {
          traces
            ..moveTo(start.dx, start.dy)
            ..lineTo(end.dx, end.dy);
        }
        traces.addOval(Rect.fromCircle(center: end, radius: 2.8 * s));
        pads.addOval(Rect.fromCircle(center: start, radius: 1.8 * s));
      }
      canvas.drawPath(traces, stroke(1.1 * s));
      canvas.drawPath(pads, fill);
  }
}

// ------------------------------------------------------------ 材质图块

/// 可无缝平铺的值噪声：格点按图块边长取模。
class _Noise {
  final int fx, fy;
  final Float64List v;
  _Noise(math.Random r, this.fx, this.fy)
      : v = Float64List.fromList(
            List.generate(fx * fy, (_) => r.nextDouble()));
  double at(double u, double w) {
    final x = u * fx, y = w * fy;
    final x0 = x.floor(), y0 = y.floor();
    var tx = x - x0, ty = y - y0;
    tx = tx * tx * (3 - 2 * tx);
    ty = ty * ty * (3 - 2 * ty);
    double g(int a, int b) => v[(b % fy) * fx + (a % fx)];
    final top = g(x0, y0) + (g(x0 + 1, y0) - g(x0, y0)) * tx;
    final bottom = g(x0, y0 + 1) + (g(x0 + 1, y0 + 1) - g(x0, y0 + 1)) * tx;
    return top + (bottom - top) * ty;
  }
}

double Function(double, double) _fbm(math.Random r, int fx, int fy,
    [int octaves = 4]) {
  final layers = [
    for (var k = 0; k < octaves; k++)
      _Noise(r, math.min(_tile, fx << k), math.min(_tile, fy << k))
  ];
  return (u, w) {
    var sum = 0.0, weight = 1.0, total = 0.0;
    for (final n in layers) {
      sum += n.at(u, w) * weight;
      total += weight;
      weight *= .5;
    }
    return sum / total;
  };
}

/// 生成 512×512 的灰度遮罩（RGBA，预乘），只有透明度有意义。
Uint8List textureTilePixels(String kind) {
  const n = _tile;
  final r = math.Random(kind.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7fffffff));
  final a = Float64List(n * n);
  void each(double Function(int x, int y, double u, double w) f) {
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        a[y * n + x] = f(x, y, x / n, y / n);
      }
    }
  }

  void stamp(double x, double y, double alpha) {
    final x0 = x.floor(), y0 = y.floor(), tx = x - x0, ty = y - y0;
    for (final (dx, dy, k) in [
      (0, 0, (1 - tx) * (1 - ty)),
      (1, 0, tx * (1 - ty)),
      (0, 1, (1 - tx) * ty),
      (1, 1, tx * ty)
    ]) {
      final i = ((y0 + dy) % n) * n + ((x0 + dx) % n);
      a[i] += alpha * k * (1 - a[i]);
    }
  }

  void fibers(int count, double minLength, double maxLength, double curl,
      double minAlpha, double maxAlpha) {
    for (var k = 0; k < count; k++) {
      var x = r.nextDouble() * n, y = r.nextDouble() * n;
      var angle = r.nextDouble() * math.pi * 2;
      final length = minLength + r.nextDouble() * (maxLength - minLength);
      final alpha = minAlpha + r.nextDouble() * (maxAlpha - minAlpha);
      for (var t = 0.0; t < length; t += .6) {
        // 两端渐隐，像真实纤维。
        final fade = math.sin(math.pi * t / length);
        stamp(x, y, alpha * fade);
        angle += (r.nextDouble() - .5) * curl;
        x += math.cos(angle) * .6;
        y += math.sin(angle) * .6;
      }
    }
  }

  double rand() => r.nextDouble();
  switch (kind) {
    case 'finePaper':
      final cloud = _fbm(r, 4, 4, 5);
      each((x, y, u, w) => .3 * cloud(u, w) + .4 * math.pow(rand(), 5));
      fibers(160, 10, 40, .35, .25, .5);
    case 'kraft':
      final cloud = _fbm(r, 6, 6, 5);
      each((x, y, u, w) => .4 * cloud(u, w) + .25 * rand() * rand());
      fibers(900, 6, 28, .45, .3, .7);
      for (var k = 0; k < 260; k++) {
        final x = rand() * n, y = rand() * n, alpha = .5 + rand() * .4;
        stamp(x, y, alpha);
        stamp(x + .8, y + .4, alpha);
      }
    case 'xuan':
      final cloud = _fbm(r, 3, 3, 5), mottle = _fbm(r, 16, 16, 3);
      each((x, y, u, w) =>
          .5 * math.pow(cloud(u, w), 1.5) + .18 * mottle(u, w));
      fibers(45, 60, 200, .1, .12, .25);
      fibers(1100, 5, 18, .6, .1, .28);
    case 'watercolor':
      final bumps = _fbm(r, 12, 12, 3), soft = _fbm(r, 3, 3, 2);
      const d = 1.5 / n;
      each((x, y, u, w) => ((bumps(u, w) - bumps(u + d, w + d)) * 9 + .22) *
          (.7 + .3 * soft(u, w)));
    case 'linen':
      final slub = _fbm(r, 64, 8, 3), slub2 = _fbm(r, 8, 64, 3);
      final rows = [for (var i = 0; i < n ~/ 4; i++) .35 + rand() * .65];
      final columns = [for (var i = 0; i < n ~/ 4; i++) .35 + rand() * .65];
      each((x, y, u, w) {
        final gy = math.pow(.5 + .5 * math.cos(2 * math.pi * y / 4), 3);
        final gx = math.pow(.5 + .5 * math.cos(2 * math.pi * x / 4), 3);
        return .5 * gy * rows[y ~/ 4] * (.6 + slub(u, w)) +
            .5 * gx * columns[x ~/ 4] * (.6 + slub2(u, w)) +
            .08 * rand();
      });
    case 'canvas':
      final cloud = _fbm(r, 8, 8, 3);
      each((x, y, u, w) {
        final over = ((x ~/ 8) + (y ~/ 8)).isEven;
        final shade = over
            ? .5 - .5 * math.cos(2 * math.pi * (y % 8) / 8)
            : .5 - .5 * math.cos(2 * math.pi * (x % 8) / 8);
        return .45 * shade + .2 * cloud(u, w) + .12 * rand();
      });
    case 'marble':
      final turbulence = _fbm(r, 3, 3, 6),
          fine = _fbm(r, 5, 5, 6),
          cloud = _fbm(r, 2, 2, 4);
      each((x, y, u, w) {
        final v1 = 1 -
            math.sin(2 * math.pi * (2 * u + w) + 6 * turbulence(u, w)).abs();
        final v2 = 1 -
            math.sin(2 * math.pi * (3 * u - 2 * w) + 9 * fine(u, w)).abs();
        // 宽而淡的云带 + 细而清晰的主纹 + 更细的次纹。
        return .3 * math.pow(v1, 5) +
            .45 * math.pow(v1, 60) +
            .35 * math.pow(v2, 90) +
            .16 * cloud(u, w);
      });
    case 'grain':
      each((x, y, u, w) => math.pow(rand(), 3).toDouble());
    case 'brushed':
      final streak = _fbm(r, 2, 128, 3);
      final rows = [for (var i = 0; i < n; i++) rand()];
      each((x, y, u, w) =>
          .55 * streak(u, w) + .3 * rows[y] + .15 * rand());
  }
  final out = Uint8List(n * n * 4);
  for (var i = 0; i < n * n; i++) {
    final v = (a[i].clamp(0.0, 1.0) * 255).round();
    out[i * 4] = v;
    out[i * 4 + 1] = v;
    out[i * 4 + 2] = v;
    out[i * 4 + 3] = v;
  }
  return out;
}
