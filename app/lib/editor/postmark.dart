import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'image_mark.dart';

/// 内置邮戳：全部用代码画成矢量，插入时生成透明 PNG 放进图片组件。
const postmarkKinds = {'airmail': '航空邮戳', 'waves': '波浪注销线', 'oval': '椭圆邮戳'};
const postmarkInks = {
  'gray': ('灰', 0xff6b6b6b),
  'blue': ('蓝', 0xff2d5b8e),
  'red': ('红', 0xffb23b2f),
  'black': ('黑', 0xff1d1d1d),
};

/// 邮戳的设计尺寸（单位与成片无关，只决定比例）。
ui.Size postmarkSize(String kind) => switch (kind) {
      'waves' => const ui.Size(900, 300),
      'oval' => const ui.Size(760, 480),
      _ => const ui.Size(1000, 560),
    };

/// 插入画布时的默认宽度（照片短边 = 1000）。
double postmarkWidth(String kind) => switch (kind) {
      'waves' => 260,
      'oval' => 190,
      _ => 280,
    };

/// 从图片文件名认出内置邮戳：postmark-<样式>-<墨色>.png。
(String, String)? postmarkOf(ImageMark mark) {
  final m = RegExp(r'^postmark-(\w+)-(\w+)\.png$').firstMatch(mark.filename);
  if (m == null ||
      !postmarkKinds.containsKey(m[1]) ||
      !postmarkInks.containsKey(m[2])) {
    return null;
  }
  return (m[1]!, m[2]!);
}

Future<ImageMark> buildPostmark(String kind, String ink, {double? width}) async {
  final size = postmarkSize(kind);
  const scale = 1.4;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.scale(scale);
  paintPostmark(canvas, kind, ui.Color(postmarkInks[ink]!.$2));
  final picture = recorder.endRecording();
  final image = await picture.toImage(
      (size.width * scale).round(), (size.height * scale).round());
  picture.dispose();
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return ImageMark(
        data: base64Encode(bytes!.buffer.asUint8List()),
        filename: 'postmark-$kind-$ink.png',
        width: width ?? postmarkWidth(kind),
        ratio: size.width / size.height);
  } finally {
    image.dispose();
  }
}

/// 在设计尺寸坐标系里画邮戳；缩略图和生成 PNG 共用。
void paintPostmark(ui.Canvas canvas, String kind, ui.Color ink) {
  final size = postmarkSize(kind);
  canvas.saveLayer(ui.Offset.zero & size, ui.Paint());
  switch (kind) {
    case 'waves':
      _waves(canvas, ink);
    case 'oval':
      _oval(canvas, ink);
    default:
      _airmail(canvas, ink);
  }
  _wear(canvas, size, kind);
  canvas.restore();
}

ui.Paint _stroke(ui.Color ink, double width) => ui.Paint()
  ..color = ink
  ..style = ui.PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = ui.StrokeCap.round
  ..isAntiAlias = true;

ui.Paragraph _glyph(String text, double size, ui.Color ink,
    {double spacing = 0, ui.FontWeight weight = ui.FontWeight.w600}) {
  final b = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: 'LCJost', fontSize: size, fontWeight: weight))
    ..pushStyle(ui.TextStyle(
        color: ink,
        fontFamily: 'LCJost',
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing))
    ..addText(text);
  return b.build()..layout(const ui.ParagraphConstraints(width: 4000));
}

void _text(ui.Canvas canvas, String text, ui.Offset center, double size,
    ui.Color ink,
    {double spacing = 0}) {
  final p = _glyph(text, size, ink, spacing: spacing);
  canvas.drawParagraph(
      p,
      center -
          ui.Offset((p.maxIntrinsicWidth - spacing) / 2, p.height / 2));
}

/// 沿圆弧排字。上弧字头朝外、顺时针；下弧字头朝内、从左往右读。
void _arcText(ui.Canvas canvas, String text, ui.Offset center, double radius,
    bool top, double size, ui.Color ink,
    {double spacing = 4}) {
  final glyphs = [for (final ch in text.split('')) _glyph(ch, size, ink)];
  final widths = [for (final g in glyphs) g.maxIntrinsicWidth + spacing];
  final span = (widths.fold<double>(0, (a, b) => a + b) - spacing) / radius;
  final mid = top ? -math.pi / 2 : math.pi / 2;
  var a = top ? mid - span / 2 : mid + span / 2;
  for (var i = 0; i < glyphs.length; i++) {
    final g = glyphs[i], half = (g.maxIntrinsicWidth / 2) / radius;
    a += top ? half : -half;
    canvas.save();
    canvas.translate(center.dx + math.cos(a) * radius,
        center.dy + math.sin(a) * radius);
    canvas.rotate(top ? a + math.pi / 2 : a - math.pi / 2);
    canvas.drawParagraph(
        g, ui.Offset(-g.maxIntrinsicWidth / 2, top ? 0 : -g.height));
    canvas.restore();
    a += (top ? 1 : -1) * (half + spacing / radius);
  }
}

ui.Path _star(ui.Offset c, double r) {
  final path = ui.Path();
  for (var i = 0; i < 10; i++) {
    final a = -math.pi / 2 + i * math.pi / 5;
    final rr = i.isEven ? r : r * .42;
    final p = c + ui.Offset(math.cos(a) * rr, math.sin(a) * rr);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

ui.Path _wave(double x0, double x1, double y, double amp, double length) {
  final path = ui.Path()..moveTo(x0, y);
  for (var x = x0; x <= x1; x += 4) {
    path.lineTo(x, y + math.sin((x - x0) / length * 2 * math.pi) * amp);
  }
  return path;
}

void _airmail(ui.Canvas canvas, ui.Color ink) {
  const c = ui.Offset(280, 280);
  canvas.drawCircle(c, 262, _stroke(ink, 11));
  canvas.drawCircle(c, 182, _stroke(ink, 6));
  _arcText(canvas, 'PAR AVION', c, 250, true, 54, ink, spacing: 8);
  _arcText(canvas, 'AIR MAIL', c, 250, false, 54, ink, spacing: 8);
  final fill = ui.Paint()
    ..color = ink
    ..isAntiAlias = true;
  canvas.drawPath(_star(const ui.Offset(52, 280), 15), fill);
  canvas.drawPath(_star(const ui.Offset(508, 280), 15), fill);
  // 飞机：机身、主翼、尾翼，整体抬头约 20°。
  canvas.save();
  canvas.translate(c.dx, c.dy - 34);
  canvas.rotate(-math.pi / 9);
  final plane = ui.Path()
    ..addRRect(ui.RRect.fromRectAndRadius(
        ui.Rect.fromCenter(center: ui.Offset.zero, width: 190, height: 22),
        const ui.Radius.circular(11)))
    ..addPolygon(const [
      ui.Offset(-6, -4),
      ui.Offset(-46, -84),
      ui.Offset(-24, -84),
      ui.Offset(38, -4)
    ], true)
    ..addPolygon(const [
      ui.Offset(-6, 4),
      ui.Offset(-46, 84),
      ui.Offset(-24, 84),
      ui.Offset(38, 4)
    ], true)
    ..addPolygon(const [
      ui.Offset(-78, -4),
      ui.Offset(-98, -40),
      ui.Offset(-84, -40),
      ui.Offset(-58, -4)
    ], true)
    ..addPolygon(const [
      ui.Offset(-78, 4),
      ui.Offset(-98, 40),
      ui.Offset(-84, 40),
      ui.Offset(-58, 4)
    ], true);
  canvas.drawPath(plane, fill);
  canvas.restore();
  _text(canvas, 'LUMACRAFT', c + const ui.Offset(0, 92), 36, ink, spacing: 6);
  for (var i = 0; i < 6; i++) {
    final y = 120 + i * 64.0;
    canvas.drawPath(_wave(i.isEven ? 470 : 500, 990, y, 15, 120),
        _stroke(ink, 10));
  }
}

void _waves(ui.Canvas canvas, ui.Color ink) {
  for (var i = 0; i < 5; i++) {
    canvas.drawPath(_wave(20, 880, 50 + i * 50.0, 16, 140), _stroke(ink, 9));
  }
  final fill = ui.Paint()..color = ink;
  final box = ui.RRect.fromRectAndRadius(
      ui.Rect.fromCenter(
          center: const ui.Offset(450, 150), width: 560, height: 150),
      const ui.Radius.circular(14));
  canvas.drawRRect(box,
      ui.Paint()..blendMode = ui.BlendMode.clear);
  canvas.drawRRect(box, _stroke(ink, 9));
  canvas.drawPath(_star(const ui.Offset(222, 150), 18), fill);
  canvas.drawPath(_star(const ui.Offset(678, 150), 18), fill);
  _text(canvas, 'POSTED', const ui.Offset(450, 150), 80, ink, spacing: 10);
}

void _oval(ui.Canvas canvas, ui.Color ink) {
  const outer = ui.Rect.fromLTWH(14, 14, 732, 452);
  canvas.drawOval(outer, _stroke(ink, 11));
  canvas.drawOval(outer.deflate(30), _stroke(ink, 5));
  _text(canvas, 'FIRST CLASS', const ui.Offset(380, 128), 50, ink, spacing: 7);
  canvas.drawLine(const ui.Offset(150, 182), const ui.Offset(610, 182),
      _stroke(ink, 5));
  canvas.drawLine(const ui.Offset(150, 300), const ui.Offset(610, 300),
      _stroke(ink, 5));
  _text(canvas, 'PHOTO POST', const ui.Offset(380, 241), 66, ink,
      spacing: 6);
  final fill = ui.Paint()..color = ink;
  for (var i = -1; i <= 1; i++) {
    canvas.drawPath(_star(ui.Offset(380 + i * 54.0, 360), 15), fill);
  }
}

/// 做旧：随机擦掉一些小点和细纹，让墨迹像真的盖上去一样不均匀。
void _wear(ui.Canvas canvas, ui.Size size, String kind) {
  final r = math.Random(
      kind.codeUnits.fold<int>(11, (a, c) => (a * 31 + c) & 0x7fffffff));
  final erase = ui.Paint()..blendMode = ui.BlendMode.dstOut;
  for (var i = 0; i < 420; i++) {
    erase.color = ui.Color.fromRGBO(0, 0, 0, .35 + r.nextDouble() * .65);
    canvas.drawCircle(
        ui.Offset(r.nextDouble() * size.width, r.nextDouble() * size.height),
        .8 + math.pow(r.nextDouble(), 3) * 7,
        erase);
  }
  final streak = ui.Paint()
    ..blendMode = ui.BlendMode.dstOut
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round;
  for (var i = 0; i < 18; i++) {
    final a = ui.Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
    final angle = r.nextDouble() * math.pi;
    final length = 30 + r.nextDouble() * 120;
    streak
      ..color = ui.Color.fromRGBO(0, 0, 0, .25 + r.nextDouble() * .4)
      ..strokeWidth = 1 + r.nextDouble() * 3;
    canvas.drawLine(
        a, a + ui.Offset(math.cos(angle), math.sin(angle)) * length, streak);
  }
}
