import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import '../phone-preview/drafts_test.dart' show O, landscape, portrait, square, Spec, apply, px;
import 'package:lumacraft/editor/background_style.dart';
import 'package:lumacraft/editor/builtin_library.dart';
import 'package:lumacraft/editor/palette_style.dart';
import 'package:lumacraft/editor/shape_style.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/style_render.dart';
import 'package:lumacraft/fonts/font_catalog.dart';

// 新增 9 款创意边框草案：生成 drafts.json（内置库格式）与横/竖/方效果图。
// 只写 build/new-presets，不改正式内置库。

class P {
  final String id, name;
  final int background;
  final List<StyleNode> nodes;
  final Map<String, double> Function(O) borders; // 像素：top/right/bottom/left
  final Spec Function(O) spec;
  final void Function(StyleDocument) look;
  P(this.id, this.name, this.background, this.nodes, this.borders, this.spec,
      this.look);
}

StyleNode t(String id, String type, String name,
        {String font = 'manrope',
        double size = 24,
        int color = 0xff2b2b2b,
        String align = 'left',
        double spacing = 0,
        String text = ''}) =>
    StyleNode(
        id: id,
        type: type,
        name: name,
        text: text,
        anchor: 'bottom',
        font: font,
        fontSize: size,
        spacing: spacing,
        color: color,
        align: align);

StyleNode line(String id, String name, int color, {double opacity = 100}) =>
    StyleNode(
        id: id,
        type: 'shape',
        name: name,
        text: '',
        anchor: 'bottom',
        opacity: opacity,
        shape: ShapeStyle(kind: 'line', width: 60, height: 2, fillColor: color));

Map<String, double> sides(double top, double right, double bottom, double left) =>
    {'top': top, 'right': right, 'bottom': bottom, 'left': left};

double canvasW(O o, Map<String, double> b) => o.w + b['left']! + b['right']!;

List<P> presets() {
  const sideWhite = 0xffffffff;
  return [
    // 1 模糊相框·居中
    P('blur-center', '模糊相框·居中', 0xff1c1c1c, [
      t('camera', 'camera', '机型',
          font: 'jost', size: 34, color: 0xfff4f4f4, align: 'center', spacing: 2),
      t('params', 'params', '拍摄参数',
          size: 22, color: 0xffdcdcdc, align: 'center'),
    ], (o) => sides(90, 90, o.key == 'landscape' ? 150 : 170, 90), (o) => {
          'camera': {'x': 50, 'y': 36, 'fs': 34},
          'params': {'x': 50, 'y': 70, 'fs': 22},
        }, (d) {
      d.fill = BackgroundStyle(
          mode: 'blur', blur: 40, brightness: -8, contrast: 104, saturation: 118);
      d.shadow = PhotoShadowStyle(
          enabled: true, color: 0xff000000, angle: 90, distance: 20, size: 4, opacity: 45, feather: 48);
    }),
    // 2 模糊相框·底栏
    P('blur-bar', '模糊相框·底栏', 0xff1c1c1c, [
      t('camera', 'camera', '机型', size: 36, color: 0xfff6f6f6),
      t('place', 'place', '地点', size: 23, color: 0xffd4d4d4),
      t('params', 'params', '拍摄参数', size: 27, color: 0xfff6f6f6, align: 'right'),
      t('time', 'time', '拍摄时间', size: 23, color: 0xffd4d4d4, align: 'right'),
      line('rule', '分隔线', 0xffffffff, opacity: 45),
    ], (o) => sides(60, 60, o.key == 'landscape' ? 150 : 170, 60), (o) {
      final b = sides(60, 60, 0, 60), w = canvasW(o, b);
      return {
        'camera': {'x': px(60, w), 'y': 36, 'fs': 36},
        'place': {'x': px(60, w), 'y': 72, 'fs': 23},
        'params': {'x': px(w - 60, w), 'y': 36, 'fs': 27},
        'time': {'x': px(w - 60, w), 'y': 72, 'fs': 23},
        'rule': {'x': 50, 'y': 54, 'w': 46, 'h': 2, 'rot': 90, 'vis': false},
      };
    }, (d) {
      d.fill = BackgroundStyle(
          mode: 'blur', blur: 34, brightness: -20, contrast: 108, saturation: 118);
      d.shadow = PhotoShadowStyle(
          enabled: true, angle: 90, distance: 16, size: 2, opacity: 40, feather: 44);
    }),
    // 3 宝丽来
    P('polaroid', '宝丽来', 0xfff7f3ea, [
      t('note', 'text', '手写一句',
          font: 'caveat', size: 70, color: 0xff4a4338, align: 'center', text: 'Golden hour'),
      t('time', 'time', '拍摄时间',
          font: 'jost', size: 24, color: 0xff9a9285, align: 'center', spacing: 3),
    ], (o) => sides(50, 50, o.key == 'landscape' ? 170 : 200, 50), (o) => {
          'note': {'x': 50, 'y': 40, 'fs': 70},
          'time': {'x': 50, 'y': 78, 'fs': 24},
        }, (d) {
      d.shadow = PhotoShadowStyle(
          enabled: true, color: 0xff3a3226, angle: 90, distance: 4, opacity: 22, feather: 22);
    }),
    // 4 底片孔洞
    P('film-strip', '底片孔洞', 0xff0e0e0e, [
      t('frame', 'text', '帧号',
          font: 'jost', size: 24, color: 0xffe0a040, text: '▶  24A', spacing: 1),
      t('camera', 'camera', '机型',
          font: 'jost', size: 22, color: 0xffcfcabd, align: 'center', spacing: 3),
      t('params', 'params', '拍摄参数',
          size: 20, color: 0xffe0a040, align: 'right'),
    ], (o) => sides(90, 0, 90, 0), (o) {
      final b = sides(90, 0, 90, 0), w = canvasW(o, b);
      return {
        'frame': {'x': px(48, w), 'y': 28, 'fs': 24},
        'camera': {'x': 50, 'y': 28, 'fs': 22},
        'params': {'x': px(w - 48, w), 'y': 28, 'fs': 20},
      };
    }, (d) {
      d.film = FilmStyle(
          enabled: true,
          orientation: 'horizontal',
          color: 0xffd9d3c3,
          width: 30,
          height: 20,
          gap: 24,
          radius: 5,
          inset: 20);
    }),
    // 5 展览标牌
    P('gallery-label', '展览标牌', 0xfffdfcf9, [
      t('title', 'text', '作品名称',
          font: 'sourceSerif', size: 42, color: 0xff1f1c18, text: 'Untitled'),
      t('sub', 'text', '副标题',
          size: 22, color: 0xff77736b, text: '摄影  2026'),
      line('rule', '短线', 0xffcfc8bb),
      t('params', 'params', '拍摄参数', size: 22, color: 0xff2b2b2b, align: 'right'),
      t('place', 'place', '地点', size: 22, color: 0xff77736b, align: 'right'),
    ], (o) => sides(90, 90, o.key == 'landscape' ? 210 : 240, 90), (o) {
      final b = sides(90, 90, 0, 90), w = canvasW(o, b);
      return {
        'title': {'x': px(90, w), 'y': 24, 'fs': 42},
        'rule': {'x': px(90 + 30, w), 'y': 47, 'w': 60, 'h': 2},
        'sub': {'x': px(90, w), 'y': 64, 'fs': 22},
        'params': {'x': px(w - 90, w), 'y': 24, 'fs': 22},
        'place': {'x': px(w - 90, w), 'y': 64, 'fs': 22},
      };
    }, (d) {
      d.shadow = PhotoShadowStyle(
          enabled: true, color: 0xff3a3226, angle: 90, distance: 8, opacity: 16, feather: 30);
    }),
    // 6 色板边框
    P('palette-strip', '色板边框', 0xfffbfaf7, [
      StyleNode(
          id: 'palette',
          type: 'palette',
          name: '照片色卡',
          anchor: 'bottom',
          palette: PaletteStyle(mode: 'blocks', shape: 'circle', size: 44, gap: 14)),
      t('camera', 'camera', '机型', size: 34, color: 0xff2b2b2b, align: 'right'),
      t('params', 'params', '拍摄参数',
          size: 22, color: 0xff77736b, align: 'right'),
    ], (o) => sides(50, 50, o.key == 'landscape' ? 160 : 190, 50), (o) {
      final b = sides(50, 50, 0, 50), w = canvasW(o, b);
      const paletteWidth = 6 * 44 + 5 * 14.0;
      return {
        'palette': {'x': px(50 + paletteWidth / 2, w), 'y': 50},
        'camera': {'x': px(w - 50, w), 'y': 36, 'fs': 34},
        'params': {'x': px(w - 50, w), 'y': 70, 'fs': 22},
      };
    }, (d) {}),
    // 7 极简黑框
    P('black-minimal', '极简黑框', 0xff0a0a0a, [
      t('params', 'params', '拍摄参数',
          font: 'jost', size: 22, color: 0xffbdbab2, align: 'center', spacing: 4),
    ], (o) => sides(30, 30, 90, 30), (o) => {
          'params': {'x': 50, 'y': 50, 'fs': 22},
        }, (d) {}),
    // 8 暮色渐变
    P('dusk-gradient', '暮色渐变', 0xff1a2646, [
      t('camera', 'camera', '机型',
          font: 'sourceSerif', size: 36, color: 0xfffaf0e6, align: 'center', spacing: 2),
      t('params', 'params', '拍摄参数',
          size: 22, color: 0xfff3e1d4, align: 'center'),
    ], (o) => sides(80, 80, o.key == 'landscape' ? 160 : 180, 80), (o) => {
          'camera': {'x': 50, 'y': 36, 'fs': 36},
          'params': {'x': 50, 'y': 72, 'fs': 22},
        }, (d) {
      d.fill = BackgroundStyle(
          mode: 'gradient', angle: 90, secondColor: 0xffe98a5b);
      d.shadow = PhotoShadowStyle(
          enabled: true, angle: 90, distance: 16, opacity: 38, feather: 46);
    }),
    // 9 双线相框
    P('double-frame', '双线相框', 0xfffaf8f3, [
      StyleNode(
          id: 'frame',
          type: 'shape',
          name: '外框线',
          text: '',
          anchor: 'canvas',
          shape: ShapeStyle(
              kind: 'rect',
              width: 1000,
              height: 1000,
              fill: false,
              stroke: true,
              strokeColor: 0xffc9c2b4,
              strokeWidth: 2.5)),
      t('camera', 'camera', '机型',
          font: 'jost', size: 26, color: 0xff3a362f, align: 'center', spacing: 7),
      t('params', 'params', '拍摄参数',
          size: 20, color: 0xff8a8478, align: 'center', spacing: 1),
    ], (o) => sides(60, 60, o.key == 'landscape' ? 150 : 170, 60), (o) {
      final b = sides(60, 60, o.key == 'landscape' ? 150 : 170, 60);
      final w = canvasW(o, b), h = o.h + b['top']! + b['bottom']!;
      return {
        'frame': {'x': 50, 'y': 50, 'w': w - 44, 'h': h - 44},
        'camera': {'x': 50, 'y': 38, 'fs': 26},
        'params': {'x': 50, 'y': 72, 'fs': 20},
      };
    }, (d) {
      d.shadow = PhotoShadowStyle(
          enabled: true, color: 0xff3a3226, angle: 90, distance: 6, opacity: 14, feather: 26);
    }),
  ];
}

StyleDocument build(P p) {
  Map<String, double> pct(O o) =>
      {for (final e in p.borders(o).entries) e.key: e.value / 10};
  final d = StyleDocument(
      name: p.name,
      background: p.background,
      borders: pct(square),
      nodes: p.nodes.map((n) => n.copy()).toList());
  d.order = d.nodes.map((n) => n.id).toList();
  p.look(d);
  apply(d, p.spec(square));
  d.setAdaptive(true);
  for (final o in [landscape, portrait]) {
    d.switchLayout(o.key);
    d.borders = pct(o);
    apply(d, p.spec(o));
  }
  d.switchLayout('general');
  return d;
}

img.Image warmPhoto(int w, int h) {
  final p = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    final t = y / h;
    final r = (96 + 154 * math.pow(t, 1.3)).round().clamp(0, 255);
    final g = (140 + 66 * math.pow(t, 1.6)).round().clamp(0, 255);
    final b = (208 - 40 * t - 70 * math.pow(t, 2.2)).round().clamp(0, 255);
    for (var x = 0; x < w; x++) {
      p.setPixelRgb(x, y, r, g, b);
    }
  }
  img.fillCircle(p, x: (w * .68).round(), y: (h * .62).round(), radius: (h * .09).round(), color: img.ColorRgb8(255, 226, 170));
  void hills(double base, double amp, double freq, int r, int g, int b) {
    for (var x = 0; x < w; x++) {
      final top = (h * base - amp * h * (math.sin(x / w * freq * math.pi + .6) * .5 + .5)).round();
      for (var y = top; y < h; y++) {
        p.setPixelRgb(x, y, r, g, b);
      }
    }
  }

  hills(.76, .10, 2.6, 168, 98, 110);
  hills(.86, .08, 4.0, 108, 72, 104);
  hills(.95, .05, 6.0, 58, 48, 84);
  return p;
}

void main() {
  testWidgets('新增创意边框 9 款草案效果图', (tester) async {
    await tester.runAsync(() async {
      for (final f in artworkFonts) {
        await (FontLoader(f.family)..addFont(rootBundle.load(f.asset))).load();
      }
      final out = Directory('build/new-presets/out')..createSync(recursive: true);
      final defs = presets();
      final entries = [for (final d in defs) BuiltinEntry(d.id, build(d), folder: 'classic')];
      final library = BuiltinLibrary([const BuiltinFolder('classic', '创意边框')], entries);
      final text = library.encode();
      await File('build/new-presets/drafts.json').writeAsString(text);
      final decoded = BuiltinLibrary.decode(text);
      const fields = {
        'camera': 'Model X Pro',
        'lens': 'Main 24mm f/1.8',
        'focal': '24',
        'aperture': '1.8',
        'shutter': '1/120',
        'iso': '100',
        'place': '杭州 · 西湖',
        'time': '2026:11:05 18:32:07'
      };
      final sheets = <String, List<img.Image>>{};
      for (final o in [landscape, portrait, square]) {
        final photo = warmPhoto(o.w.round(), o.h.round());
        final file = File('${out.path}/photo-${o.key}.jpg');
        await file.writeAsBytes(img.encodeJpg(photo, quality: 95));
        for (final e in decoded.entries) {
          final png = await renderStyledPhoto(file.path, e.style, fields, true);
          await File('${out.path}/${e.id}-${o.key}.png').writeAsBytes(png);
          (sheets[o.key] ??= []).add(img.decodePng(png)!);
        }
      }
      for (final entry in sheets.entries) {
        final cellW = entry.key == 'portrait' ? 380 : 520;
        final cells = [for (final i in entry.value) img.copyResize(i, width: cellW, interpolation: img.Interpolation.cubic)];
        final cellH = cells.map((c) => c.height).reduce(math.max);
        const gap = 24;
        final sheet = img.Image(width: cellW * 3 + gap * 4, height: cellH * 3 + gap * 4);
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
