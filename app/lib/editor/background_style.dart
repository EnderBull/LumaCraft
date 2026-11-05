import 'dart:ui';

double styleNumber(Map<String, dynamic> j, String key, double fallback,
    double min, double max) {
  final value = j[key];
  return value is num && value.isFinite
      ? value.toDouble().clamp(min, max)
      : fallback;
}

/// 边框纹理：按风格分组，'none' 表示不叠加纹理。
const textureGroups = <String, (String, Map<String, String>)>{
  'paper': (
    '纸张',
    {'finePaper': '细纹纸', 'kraft': '牛皮纸', 'xuan': '宣纸', 'watercolor': '水彩纸'}
  ),
  'fabric': ('织物', {'linen': '亚麻布', 'canvas': '帆布'}),
  'simple': ('简洁', {'dots': '细点阵', 'diagonal': '细斜纹', 'grid': '细网格'}),
  'luxe': ('高级', {'marble': '大理石', 'grain': '磨砂颗粒', 'brushed': '拉丝金属'}),
  'cute': ('可爱', {'polka': '波点', 'stars': '小星星', 'gingham': '格纹'}),
  'tech': ('科技', {'circuit': '电路线', 'honeycomb': '蜂窝', 'scanlines': '扫描线'}),
};
final textureKindNames = {
  for (final g in textureGroups.values) ...g.$2
};
String textureGroupOf(String kind) =>
    textureGroups.entries
        .where((e) => e.value.$2.containsKey(kind))
        .firstOrNull
        ?.key ??
    'none';

class BackgroundStyle {
  String mode, gradientType;
  double centerX, centerY, radius;
  int secondColor;
  double angle, blur, brightness, contrast, saturation;
  String texture;
  int textureColor;
  double textureOpacity, textureScale;
  BackgroundStyle(
      {this.mode = 'solid',
      this.gradientType = 'linear',
      this.centerX = 50,
      this.centerY = 50,
      this.radius = 70,
      this.secondColor = 0xffb8cbd0,
      this.angle = 90,
      this.blur = 24,
      this.brightness = 0,
      this.contrast = 100,
      this.saturation = 100,
      this.texture = 'none',
      this.textureColor = 0xff000000,
      this.textureOpacity = 15,
      this.textureScale = 100});
  bool get hasTexture => textureKindNames.containsKey(texture);
  Map<String, dynamic> toJson() => {
        'mode': mode,
        'gradientType': gradientType,
        'centerX': centerX,
        'centerY': centerY,
        'radius': radius,
        'secondColor': secondColor,
        'angle': angle,
        'blur': blur,
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        if (hasTexture) ...{
          'texture': texture,
          'textureColor': textureColor,
          'textureOpacity': textureOpacity,
          'textureScale': textureScale
        }
      };
  factory BackgroundStyle.fromJson(Map<String, dynamic> j) => BackgroundStyle(
      mode: ['solid', 'gradient', 'blur'].contains(j['mode'])
          ? j['mode']
          : 'solid',
      gradientType: j['gradientType'] == 'radial' ? 'radial' : 'linear',
      centerX: styleNumber(j, 'centerX', 50, 0, 100),
      centerY: styleNumber(j, 'centerY', 50, 0, 100),
      radius: styleNumber(j, 'radius', 70, 1, 200),
      secondColor: j['secondColor'] is int ? j['secondColor'] : 0xffb8cbd0,
      angle: styleNumber(j, 'angle', 90, 0, 360),
      blur: styleNumber(j, 'blur', 24, 0, 100),
      brightness: styleNumber(j, 'brightness', 0, -100, 100),
      contrast: styleNumber(j, 'contrast', 100, 0, 200),
      saturation: styleNumber(j, 'saturation', 100, 0, 200),
      texture: textureKindNames.containsKey(j['texture']) ? j['texture'] : 'none',
      textureColor: j['textureColor'] is int ? j['textureColor'] : 0xff000000,
      textureOpacity: styleNumber(j, 'textureOpacity', 15, 0, 100),
      textureScale: styleNumber(j, 'textureScale', 100, 50, 300));
}

const filmOrientations = ['vertical', 'horizontal', 'long'];

class FilmStyle {
  bool enabled;
  String orientation;
  int color;
  double width, height, gap, radius, inset;
  FilmStyle(
      {this.enabled = false,
      this.orientation = 'vertical',
      this.color = 0xffeeeae0,
      this.width = 14,
      this.height = 20,
      this.gap = 14,
      this.radius = 3,
      this.inset = 5});

  /// 孔洞是否排在左右两侧。“沿长边”时竖图在左右、横图和方图在上下。
  bool verticalFor(Rect photo) =>
      orientation == 'vertical' ||
      orientation == 'long' && photo.height > photo.width;

  /// 实际孔洞尺寸。“沿长边”时孔宽、孔高按横图填写，竖图随胶片一起转向。
  Size holeFor(Rect photo) => orientation == 'long' && verticalFor(photo)
      ? Size(height, width)
      : Size(width, height);
  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'orientation': orientation,
        'color': color,
        'width': width,
        'height': height,
        'gap': gap,
        'radius': radius,
        'inset': inset
      };
  factory FilmStyle.fromJson(Map<String, dynamic> j) => FilmStyle(
      enabled: j['enabled'] == true,
      orientation: filmOrientations.contains(j['orientation'])
          ? j['orientation']
          : 'vertical',
      color: j['color'] is int ? j['color'] : 0xffeeeae0,
      width: styleNumber(j, 'width', 14, 2, 100),
      height: styleNumber(j, 'height', 20, 2, 100),
      gap: styleNumber(j, 'gap', 14, 0, 100),
      radius: styleNumber(j, 'radius', 3, 0, 50),
      inset: styleNumber(j, 'inset', 5, 0, 100));
}

class PhotoShadowStyle {
  bool enabled;
  int color;
  double angle, distance, size, opacity, feather;
  PhotoShadowStyle(
      {this.enabled = false,
      this.color = 0xff000000,
      this.angle = 135,
      this.distance = 14,
      this.size = 0,
      this.opacity = 30,
      this.feather = 35});
  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'color': color,
        'angle': angle,
        'distance': distance,
        'size': size,
        'opacity': opacity,
        'feather': feather
      };
  factory PhotoShadowStyle.fromJson(Map<String, dynamic> j) => PhotoShadowStyle(
      enabled: j['enabled'] == true,
      color: j['color'] is int ? j['color'] : 0xff000000,
      angle: styleNumber(j, 'angle', 135, 0, 360),
      distance: styleNumber(j, 'distance', 14, 0, 200),
      size: styleNumber(j, 'size', 0, 0, 100),
      opacity: styleNumber(j, 'opacity', 30, 0, 100),
      feather: styleNumber(j, 'feather', 35, 0, 100));
}
