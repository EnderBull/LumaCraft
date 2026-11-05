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

// 新增创意边框草案（1–9 号首批，10–27 号文艺 / 纹理 / 色卡）：生成 drafts.json（内置库格式）与横/竖/方效果图。
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
    // 4 底片孔洞：孔洞沿长边；竖图只留左右孔洞边，文字直接叠在照片底部。
    P('film-strip', '底片孔洞', 0xff0e0e0e, [
      t('frame', 'text', '帧号',
          font: 'jost', size: 24, color: 0xffe0a040, text: '▶  24A', spacing: 1),
      t('camera', 'camera', '机型',
          font: 'jost', size: 22, color: 0xffcfcabd, align: 'center', spacing: 3),
      t('params', 'params', '拍摄参数',
          size: 20, color: 0xffe0a040, align: 'right'),
    ], (o) => o.key == 'portrait' ? sides(0, 90, 0, 90) : sides(90, 0, 90, 0),
        (o) {
      if (o.key == 'portrait') {
        final y = px(o.h - 46, o.h);
        return {
          'frame': {'anchor': 'photo', 'x': px(44, o.w), 'y': y, 'fs': 24},
          'camera': {'anchor': 'photo', 'x': 50, 'y': y, 'fs': 22},
          'params': {'anchor': 'photo', 'x': px(o.w - 44, o.w), 'y': y, 'fs': 20},
        };
      }
      final b = sides(90, 0, 90, 0), w = canvasW(o, b);
      return {
        'frame': {'anchor': 'bottom', 'x': px(48, w), 'y': 28, 'fs': 24},
        'camera': {'anchor': 'bottom', 'x': 50, 'y': 28, 'fs': 22},
        'params': {'anchor': 'bottom', 'x': px(w - 48, w), 'y': 28, 'fs': 20},
      };
    }, (d) {
      d.film = FilmStyle(
          enabled: true,
          orientation: 'long',
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
    ...texturePresets(),
  ];
}

StyleNode box(String id, String name,
        {String anchor = 'bottom',
        double w = 100,
        double h = 100,
        double radius = 0,
        double rotation = 0,
        int? fill,
        double fillOpacity = 100,
        int? stroke,
        double strokeWidth = 2,
        double opacity = 100}) =>
    StyleNode(
        id: id,
        type: 'shape',
        name: name,
        text: '',
        anchor: anchor,
        opacity: opacity,
        shape: ShapeStyle(
            kind: 'rect',
            width: w,
            height: h,
            radius: radius,
            rotation: rotation,
            fill: fill != null,
            fillColor: fill ?? 0xff000000,
            fillOpacity: fillOpacity,
            stroke: stroke != null,
            strokeColor: stroke ?? 0xff000000,
            strokeWidth: strokeWidth));

StyleNode pal(String id, PaletteStyle p, {double opacity = 100}) => StyleNode(
    id: id, type: 'palette', name: '照片色卡', anchor: 'bottom', opacity: opacity, palette: p);

BackgroundStyle textured(String kind, int color, double opacity,
        {double scale = 100}) =>
    BackgroundStyle(
        texture: kind,
        textureColor: color,
        textureOpacity: opacity,
        textureScale: scale);

/// 竖图底边比横图、方图略高，给文字留足呼吸感。
double tall(O o, double landscapeValue, double portraitValue) =>
    o.key == 'portrait' ? portraitValue : landscapeValue;

List<P> texturePresets() => [
      // 10 宣纸题印
      P('xuan-seal', '宣纸题印', 0xfff3ecdc, [
        t('title', 'text', '题字',
            font: 'wenkai', size: 42, color: 0xff3a332a, spacing: 4, text: '山色有无中'),
        t('place', 'place', '地点', font: 'wenkai', size: 22, color: 0xff8a7f6d),
        t('params', 'params', '拍摄参数',
            font: 'sourceSerif', size: 20, color: 0xff8a7f6d, align: 'right'),
        t('time', 'time', '拍摄时间',
            font: 'sourceSerif', size: 20, color: 0xff8a7f6d, align: 'right'),
        box('seal', '印章', w: 56, h: 56, radius: 6, fill: 0xffb3362c),
        t('sealText', 'text', '印文',
            font: 'sourceSerif', size: 28, color: 0xfff6e9dc, align: 'center', text: '光'),
      ], (o) => sides(70, 70, tall(o, 190, 220), 70), (o) {
        final w = canvasW(o, sides(70, 70, 0, 70)), seal = w - 70 - 28;
        return {
          'title': {'x': px(70, w), 'y': 38},
          'place': {'x': px(70, w), 'y': 70},
          'params': {'x': px(seal - 28 - 26, w), 'y': 38},
          'time': {'x': px(seal - 28 - 26, w), 'y': 70},
          'seal': {'x': px(seal, w), 'y': 54},
          'sealText': {'x': px(seal, w), 'y': 54},
        };
      }, (d) => d.fill = textured('xuan', 0xff8a7350, 34)),
      // 11 牛皮纸信笺
      P('kraft-letter', '牛皮纸信笺', 0xffc9a57a, [
        t('note', 'text', '手写一句',
            font: 'caveat', size: 66, color: 0xff3b2a1a, text: 'Dear summer,'),
        StyleNode(
            id: 'rule',
            type: 'shape',
            name: '虚线',
            text: '',
            anchor: 'bottom',
            opacity: 55,
            shape: ShapeStyle(
                kind: 'line', width: 360, height: 2, dashed: true, fillColor: 0xff5a3d22)),
        t('params', 'params', '拍摄参数',
            font: 'jost', size: 20, color: 0xff3b2a1a, align: 'right', spacing: 1),
        t('place', 'place', '地点', size: 20, color: 0xff6b4c2e, align: 'right'),
        box('stamp', '邮戳框', w: 104, h: 76, radius: 4, stroke: 0xff5a3d22),
        t('stampText', 'text', '邮戳文字',
            font: 'jost', size: 15, color: 0xff5a3d22, align: 'center', spacing: 2, text: 'PAR AVION'),
      ], (o) => sides(60, 60, tall(o, 180, 210), 60), (o) {
        final w = canvasW(o, sides(60, 60, 0, 60)), stamp = w - 60 - 52;
        return {
          'note': {'x': px(60, w), 'y': 40},
          'rule': {'x': px(60 + 180, w), 'y': 74, 'w': 360, 'h': 2},
          'stamp': {'x': px(stamp, w), 'y': 50},
          'stampText': {'x': px(stamp, w), 'y': 50},
          'params': {'x': px(stamp - 52 - 28, w), 'y': 36},
          'place': {'x': px(stamp - 52 - 28, w), 'y': 66},
        };
      }, (d) => d.fill = textured('kraft', 0xff5a3d22, 38)),
      // 12 水彩手账
      P('watercolor-journal', '水彩手账', 0xfffbf8f2, [
        t('title', 'text', '手写标题',
            font: 'wenkai', size: 40, color: 0xff4a4338, text: '今天的风很温柔'),
        t('time', 'time', '拍摄时间', font: 'wenkai', size: 22, color: 0xff9a9285),
        pal('palette', PaletteStyle(shape: 'circle', size: 42, gap: 12), opacity: 88),
      ], (o) => sides(60, 60, tall(o, 190, 220), 60), (o) {
        final w = canvasW(o, sides(60, 60, 0, 60));
        return {
          'title': {'x': px(60, w), 'y': 38},
          'time': {'x': px(60, w), 'y': 70},
          'palette': {'x': px(w - 60 - 156, w), 'y': 52},
        };
      }, (d) => d.fill = textured('watercolor', 0xff7a6a55, 40)),
      // 13 亚麻画布
      P('linen-canvas', '亚麻画布', 0xffe8e1d3, [
        t('title', 'text', '作品名称',
            font: 'playfair', size: 42, color: 0xff2e2a24, align: 'center', text: 'Still Life'),
        t('params', 'params', '拍摄参数',
            font: 'sourceSans', size: 19, color: 0xff7a6f5c, align: 'center', spacing: 2),
      ], (o) => sides(100, 100, tall(o, 210, 240), 100), (o) => {
            'title': {'x': 50, 'y': 40},
            'params': {'x': 50, 'y': 72},
          }, (d) {
        d.fill = textured('linen', 0xff6a5d48, 32);
        d.shadow = PhotoShadowStyle(
            enabled: true, color: 0xff3a3226, angle: 90, distance: 10, opacity: 22, feather: 30);
      }),
      // 14 诗集扉页
      P('poetry-page', '诗集扉页', 0xfffdfbf6, [
        t('chapter', 'text', '章节',
            font: 'jost', size: 17, color: 0xff9a9285, align: 'center', spacing: 6, text: 'CHAPTER  I'),
        t('poem', 'text', '诗句',
            font: 'sourceSerif', size: 34, color: 0xff2b2722, align: 'center', spacing: 3, text: '我们在光里走了很远'),
        line('rule', '短线', 0xffc9c0ae),
        t('params', 'params', '拍摄参数',
            font: 'jost', size: 17, color: 0xff9a9285, align: 'center', spacing: 2),
      ], (o) => sides(120, 120, tall(o, 290, 330), 120), (o) => {
            'chapter': {'x': 50, 'y': 18},
            'poem': {'x': 50, 'y': 40},
            'rule': {'x': 50, 'y': 60, 'w': 40, 'h': 2},
            'params': {'x': 50, 'y': 77},
          }, (d) => d.fill = textured('finePaper', 0xff6b5a40, 28)),
      // 15 色带边框：照片下方一条通栏色带
      P('palette-band', '色带边框', 0xffffffff, [
        pal('palette', PaletteStyle(mode: 'strip', size: 250, height: 14, radius: 0)),
        t('camera', 'camera', '机型', size: 30, color: 0xff2b2b2b),
        t('params', 'params', '拍摄参数', size: 21, color: 0xff77736b, align: 'right'),
      ], (o) => sides(40, 40, tall(o, 150, 170), 40), (o) {
        final w = canvasW(o, sides(40, 40, 0, 40)), bottom = tall(o, 150, 170);
        return {
          'palette': {'x': 50, 'y': px(26, bottom), 'ps': o.w / 6},
          'camera': {'x': px(40, w), 'y': 62},
          'params': {'x': px(w - 40, w), 'y': 62},
        };
      }, (d) {}),
      // 16 色卡标签
      P('palette-card', '色卡标签', 0xfff7f5f0, [
        pal('palette',
            PaletteStyle(shape: 'roundedRect', size: 58, height: 82, radius: 6, gap: 8)),
        t('label', 'text', '色卡编号',
            font: 'jost', size: 15, color: 0xff8a8478, spacing: 3, text: 'COLOR  No.06'),
        t('camera', 'camera', '机型', font: 'jost', size: 30, color: 0xff2b2b2b, align: 'right'),
        t('params', 'params', '拍摄参数',
            font: 'sourceSans', size: 20, color: 0xff77736b, align: 'right'),
      ], (o) => sides(50, 50, tall(o, 230, 260), 50), (o) {
        final w = canvasW(o, sides(50, 50, 0, 50));
        return {
          'palette': {'x': px(50 + 194, w), 'y': 40},
          'label': {'x': px(50, w), 'y': 80},
          'camera': {'x': px(w - 50, w), 'y': 38},
          'params': {'x': px(w - 50, w), 'y': 60},
        };
      }, (d) => d.fill = textured('dots', 0xff2b2b2b, 14)),
      // 17 模糊色卡
      P('blur-palette', '模糊色卡', 0xff1c1c1c, [
        pal('palette',
            PaletteStyle(
                shape: 'circle',
                size: 34,
                gap: 16,
                stroke: true,
                strokeColor: 0xffffffff,
                strokeWidth: 1.5,
                strokeGap: 3)),
        t('params', 'params', '拍摄参数',
            size: 21, color: 0xfff2f2f2, align: 'center', spacing: 1),
      ], (o) => sides(70, 70, tall(o, 180, 210), 70), (o) => {
            'palette': {'x': 50, 'y': 40},
            'params': {'x': 50, 'y': 74},
          }, (d) {
        d.fill = BackgroundStyle(
            mode: 'blur', blur: 38, brightness: -12, contrast: 104, saturation: 115);
        d.shadow = PhotoShadowStyle(
            enabled: true, angle: 90, distance: 18, size: 2, opacity: 40, feather: 46);
      }),
      // 18 波点糖果：照片外一圈白色贴纸边
      P('candy-polka', '波点糖果', 0xfff9d8d6, [
        box('ring', '白色贴纸边', anchor: 'photo', stroke: 0xffffffff, strokeWidth: 16),
        t('title', 'text', '一句话',
            font: 'smiley', size: 46, color: 0xffd9576a, align: 'center', text: '今天也要开心呀'),
        t('time', 'time', '拍摄时间',
            font: 'smiley', size: 22, color: 0xffd98a95, align: 'center', spacing: 1),
      ], (o) => sides(70, 70, tall(o, 190, 220), 70), (o) => {
            'ring': {'x': 50, 'y': 50, 'w': o.w + 16, 'h': o.h + 16},
            'title': {'x': 50, 'y': 42},
            'time': {'x': 50, 'y': 73},
          }, (d) => d.fill = textured('polka', 0xffffffff, 70)),
      // 19 星星便签：照片上角贴两条和纸胶带
      P('star-note', '星星便签', 0xffcfe3f5, [
        box('tapeLeft', '胶带·左',
            anchor: 'photo', w: 150, h: 44, rotation: 315, fill: 0xfffff4d6, fillOpacity: 80),
        box('tapeRight', '胶带·右',
            anchor: 'photo', w: 150, h: 44, rotation: 45, fill: 0xfffff4d6, fillOpacity: 80),
        t('note', 'text', '手写一句',
            font: 'caveat', size: 62, color: 0xff3b5a80, text: 'little stars'),
        t('camera', 'camera', '机型',
            font: 'jost', size: 24, color: 0xff3b5a80, align: 'right', spacing: 2),
        t('params', 'params', '拍摄参数',
            font: 'jost', size: 18, color: 0xff6a87aa, align: 'right'),
      ], (o) => sides(60, 60, tall(o, 180, 210), 60), (o) {
        final w = canvasW(o, sides(60, 60, 0, 60));
        return {
          // 胶带转 45° 后外接框半宽约 69，离照片角 14 才能完整留在画布内。
          'tapeLeft': {'x': px(14, o.w), 'y': px(14, o.h)},
          'tapeRight': {'x': px(o.w - 14, o.w), 'y': px(14, o.h)},
          'note': {'x': px(60, w), 'y': 48},
          'camera': {'x': px(w - 60, w), 'y': 38},
          'params': {'x': px(w - 60, w), 'y': 66},
        };
      }, (d) => d.fill = textured('stars', 0xffffffff, 85)),
      // 20 蜂窝科技
      P('tech-honeycomb', '蜂窝科技', 0xff111418, [
        box('accent', '强调条', w: 5, h: 64, radius: 2.5, fill: 0xff6aa8ff),
        t('camera', 'camera', '机型',
            font: 'jost', size: 32, color: 0xffe8f1ff, spacing: 3),
        t('params', 'params', '拍摄参数',
            font: 'jost', size: 19, color: 0xff6aa8ff, spacing: 2),
        t('time', 'time', '拍摄时间',
            font: 'jost', size: 18, color: 0xff7f8ea3, align: 'right', spacing: 1),
        t('place', 'place', '地点',
            font: 'sourceSans', size: 18, color: 0xff7f8ea3, align: 'right'),
      ], (o) => sides(50, 50, tall(o, 170, 200), 50), (o) {
        final w = canvasW(o, sides(50, 50, 0, 50));
        return {
          'accent': {'x': px(52.5, w), 'y': 51},
          'camera': {'x': px(72, w), 'y': 36},
          'params': {'x': px(72, w), 'y': 66},
          'time': {'x': px(w - 50, w), 'y': 36},
          'place': {'x': px(w - 50, w), 'y': 66},
        };
      }, (d) => d.fill = textured('honeycomb', 0xff6aa8ff, 30)),
      // 21 扫描线 HUD：照片内一圈细取景框 + REC 标记
      P('scanline-hud', '扫描线 HUD', 0xff0b0f14, [
        box('viewfinder', '取景框',
            anchor: 'photo', stroke: 0xff7cf0ff, strokeWidth: 2, opacity: 55),
        t('rec', 'text', '录制标记',
            font: 'jost', size: 20, color: 0xffff4d5e, spacing: 2, text: '● REC'),
        t('params', 'params', '拍摄参数',
            font: 'manrope', size: 22, color: 0xff7cf0ff, spacing: 3),
        t('place', 'place', '地点',
            font: 'sourceSans', size: 17, color: 0xff4f8a96),
        t('camera', 'camera', '机型',
            font: 'jost', size: 24, color: 0xffe6fbff, align: 'right', spacing: 4),
        t('time', 'time', '拍摄时间',
            font: 'manrope', size: 17, color: 0xff4f8a96, align: 'right', spacing: 2),
      ], (o) => sides(40, 40, tall(o, 150, 170), 40), (o) {
        final w = canvasW(o, sides(40, 40, 0, 40));
        return {
          'viewfinder': {'x': 50, 'y': 50, 'w': o.w - 60, 'h': o.h - 60},
          'rec': {'anchor': 'photo', 'x': px(56, o.w), 'y': px(58, o.h)},
          'params': {'x': px(40, w), 'y': 38},
          'place': {'x': px(40, w), 'y': 66},
          'camera': {'x': px(w - 40, w), 'y': 38},
          'time': {'x': px(w - 40, w), 'y': 66},
        };
      }, (d) => d.fill = textured('scanlines', 0xff7cf0ff, 12)),
      // 22 大理石画廊：照片外一圈金色细框
      P('marble-gallery', '大理石画廊', 0xfff4f2ef, [
        box('goldFrame', '金色细框', anchor: 'photo', stroke: 0xffb89b5e, strokeWidth: 2),
        t('title', 'text', '作品名称',
            font: 'playfair', size: 40, color: 0xff2b2722, align: 'center', spacing: 2, text: 'Marble Hall'),
        line('rule', '金色短线', 0xffb89b5e),
        t('params', 'params', '拍摄参数',
            font: 'sourceSans', size: 18, color: 0xff8a8478, align: 'center', spacing: 3),
      ], (o) => sides(90, 90, tall(o, 220, 250), 90), (o) => {
            'goldFrame': {'x': 50, 'y': 50, 'w': o.w + 36, 'h': o.h + 36},
            'title': {'x': 50, 'y': 42},
            'rule': {'x': 50, 'y': 61, 'w': 56, 'h': 2},
            'params': {'x': 50, 'y': 77},
          }, (d) {
        d.fill = textured('marble', 0xff5b5650, 45, scale: 150);
        d.shadow = PhotoShadowStyle(
            enabled: true, color: 0xff3a3226, angle: 90, distance: 8, opacity: 18, feather: 30);
      }),
      // 23 网格极简
      P('grid-minimal', '网格极简', 0xfffbfbfa, [
        t('camera', 'camera', '机型', font: 'manrope', size: 30, color: 0xff2b2b2b),
        t('params', 'params', '拍摄参数', font: 'manrope', size: 20, color: 0xff8a8a8a),
        pal('palette', PaletteStyle(mode: 'strip', size: 30, height: 10, radius: 5)),
        t('time', 'time', '拍摄时间',
            font: 'manrope', size: 18, color: 0xff8a8a8a, align: 'right'),
      ], (o) => sides(60, 60, tall(o, 170, 190), 60), (o) {
        final w = canvasW(o, sides(60, 60, 0, 60));
        return {
          'camera': {'x': px(60, w), 'y': 38},
          'params': {'x': px(60, w), 'y': 66},
          'palette': {'x': px(w - 60 - 90, w), 'y': 38},
          'time': {'x': px(w - 60, w), 'y': 66},
        };
      }, (d) => d.fill = textured('grid', 0xff2b2b2b, 9)),
      // 24 野餐格纹：格纹上放一张白色标签卡
      P('picnic-gingham', '野餐格纹', 0xfffdfbf6, [
        box('card', '标签卡', w: 520, h: 124, radius: 14, fill: 0xfffffdf8),
        t('note', 'text', '手写一句',
            font: 'caveat', size: 52, color: 0xffb24a4a, align: 'center', text: 'Picnic day'),
        t('time', 'time', '拍摄时间',
            font: 'jost', size: 16, color: 0xffb98a7a, align: 'center', spacing: 2),
      ], (o) => sides(60, 60, tall(o, 200, 230), 60), (o) {
        final bottom = tall(o, 200, 230), center = bottom / 2;
        return {
          'card': {'x': 50, 'y': 50},
          'note': {'x': 50, 'y': px(center - 22, bottom)},
          'time': {'x': 50, 'y': px(center + 34, bottom)},
        };
      }, (d) {
        d.fill = textured('gingham', 0xffd96c6c, 26);
        d.shadow = PhotoShadowStyle(
            enabled: true, color: 0xff6a2a2a, angle: 90, distance: 6, opacity: 16, feather: 24);
      }),
      // 25 电路板
      P('circuit-board', '电路板', 0xff0d1b2a, [
        t('camera', 'camera', '机型',
            font: 'jost', size: 30, color: 0xffe6fffb, spacing: 3),
        t('params', 'params', '拍摄参数',
            font: 'jost', size: 19, color: 0xff3ad1c7, spacing: 2),
        pal('palette', PaletteStyle(shape: 'hexagon', size: 16, gap: 8, radius: 2)),
      ], (o) => sides(50, 50, tall(o, 170, 200), 50), (o) {
        final w = canvasW(o, sides(50, 50, 0, 50));
        final width = 6 * math.sqrt(3) * 16 + 5 * 8;
        return {
          'camera': {'x': px(50, w), 'y': 38},
          'params': {'x': px(50, w), 'y': 66},
          'palette': {'x': px(w - 50 - width / 2, w), 'y': 52},
        };
      }, (d) => d.fill = textured('circuit', 0xff3ad1c7, 40)),
      // 26 拉丝金属
      P('brushed-metal', '拉丝金属', 0xffb9bcc0, [
        t('camera', 'camera', '机型',
            font: 'jost', size: 30, color: 0xff1f2226, spacing: 5),
        t('params', 'params', '拍摄参数',
            font: 'manrope', size: 20, color: 0xff2f3236, align: 'right'),
      ], (o) => sides(50, 50, tall(o, 140, 160), 50), (o) {
        final w = canvasW(o, sides(50, 50, 0, 50));
        return {
          'camera': {'x': px(50, w), 'y': 50},
          'params': {'x': px(w - 50, w), 'y': 50},
        };
      }, (d) {
        d.fill = textured('brushed', 0xff3a3d42, 30);
        d.shadow = PhotoShadowStyle(
            enabled: true, angle: 90, distance: 10, size: 1, opacity: 30, feather: 30);
      }),
      // 27 磨砂黑卡
      P('frosted-black', '磨砂黑卡', 0xff1b1b1d, [
        t('title', 'text', '标题',
            font: 'sourceSerif', size: 36, color: 0xfff1ede4, align: 'center', spacing: 8, text: '夜 归'),
        line('rule', '金色短线', 0xffb89b5e),
        t('params', 'params', '拍摄参数',
            font: 'jost', size: 17, color: 0xff9b978e, align: 'center', spacing: 3),
      ], (o) => sides(70, 70, tall(o, 200, 230), 70), (o) => {
            'title': {'x': 50, 'y': 38},
            'rule': {'x': 50, 'y': 60, 'w': 36, 'h': 2},
            'params': {'x': 50, 'y': 76},
          }, (d) => d.fill = textured('grain', 0xffffffff, 18)),
    ];

void applyMore(StyleDocument d, Spec spec) {
  apply(d, spec);
  for (final n in d.nodes) {
    final v = spec[n.id];
    if (v == null) continue;
    if (v['anchor'] != null) n.anchor = v['anchor'];
    if (v['ps'] != null) n.palette.size = (v['ps'] as num).toDouble();
  }
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
  applyMore(d, p.spec(square));
  d.setAdaptive(true);
  for (final o in [landscape, portrait]) {
    d.switchLayout(o.key);
    d.borders = pct(o);
    applyMore(d, p.spec(o));
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
  testWidgets('新增创意边框草案效果图', (tester) async {
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
      // 联系表：每 9 款一张（3×3），第 1 张是 1–9 号，第 2 张 10–18 号，第 3 张 19–27 号。
      for (final entry in sheets.entries) {
        final cellW = entry.key == 'portrait' ? 380 : 520;
        for (var page = 0; page * 9 < entry.value.length; page++) {
          final cells = [
            for (final i in entry.value.skip(page * 9).take(9))
              img.copyResize(i, width: cellW, interpolation: img.Interpolation.cubic)
          ];
          final cellH = cells.map((c) => c.height).reduce(math.max);
          const gap = 24;
          final rows = (cells.length / 3).ceil();
          final sheet = img.Image(width: cellW * 3 + gap * 4, height: cellH * rows + gap * (rows + 1));
          img.fill(sheet, color: img.ColorRgb8(40, 40, 40));
          for (var i = 0; i < cells.length; i++) {
            img.compositeImage(sheet, cells[i],
                dstX: gap + (i % 3) * (cellW + gap), dstY: gap + (i ~/ 3) * (cellH + gap));
          }
          await File('${out.path}/sheet-${entry.key}-${page + 1}.png')
              .writeAsBytes(img.encodePng(sheet));
        }
      }
      // ignore: avoid_print
      print('RESULT drafts=${decoded.entries.length} json=${text.length} bytes');
    });
  });
}
