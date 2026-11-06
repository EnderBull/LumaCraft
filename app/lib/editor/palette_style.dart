/// Dimensions follow the editor's 1000 px photo-short-side coordinate system.
class PaletteStyle {
  String mode, shape, strokeMode;
  double size, height, gap, radius, strokeWidth, strokeGap, strokeOpacity, scale;
  bool stroke, reversed;
  int strokeColor;
  PaletteStyle(
      {this.mode = 'blocks',
      this.shape = 'circle',
      this.size = 34,
      this.height = 34,
      this.gap = 10,
      this.radius = 6,
      this.stroke = false,
      this.strokeMode = 'outer',
      this.strokeWidth = 1,
      this.strokeGap = 0,
      this.strokeOpacity = 100,
      this.strokeColor = 0xffeeeeee,
      this.reversed = false,
      this.scale = 1});
  Map<String, dynamic> toJson() => {
        'mode': mode,
        'shape': shape,
        'size': size,
        'height': height,
        'gap': gap,
        'radius': radius,
        'stroke': stroke,
        'strokeMode': strokeMode,
        'strokeWidth': strokeWidth,
        'strokeGap': strokeGap,
        'strokeOpacity': strokeOpacity,
        'strokeColor': strokeColor,
        'reversed': reversed,
        'scale': scale
      };
  factory PaletteStyle.fromJson(Map<String, dynamic> j) {
    double n(String key, double fallback, double min, double max) {
      final value = (j[key] as num?)?.toDouble();
      return value == null || !value.isFinite
          ? fallback
          : value.clamp(min, max);
    }

    return PaletteStyle(
        mode: j['mode'] == 'strip' ? 'strip' : 'blocks',
        shape: ['circle', 'roundedRect', 'hexagon'].contains(j['shape'])
            ? j['shape']
            : 'circle',
        size: n('size', 34, 4, 300),
        height: n('height', 34, 4, 300),
        gap: n('gap', 10, 0, 100),
        radius: n('radius', 6, 0, 150),
        stroke: j['stroke'] == true,
        strokeMode: j['strokeMode'] == 'each' ? 'each' : 'outer',
        strokeWidth: n('strokeWidth', 1, .1, 30),
        strokeGap: n('strokeGap', 0, 0, 10),
        strokeOpacity: n('strokeOpacity', 100, 0, 100),
        strokeColor: j['strokeColor'] as int? ?? 0xffeeeeee,
        reversed: j['reversed'] == true,
        scale: n('scale', 1, .1, 6));
  }
}
