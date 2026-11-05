import 'dart:math' as math;
import 'dart:ui';

/// 尺寸均采用编辑器的“照片短边 1000 px”坐标系。
const shapeKindNames = {
  'line': '线条',
  'rect': '矩形',
  'triangle': '三角形',
  'circle': '圆形',
  'parallelogram': '平行四边形',
  'trapezoid': '梯形',
  'diamond': '菱形',
  'hexagon': '六边形',
};

/// 横竖布局可单独覆盖的形状参数。
const shapeLayoutKeys = [
  'width',
  'height',
  'rotation',
  'radius',
  'skew',
  'inset'
];

/// 样式中各参数允许的范围，保存、导入和分享共用。
const shapeLimits = {
  'width': (1.0, 4000.0),
  'height': (.5, 4000.0),
  'rotation': (0.0, 360.0),
  'radius': (0.0, 2000.0),
  'skew': (0.0, .85),
  'inset': (0.0, .5),
};

class ShapeStyle {
  String kind;
  double width, height, rotation, radius, skew, inset;
  bool fill, split, stroke, pointy, round, dashed;
  int fillColor, fillColor2, strokeColor;
  double fillOpacity, strokeOpacity, strokeWidth;
  ShapeStyle(
      {this.kind = 'rect',
      this.width = 140,
      this.height = 90,
      this.rotation = 0,
      this.radius = 0,
      this.skew = .25,
      this.inset = .25,
      this.fill = true,
      this.split = false,
      this.stroke = false,
      this.pointy = false,
      this.round = false,
      this.dashed = false,
      this.fillColor = 0xff544c41,
      this.fillColor2 = 0xffb89b6a,
      this.strokeColor = 0xff544c41,
      this.fillOpacity = 100,
      this.strokeOpacity = 100,
      this.strokeWidth = 2});

  /// 切换形状种类时给出合理的尺寸，避免线条变成大块或大块变成细线。
  void applyKind(String next) {
    if (!shapeKindNames.containsKey(next) || next == kind) return;
    final wasLine = kind == 'line';
    kind = next;
    if (next == 'line') {
      height = 3;
      stroke = false;
      fill = true;
    } else if (wasLine) {
      height = math.max(24, width * .6);
    }
    if (next == 'circle') radius = 0;
  }

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'width': width,
        'height': height,
        'rotation': rotation,
        'radius': radius,
        'skew': skew,
        'inset': inset,
        'fill': fill,
        'split': split,
        'stroke': stroke,
        'pointy': pointy,
        'round': round,
        'dashed': dashed,
        'fillColor': fillColor,
        'fillColor2': fillColor2,
        'strokeColor': strokeColor,
        'fillOpacity': fillOpacity,
        'strokeOpacity': strokeOpacity,
        'strokeWidth': strokeWidth,
      };

  factory ShapeStyle.fromJson(Map<String, dynamic> j) {
    double n(String key, double fallback, double min, double max) {
      final value = (j[key] as num?)?.toDouble();
      return value == null || !value.isFinite
          ? fallback
          : value.clamp(min, max);
    }

    int color(String key, int fallback) {
      final v = j[key];
      return v is int ? v : fallback;
    }

    var rotation = n('rotation', 0, -100000, 100000) % 360;
    if (rotation < 0) rotation += 360;
    return ShapeStyle(
        kind: shapeKindNames.containsKey(j['kind']) ? j['kind'] : 'rect',
        width: n('width', 140, shapeLimits['width']!.$1, shapeLimits['width']!.$2),
        height:
            n('height', 90, shapeLimits['height']!.$1, shapeLimits['height']!.$2),
        rotation: rotation,
        radius:
            n('radius', 0, shapeLimits['radius']!.$1, shapeLimits['radius']!.$2),
        skew: n('skew', .25, shapeLimits['skew']!.$1, shapeLimits['skew']!.$2),
        inset: n('inset', .25, shapeLimits['inset']!.$1, shapeLimits['inset']!.$2),
        fill: j['fill'] != false,
        split: j['split'] == true,
        stroke: j['stroke'] == true,
        pointy: j['pointy'] == true,
        round: j['round'] == true,
        dashed: j['dashed'] == true,
        fillColor: color('fillColor', 0xff544c41),
        fillColor2: color('fillColor2', 0xffb89b6a),
        strokeColor: color('strokeColor', 0xff544c41),
        fillOpacity: n('fillOpacity', 100, 0, 100),
        strokeOpacity: n('strokeOpacity', 100, 0, 100),
        strokeWidth: n('strokeWidth', 2, .1, 200));
  }
}

// ---------------------------------------------------------------- 几何

double _rad(double degrees) => degrees * math.pi / 180;

/// 把局部坐标（形状中心为原点、未旋转）换算为画布坐标。
Offset shapeToWorld(Offset center, double rotation, Offset local) {
  final c = math.cos(_rad(rotation)), s = math.sin(_rad(rotation));
  return center +
      Offset(local.dx * c - local.dy * s, local.dx * s + local.dy * c);
}

/// 把画布上相对形状中心的向量换算为局部坐标。
Offset shapeToLocal(Offset center, double rotation, Offset world) {
  final c = math.cos(_rad(rotation)), s = math.sin(_rad(rotation));
  final d = world - center;
  return Offset(d.dx * c + d.dy * s, -d.dx * s + d.dy * c);
}

/// 多边形顶点（局部坐标，按顺时针）。圆形与线条返回空列表。
List<Offset> shapeVertices(ShapeStyle s) {
  final w = s.width, h = s.height, hw = w / 2, hh = h / 2;
  switch (s.kind) {
    case 'rect':
      return [Offset(-hw, -hh), Offset(hw, -hh), Offset(hw, hh), Offset(-hw, hh)];
    case 'triangle':
      return [Offset(0, -hh), Offset(hw, hh), Offset(-hw, hh)];
    case 'diamond':
      return [Offset(0, -hh), Offset(hw, 0), Offset(0, hh), Offset(-hw, 0)];
    case 'parallelogram':
      final d = s.skew.clamp(0.0, .85) * w;
      return [
        Offset(-hw + d, -hh),
        Offset(hw, -hh),
        Offset(hw - d, hh),
        Offset(-hw, hh)
      ];
    case 'trapezoid':
      final d = s.inset.clamp(0.0, .49) * w;
      return [
        Offset(-hw + d, -hh),
        Offset(hw - d, -hh),
        Offset(hw, hh),
        Offset(-hw, hh)
      ];
    case 'hexagon':
      if (s.pointy) {
        final d = s.inset.clamp(0.0, .5) * h;
        return [
          Offset(0, -hh),
          Offset(hw, -hh + d),
          Offset(hw, hh - d),
          Offset(0, hh),
          Offset(-hw, hh - d),
          Offset(-hw, -hh + d)
        ];
      }
      final d = s.inset.clamp(0.0, .5) * w;
      return [
        Offset(-hw, 0),
        Offset(-hw + d, -hh),
        Offset(hw - d, -hh),
        Offset(hw, 0),
        Offset(hw - d, hh),
        Offset(-hw + d, hh)
      ];
  }
  return const [];
}

/// 圆角的最大切入长度：最短边的一半。
double shapeMaxCut(ShapeStyle s) {
  final v = shapeVertices(s);
  if (v.isEmpty) return 0;
  var shortest = double.infinity;
  for (var i = 0; i < v.length; i++) {
    shortest = math.min(shortest, (v[(i + 1) % v.length] - v[i]).distance);
  }
  return shortest / 2;
}

Path _roundedPolygon(List<Offset> v, double radius) {
  final n = v.length, cut = radius.clamp(0.0, _maxCut(v));
  final path = Path();
  if (cut < .01) {
    path.moveTo(v[0].dx, v[0].dy);
    for (var i = 1; i < n; i++) {
      path.lineTo(v[i].dx, v[i].dy);
    }
    return path..close();
  }
  for (var i = 0; i < n; i++) {
    final p = v[i], previous = v[(i + n - 1) % n], next = v[(i + 1) % n];
    final a = p + (previous - p) / (previous - p).distance * cut;
    final b = p + (next - p) / (next - p).distance * cut;
    if (i == 0) {
      path.moveTo(a.dx, a.dy);
    } else {
      path.lineTo(a.dx, a.dy);
    }
    path.quadraticBezierTo(p.dx, p.dy, b.dx, b.dy);
  }
  return path..close();
}

double _maxCut(List<Offset> v) {
  var shortest = double.infinity;
  for (var i = 0; i < v.length; i++) {
    shortest = math.min(shortest, (v[(i + 1) % v.length] - v[i]).distance);
  }
  return shortest / 2;
}

/// 局部坐标中的形状路径（未旋转，中心在原点）。
Path shapePath(ShapeStyle s) {
  final w = s.width, h = s.height;
  switch (s.kind) {
    case 'circle':
      return Path()..addOval(Rect.fromCenter(center: Offset.zero, width: w, height: h));
    case 'line':
      final capRadius = s.round ? h / 2 : 0.0;
      if (!s.dashed) {
        return Path()
          ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: w, height: h),
              Radius.circular(math.min(capRadius, w / 2))));
      }
      final dash = math.max(h * 4, 8.0), gap = math.max(h * 2.5, 5.0);
      final path = Path();
      for (var x = -w / 2; x < w / 2 - .001; x += dash + gap) {
        final end = math.min(x + dash, w / 2);
        path.addRRect(RRect.fromRectAndRadius(
            Rect.fromLTRB(x, -h / 2, end, h / 2),
            Radius.circular(math.min(capRadius, (end - x) / 2))));
      }
      return path;
    case 'rect':
      return Path()
        ..addRRect(RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w, height: h),
            Radius.circular(s.radius.clamp(0.0, math.min(w, h) / 2))));
  }
  final v = shapeVertices(s);
  return v.isEmpty ? Path() : _roundedPolygon(v, s.radius);
}

/// 形状在画布上的外接矩形（含旋转与描边），用于选择框、框选与吸附。
Rect shapeBounds(Offset center, ShapeStyle s) {
  final grow = s.stroke && s.kind != 'line' ? s.strokeWidth / 2 : 0.0;
  final hw = s.width / 2 + grow, hh = s.height / 2 + grow;
  Rect? out;
  for (final corner in [Offset(-hw, -hh), Offset(hw, -hh), Offset(hw, hh), Offset(-hw, hh)]) {
    final p = shapeToWorld(center, s.rotation, corner);
    out = out == null
        ? Rect.fromLTWH(p.dx, p.dy, 0, 0)
        : out.expandToInclude(Rect.fromLTWH(p.dx, p.dy, 0, 0));
  }
  return out!;
}

// ---------------------------------------------------------------- 抓点

/// 画布上的可拖动抓点。type：size 调整宽高、radius 调整圆角、adjust 调整形状专有参数。
class ShapeGrip {
  final String type;
  final int sx, sy;
  final Offset local;
  const ShapeGrip(this.type, this.sx, this.sy, this.local);
}

int _radiusVertex(String kind) => switch (kind) {
      'rect' => 2,
      'triangle' => 1,
      'diamond' => 1,
      'parallelogram' => 2,
      'trapezoid' => 2,
      'hexagon' => 3,
      _ => -1
    };

bool shapeHasRadius(ShapeStyle s) => _radiusVertex(s.kind) >= 0;

({Offset from, Offset direction}) _radiusEdge(ShapeStyle s) {
  final v = shapeVertices(s), i = _radiusVertex(s.kind);
  final next = v[(i + 1) % v.length];
  return (from: v[i], direction: (next - v[i]) / (next - v[i]).distance);
}

/// [pad] 为抓点与顶点之间的固定偏移（局部单位），避免圆角为 0 时盖住顶点抓点。
List<ShapeGrip> shapeGrips(ShapeStyle s, double pad) {
  final hw = s.width / 2, hh = s.height / 2;
  final grips = <ShapeGrip>[];
  if (s.kind == 'line') {
    grips.add(ShapeGrip('size', -1, 0, Offset(-hw, 0)));
    grips.add(ShapeGrip('size', 1, 0, Offset(hw, 0)));
    return grips;
  }
  switch (s.kind) {
    case 'parallelogram':
      grips.add(ShapeGrip('adjust', 0, 0,
          Offset(-hw + s.skew.clamp(0.0, .85) * s.width, -hh)));
    case 'trapezoid':
      grips.add(ShapeGrip(
          'adjust', 0, 0, Offset(-hw + s.inset.clamp(0.0, .49) * s.width, -hh)));
    case 'hexagon':
      grips.add(ShapeGrip(
          'adjust',
          0,
          0,
          s.pointy
              ? Offset(hw, -hh + s.inset.clamp(0.0, .5) * s.height)
              : Offset(-hw + s.inset.clamp(0.0, .5) * s.width, -hh)));
  }
  if (shapeHasRadius(s)) {
    final edge = _radiusEdge(s), cut = s.radius.clamp(0.0, shapeMaxCut(s));
    grips.add(ShapeGrip('radius', 0, 0, edge.from + edge.direction * (cut + pad)));
  }
  for (final sy in [-1, 0, 1]) {
    for (final sx in [-1, 0, 1]) {
      if (sx == 0 && sy == 0) continue;
      grips.add(ShapeGrip('size', sx, sy, Offset(sx * hw, sy * hh)));
    }
  }
  return grips;
}

/// 拖动专有参数抓点：[local] 是鼠标在形状局部坐标中的位置。
void dragShapeAdjust(ShapeStyle s, Offset local) {
  switch (s.kind) {
    case 'parallelogram':
      s.skew = ((local.dx + s.width / 2) / s.width).clamp(0.0, .85);
    case 'trapezoid':
      s.inset = ((local.dx + s.width / 2) / s.width).clamp(0.0, .49);
    case 'hexagon':
      s.inset = (s.pointy
              ? (local.dy + s.height / 2) / s.height
              : (local.dx + s.width / 2) / s.width)
          .clamp(0.0, .5);
  }
}

/// 拖动圆角抓点。
void dragShapeRadius(ShapeStyle s, Offset local, double pad) {
  if (!shapeHasRadius(s)) return;
  final edge = _radiusEdge(s);
  final along = (local - edge.from).dx * edge.direction.dx +
      (local - edge.from).dy * edge.direction.dy;
  s.radius = (along - pad).clamp(0.0, shapeMaxCut(s));
}

/// 拖动尺寸抓点：对侧顶点保持不动，返回新的中心与宽高。
({Offset center, double width, double height}) resizeShapeByGrip(
    {required Offset center,
    required double rotation,
    required double width,
    required double height,
    required int sx,
    required int sy,
    required Offset pointer,
    bool keepRatio = false}) {
  final anchor = shapeToWorld(
      center, rotation, Offset(-sx * width / 2, -sy * height / 2));
  final d = shapeToLocal(anchor, rotation, pointer);
  var w = sx == 0 ? width : math.max(1.0, sx * d.dx);
  var h = sy == 0 ? height : math.max(.5, sy * d.dy);
  if (keepRatio && sx != 0 && sy != 0) {
    final k = math.max(w / width, h / height);
    w = width * k;
    h = height * k;
  }
  w = w.clamp(shapeLimits['width']!.$1, shapeLimits['width']!.$2);
  h = h.clamp(shapeLimits['height']!.$1, shapeLimits['height']!.$2);
  final newCenter = shapeToWorld(
      anchor, rotation, Offset(sx == 0 ? 0 : sx * w / 2, sy == 0 ? 0 : sy * h / 2));
  return (center: newCenter, width: w, height: h);
}

/// 旋转抓点相对形状顶部的外移距离（局部单位）。
Offset shapeRotateGrip(ShapeStyle s, double offset) => Offset(
    0,
    -(s.height / 2 + (s.stroke && s.kind != 'line' ? s.strokeWidth / 2 : 0) + offset));
