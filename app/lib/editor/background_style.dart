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
      this.texture = 'finePaper',
      this.textureColor = 0xff000000,
      this.textureOpacity = 15,
      this.textureScale = 100});

  /// 纹理是一种独立的填充方式：底色 + 纹理，不与渐变、照片模糊叠加。
  bool get hasTexture =>
      mode == 'texture' && textureKindNames.containsKey(texture);
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
  factory BackgroundStyle.fromJson(Map<String, dynamic> j) {
    final textured = textureKindNames.containsKey(j['texture']);
    var mode = backgroundModes.contains(j['mode']) ? j['mode'] : 'solid';
    // 0.12.0 把纹理存成“纯色 + texture 字段”，读入时转成纹理填充，画面不变。
    if (mode == 'solid' && textured) mode = 'texture';
    return BackgroundStyle(
      mode: mode,
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
      texture: textured ? j['texture'] : 'finePaper',
      textureColor: j['textureColor'] is int ? j['textureColor'] : 0xff000000,
      textureOpacity: styleNumber(j, 'textureOpacity', 15, 0, 100),
      textureScale: styleNumber(j, 'textureScale', 100, 50, 300));
  }
}

const backgroundModes = ['solid', 'gradient', 'blur', 'texture'];

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

const stampSideNames = {
  'all': '四边',
  'topBottom': '上下',
  'leftRight': '左右',
  'short': '短边'
};
const ticketAxisNames = {'horizontal': '横向（照片下方）', 'vertical': '纵向（右侧票根）'};

/// 邮票打孔：照片外一张“邮票纸”，纸边打半圆孔，纸外露出背景填充。
/// 车票样式在纸上加一条虚线分割线，两端各切一个半圆缺口。
class StampStyle {
  bool enabled, ticket;
  String sides, ticketAxis;
  int paper, ticketColor;
  double diameter, gap, margin;
  double ticketOffset, ticketWidth, ticketDash, ticketGap, notch;
  StampStyle(
      {this.enabled = false,
      this.sides = 'all',
      this.paper = 0xffffffff,
      this.diameter = 18,
      this.gap = 10,
      this.margin = 50,
      this.ticket = false,
      this.ticketAxis = 'horizontal',
      this.ticketOffset = 36,
      this.ticketWidth = 2,
      this.ticketDash = 9,
      this.ticketGap = 6,
      this.ticketColor = 0xff9a948a,
      this.notch = 30});

  /// 打孔的纸边：上、右、下、左。
  List<bool> edgesFor(Rect paper) {
    final landscape = paper.width >= paper.height;
    return switch (sides) {
      'topBottom' => [true, false, true, false],
      'leftRight' => [false, true, false, true],
      'short' => landscape
          ? [false, true, false, true]
          : [true, false, true, false],
      _ => [true, true, true, true],
    };
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'sides': sides,
        'paper': paper,
        'diameter': diameter,
        'gap': gap,
        'margin': margin,
        'ticket': ticket,
        'ticketAxis': ticketAxis,
        'ticketOffset': ticketOffset,
        'ticketWidth': ticketWidth,
        'ticketDash': ticketDash,
        'ticketGap': ticketGap,
        'ticketColor': ticketColor,
        'notch': notch
      };
  factory StampStyle.fromJson(Map<String, dynamic> j) => StampStyle(
      enabled: j['enabled'] == true,
      sides: stampSideNames.containsKey(j['sides']) ? j['sides'] : 'all',
      paper: j['paper'] is int ? j['paper'] : 0xffffffff,
      diameter: styleNumber(j, 'diameter', 18, 2, 120),
      gap: styleNumber(j, 'gap', 10, 0, 120),
      margin: styleNumber(j, 'margin', 50, 0, 400),
      ticket: j['ticket'] == true,
      ticketAxis:
          ticketAxisNames.containsKey(j['ticketAxis']) ? j['ticketAxis'] : 'horizontal',
      ticketOffset: styleNumber(j, 'ticketOffset', 36, 0, 400),
      ticketWidth: styleNumber(j, 'ticketWidth', 2, .5, 20),
      ticketDash: styleNumber(j, 'ticketDash', 9, 1, 100),
      ticketGap: styleNumber(j, 'ticketGap', 6, 0, 100),
      ticketColor: j['ticketColor'] is int ? j['ticketColor'] : 0xff9a948a,
      notch: styleNumber(j, 'notch', 30, 0, 200));
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
