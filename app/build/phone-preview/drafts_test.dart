import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/editor/builtin_library.dart';
import 'package:lumacraft/editor/image_mark.dart';
import 'package:lumacraft/editor/shape_style.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/style_render.dart';
import 'package:lumacraft/fonts/font_catalog.dart';

// 手机经典 6 款草案：生成 drafts.json（内置库格式）与横/竖/方效果图。
// 只写 build/phone-preview，不改正式内置库。

class O {
  final String key;
  final double w, h;
  const O(this.key, this.w, this.h);
}

const landscape = O('landscape', 1500, 1000),
    square = O('general', 1000, 1000),
    portrait = O('portrait', 1000, 1500);

typedef Spec = Map<String, Map<String, dynamic>>;

class Def {
  final String id, name;
  final int background;
  final List<StyleNode> nodes;
  final double Function(O) bottom; // 底边框 px
  final double Function(O) top; // 顶边框 px（几乎都是 0）
  final Spec Function(O) spec;
  Def(this.id, this.name, this.background, this.nodes, this.bottom, this.spec,
      {double Function(O)? top})
      : top = top ?? ((_) => 0);
}

StyleNode txt(String id, String type, String name,
        {String font = 'manrope',
        double size = 24,
        int color = 0xff2b2b2b,
        String align = 'left',
        String anchor = 'bottom',
        String text = ''}) =>
    StyleNode(
        id: id,
        type: type,
        name: name,
        text: text,
        anchor: anchor,
        font: font,
        fontSize: size,
        color: color,
        align: align);

StyleNode logoNode(String id, String data, {String anchor = 'bottom'}) =>
    StyleNode(
        id: id,
        type: 'image',
        name: '品牌标识（占位）',
        text: '',
        anchor: anchor,
        image: ImageMark(
            data: data, filename: 'logo-placeholder.png', width: 56, ratio: 1));

StyleNode lineNode(String id, String name, int color,
        {String anchor = 'bottom'}) =>
    StyleNode(
        id: id,
        type: 'shape',
        name: name,
        text: '',
        anchor: anchor,
        shape: ShapeStyle(
            kind: 'line', width: 50, height: 2, fillColor: color));

StyleNode bandNode(String id) => StyleNode(
    id: id,
    type: 'shape',
    name: '半透明底衬',
    text: '',
    anchor: 'photo',
    shape: ShapeStyle(
        kind: 'rect',
        width: 470,
        height: 100,
        radius: 16,
        fillColor: 0xff000000,
        fillOpacity: 40));

void apply(StyleDocument d, Spec spec) {
  for (final n in d.nodes) {
    final v = spec[n.id];
    if (v == null) continue;
    if (v['x'] != null) n.x = (v['x'] as num).toDouble();
    if (v['y'] != null) n.y = (v['y'] as num).toDouble();
    if (v['fs'] != null) n.fontSize = (v['fs'] as num).toDouble();
    if (v['align'] != null) n.align = v['align'];
    if (v['w'] != null) {
      if (n.type == 'image') n.image.width = (v['w'] as num).toDouble();
      if (n.type == 'shape') n.shape.width = (v['w'] as num).toDouble();
    }
    if (v['h'] != null) n.shape.height = (v['h'] as num).toDouble();
    if (v['rot'] != null) n.shape.rotation = (v['rot'] as num).toDouble();
    if (v['vis'] != null) n.visible = v['vis'];
  }
}

StyleDocument build(Def def) {
  Map<String, double> borders(O o) =>
      {'top': def.top(o) / 10, 'right': 0, 'bottom': def.bottom(o) / 10, 'left': 0};
  final d = StyleDocument(
      name: def.name,
      background: def.background,
      borders: borders(square),
      nodes: def.nodes.map((n) => n.copy()).toList());
  d.order = d.nodes.map((n) => n.id).toList();
  apply(d, def.spec(square));
  d.setAdaptive(true);
  for (final o in [landscape, portrait]) {
    d.switchLayout(o.key);
    d.borders = borders(o);
    apply(d, def.spec(o));
  }
  d.switchLayout('general');
  return d;
}

double px(double v, double total) => v / total * 100;

List<Def> definitions(String lightLogo, String darkLogo) {
  const margin = 52.0;
  Def bar(String id, String name, bool dark) {
    final bg = dark ? 0xff101010 : 0xffffffff;
    final main = dark ? 0xfff2f2f2 : 0xff2b2b2b;
    final sub = dark ? 0xff9b978e : 0xff77736b;
    final rule = dark ? 0xff3b3b3b : 0xffd9d6cf;
    return Def(id, name, bg, [
      txt('camera', 'camera', '机型', size: 36, color: main),
      txt('place', 'place', '地点', size: 24, color: sub),
      txt('params', 'params', '拍摄参数', size: 27, color: main, align: 'right'),
      txt('time', 'time', '拍摄时间', size: 24, color: sub, align: 'right'),
      lineNode('rule', '分隔线', rule),
      logoNode('logo', dark ? darkLogo : lightLogo),
    ], (o) => o.key == 'landscape' ? 128 : 150, (o) {
      const logoW = 72.0;
      final logoX = o.w - margin - logoW / 2;
      final ruleX = o.w - margin - logoW - 30;
      final rightX = ruleX - 30;
      return {
        'camera': {'x': px(margin, o.w), 'y': 34, 'fs': 36},
        'place': {'x': px(margin, o.w), 'y': 71, 'fs': 24},
        'params': {'x': px(rightX, o.w), 'y': 34, 'fs': 27},
        'time': {'x': px(rightX, o.w), 'y': 71, 'fs': 24},
        'rule': {'x': px(ruleX, o.w), 'y': 50, 'w': 66, 'h': 2.5, 'rot': 90},
        'logo': {'x': px(logoX, o.w), 'y': 50, 'w': logoW},
      };
    });
  }

  return [
    bar('phone-bar-white', '底栏参数条·白', false),
    bar('phone-bar-black', '底栏参数条·黑', true),
    Def('phone-overlay', '透明叠加·左下角', 0xffffffff, [
      bandNode('band'),
      logoNode('logo', lightLogo, anchor: 'photo'),
      txt('camera', 'camera', '机型',
          size: 30, color: 0xffffffff, anchor: 'photo'),
      txt('params', 'params', '拍摄参数',
          size: 21, color: 0xffe6e6e6, anchor: 'photo'),
    ], (_) => 0, (o) {
      // 半透明底衬贴在照片左下角，距边 48 px，里面是标识 + 机型 + 参数。
      const bandW = 640.0, bandH = 132.0, edge = 48.0, pad = 24.0, logoW = 64.0;
      final cy = o.h - edge - bandH / 2, textX = edge + pad + logoW + 20;
      return {
        'band': {'x': px(edge + bandW / 2, o.w), 'y': px(cy, o.h), 'w': bandW, 'h': bandH},
        'logo': {'x': px(edge + pad + logoW / 2, o.w), 'y': px(cy, o.h), 'w': logoW},
        'camera': {'x': px(textX, o.w), 'y': px(cy - 22, o.h), 'fs': 30},
        'params': {'x': px(textX, o.w), 'y': px(cy + 24, o.h), 'fs': 21},
      };
    }),
    Def('phone-center', '居中双行', 0xfffafaf8, [
      txt('camera', 'camera', '机型', size: 38, align: 'center'),
      lineNode('rule', '分隔线', 0xffcfcac0),
      txt('params', 'params', '拍摄参数',
          size: 25, color: 0xff77736b, align: 'center'),
    ], (o) => o.key == 'landscape' ? 150 : 180, (o) => {
          'camera': {'x': 50, 'y': 30, 'fs': 38},
          'rule': {'x': 50, 'y': 55, 'w': 56, 'h': 2.5},
          'params': {'x': 50, 'y': 77, 'fs': 25},
        }),
    Def('phone-signature', '签名边框', 0xffffffff, [
      txt('author', 'author', '作者签名',
          font: 'caveat', size: 76, text: 'Alex Chen'),
      txt('camera', 'camera', '机型',
          font: 'jost', size: 30, align: 'right', color: 0xff2b2b2b),
      txt('params', 'params', '拍摄参数',
          size: 23, align: 'right', color: 0xff77736b),
    ], (o) => o.key == 'landscape' ? 160 : 190, (o) => {
          'author': {'x': px(56, o.w), 'y': 50, 'fs': 76},
          'camera': {'x': px(o.w - 56, o.w), 'y': 36, 'fs': 30},
          'params': {'x': px(o.w - 56, o.w), 'y': 68, 'fs': 23},
        }),
    Def('phone-minimal', '极简单行', 0xffffffff, [
      logoNode('logo', lightLogo),
      txt('camera', 'camera', '机型', size: 27),
      txt('params', 'params', '拍摄参数',
          size: 22, align: 'right', color: 0xff77736b),
    ], (_) => 84, (o) => {
          'logo': {'x': px(margin + 20, o.w), 'y': 50, 'w': 40},
          'camera': {'x': px(margin + 40 + 18, o.w), 'y': 50, 'fs': 27},
          'params': {'x': px(o.w - margin, o.w), 'y': 50, 'fs': 22},
        }),
  ];
}
// ------------------------------------------------------------ 占位图与示例照片

Future<Uint8List> placeholderPng(bool dark) async {
  const s = 256.0;
  final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
  final fill = Paint()..color = Color(dark ? 0xff35332f : 0xffdcd8cf);
  canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, s, s), const Radius.circular(60)),
      fill);
  final ink = Color(dark ? 0xff8c867b : 0xff8f8a80);
  final stroke = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 16
    ..strokeCap = StrokeCap.round;
  canvas.drawCircle(const Offset(128, 128), 58, stroke);
  canvas.drawCircle(const Offset(128, 128), 21, Paint()..color = ink);
  canvas.drawCircle(const Offset(184, 72), 9, Paint()..color = ink);
  final image = await recorder.endRecording().toImage(256, 256);
  final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  return data.buffer.asUint8List();
}

img.Image samplePhoto(int w, int h) {
  final p = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    final t = y / h;
    final r = (110 + 120 * t).round(), g = (150 + 70 * t).round(), b = (200 - 60 * t).round();
    for (var x = 0; x < w; x++) {
      p.setPixelRgb(x, y, r, g, b);
    }
  }
  img.fillCircle(p, x: (w * .72).round(), y: (h * .3).round(), radius: (h * .07).round(), color: img.ColorRgb8(255, 236, 190));
  void hills(double base, double amp, double freq, int r, int g, int b) {
    for (var x = 0; x < w; x++) {
      final top = (h * base - amp * h * (math.sin(x / w * freq * math.pi) * .5 + .5)).round();
      for (var y = top; y < h; y++) {
        p.setPixelRgb(x, y, r, g, b);
      }
    }
  }

  hills(.68, .16, 2.4, 92, 112, 120);
  hills(.80, .12, 3.6, 52, 74, 82);
  hills(.92, .06, 5.0, 30, 46, 52);
  return p;
}

void main() {
  testWidgets('手机经典 6 款草案效果图', (tester) async {
    await tester.runAsync(() async {
      for (final f in artworkFonts) {
        await (FontLoader(f.family)..addFont(rootBundle.load(f.asset))).load();
      }
      final out = Directory('build/phone-preview/out')..createSync(recursive: true);
      final light = await placeholderPng(false), dark = await placeholderPng(true);
      await File('build/phone-preview/placeholder-light.png').writeAsBytes(light);
      await File('build/phone-preview/placeholder-dark.png').writeAsBytes(dark);
      final defs = definitions(base64Encode(light), base64Encode(dark));
      final entries = [for (final d in defs) BuiltinEntry(d.id, build(d), folder: 'phone')];
      final library = BuiltinLibrary(
          [const BuiltinFolder('phone', '手机经典')], entries);
      final text = library.encode();
      await File('build/phone-preview/drafts.json').writeAsString(text);
      // 重新解码，确保草案是合法的内置库。
      final decoded = BuiltinLibrary.decode(text);
      const fields = {
        'camera': 'Model X Pro',
        'lens': 'Main 24mm f/1.8',
        'focal': '24',
        'aperture': '1.8',
        'shutter': '1/120',
        'iso': '100',
        'place': '杭州 · 西湖',
        'time': '2026.11.05 18:32'
      };
      final sheets = <String, List<img.Image>>{};
      for (final o in [landscape, portrait, square]) {
        final photo = samplePhoto(o.w.round(), o.h.round());
        final file = File('${out.path}/photo-${o.key}.jpg');
        await file.writeAsBytes(img.encodeJpg(photo, quality: 95));
        for (final e in decoded.entries) {
          final png = await renderStyledPhoto(file.path, e.style, fields, true);
          await File('${out.path}/${e.id}-${o.key}.png').writeAsBytes(png);
          (sheets[o.key] ??= []).add(img.decodePng(png)!);
        }
      }
      // 联系表：每种比例 3 列 × 2 行，缩到统一宽度。
      for (final entry in sheets.entries) {
        final cellW = entry.key == 'portrait' ? 420 : 640;
        final cells = [for (final i in entry.value) img.copyResize(i, width: cellW, interpolation: img.Interpolation.cubic)];
        final cellH = cells.map((c) => c.height).reduce(math.max);
        const gap = 24;
        final sheet = img.Image(width: cellW * 3 + gap * 4, height: cellH * 2 + gap * 3);
        img.fill(sheet, color: img.ColorRgb8(40, 40, 40));
        for (var i = 0; i < cells.length; i++) {
          img.compositeImage(sheet, cells[i],
              dstX: gap + (i % 3) * (cellW + gap), dstY: gap + (i ~/ 3) * (cellH + gap));
        }
        await File('${out.path}/sheet-${entry.key}.png').writeAsBytes(img.encodePng(sheet));
      }
      // ignore: avoid_print
      print('RESULT drafts=${decoded.entries.length} json=${text.length} bytes');
    });
  });
}
