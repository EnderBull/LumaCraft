import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import '../phone-preview/drafts_test.dart' show O, landscape, portrait, square, px;
import '../new-presets/drafts_test.dart'
    show P, t, line, sides, canvasW, build, warmPhoto, tall;
import 'package:lumacraft/editor/background_style.dart';
import 'package:lumacraft/editor/builtin_library.dart';
import 'package:lumacraft/editor/image_mark.dart';
import 'package:lumacraft/editor/palette_style.dart';
import 'package:lumacraft/editor/postmark.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/style_render.dart';
import 'package:lumacraft/fonts/font_catalog.dart';

// 0.13.0 邮票 / 车票 / 杂志预设草案：仿用户参考图 3 款 + 变体 3 款。
// 只写 build/stamp-presets，不改正式内置库。

final marks = <String, ImageMark>{};
double prefixWidth = 0;

StyleNode postmarkNode(String id, String kind, String ink,
        {String anchor = 'bottom', double opacity = 75}) =>
    StyleNode(
        id: id,
        type: 'image',
        name: '邮戳',
        text: '',
        anchor: anchor,
        opacity: opacity,
        image: ImageMark.fromJson(marks['$kind-$ink']!.toJson()));

List<P> presets() => [
      // 1 邮票·模糊背景（仿参考图 1）
      P('stamp-blur', '邮票·模糊背景', 0xff1c1c1c, [
        t('title', 'text', '标题', size: 50, color: 0xff2b2b2b, text: 'Hangzhou'),
        t('place', 'place', '地点', size: 30, color: 0xff55524c),
        line('rule', '分隔线', 0xffd9d6cf),
        t('time', 'time', '拍摄时间', size: 26, color: 0xff77736b),
        postmarkNode('postmark', 'airmail', 'gray', opacity: 70),
      ], (o) {
        final b = tall(o, 240, 280);
        return sides(166, 166, 110 + b, 166);
      }, (o) {
        final b = tall(o, 240, 280), bt = 110 + b;
        final w = canvasW(o, sides(166, 166, 0, 166));
        return {
          'title': {'x': px(166, w), 'y': px(b * .27, bt)},
          'place': {'x': px(166, w), 'y': px(b * .49, bt)},
          'rule': {'x': px(166 + 130, w), 'y': px(b * .615, bt), 'w': 260, 'h': 2},
          'time': {'x': px(166, w), 'y': px(b * .74, bt)},
          'postmark': {'x': px(w - 166 - 140, w), 'y': px(b * .5, bt), 'w': 300},
        };
      }, (d) {
        d.fill = BackgroundStyle(
            mode: 'blur', blur: 42, brightness: -6, contrast: 100, saturation: 110);
        d.stamp = StampStyle(enabled: true, diameter: 34, gap: 22, margin: 110);
      }),
      // 2 车票（仿参考图 2）：上下打孔，照片下方虚线分割，两端半圆缺口。
      P('ticket', '车票', 0xff1c1c1c, [
        t('title', 'text', '标题', size: 46, color: 0xff2b2b2b, text: 'Shanghai'),
        t('place', 'place', '地点', size: 28, color: 0xff55524c),
        line('rule', '分隔线', 0xffdedad2),
        t('time', 'time', '拍摄时间', size: 24, color: 0xff77736b),
        postmarkNode('postmark', 'airmail', 'gray', opacity: 65),
      ], (o) => sides(180, 156, 120 + tall(o, 250, 270), 156), (o) {
        final b = tall(o, 250, 270), bt = 120 + b, h = b - 44;
        final w = canvasW(o, sides(180, 156, 0, 156));
        return {
          'title': {'x': px(156, w), 'y': px(44 + h * .26, bt)},
          'place': {'x': px(156, w), 'y': px(44 + h * .49, bt)},
          'rule': {'x': px(156 + 120, w), 'y': px(44 + h * .62, bt), 'w': 240, 'h': 2},
          'time': {'x': px(156, w), 'y': px(44 + h * .76, bt)},
          'postmark': {'x': px(w - 156 - 130, w), 'y': px(44 + h * .5, bt), 'w': 260},
        };
      }, (d) {
        d.fill = BackgroundStyle(
            mode: 'blur', blur: 42, brightness: -10, contrast: 100, saturation: 110);
        d.stamp = StampStyle(
            enabled: true,
            sides: 'topBottom',
            diameter: 30,
            gap: 22,
            margin: 120,
            ticket: true,
            ticketOffset: 44,
            ticketWidth: 2.5,
            ticketDash: 12,
            ticketGap: 8,
            ticketColor: 0xffb9b4aa,
            notch: 40);
      }),
      // 3 自然诗篇（仿参考图 3）：顶部标题 + 拍摄时间，底部色带 + 机型参数地点。
      P('nature-poetry', '自然诗篇', 0xffffffff, [
        t('title', 'text', '标题',
            font: 'jost', size: 62, color: 0xff1d1d1d, text: "Nature's poetry"),
        t('prefix', 'text', '时间前缀',
            font: 'jost', size: 19, color: 0xff8c8c8c, spacing: 3, text: 'PHOTOGRAPHED IN ·'),
        t('time', 'time', '拍摄时间', font: 'jost', size: 19, color: 0xff8c8c8c, spacing: 2),
        StyleNode(
            id: 'palette',
            type: 'palette',
            name: '照片色卡',
            anchor: 'bottom',
            palette: PaletteStyle(mode: 'strip', size: 58, height: 24, radius: 0)),
        t('camera', 'camera', '机型',
            font: 'jost', size: 40, color: 0xff1d1d1d, align: 'right', spacing: 1),
        t('params', 'params', '拍摄参数',
            font: 'jost', size: 19, color: 0xff8c8c8c, align: 'right'),
        t('place', 'place', '地点', size: 17, color: 0xffa0a0a0, align: 'right'),
      ], (o) => sides(tall(o, 200, 220), 60, tall(o, 170, 190), 60), (o) {
        final top = tall(o, 200, 220), bottom = tall(o, 170, 190);
        final w = canvasW(o, sides(0, 60, 0, 60)), h = top + o.h + bottom;
        return {
          'title': {'anchor': 'canvas', 'x': px(60, w), 'y': px(top * .4, h)},
          'prefix': {'anchor': 'canvas', 'x': px(60, w), 'y': px(top * .72, h)},
          'time': {'anchor': 'canvas', 'x': px(60 + prefixWidth + 12, w), 'y': px(top * .72, h)},
          'palette': {'x': px(60 + 174, w), 'y': px(bottom * .3, bottom)},
          'camera': {'x': px(w - 60, w), 'y': px(bottom * .3, bottom)},
          'params': {'x': px(w - 60, w), 'y': px(bottom * .56, bottom)},
          'place': {'x': px(w - 60, w), 'y': px(bottom * .74, bottom)},
        };
      }, (d) {}),
      // 4 牛皮纸邮票：纹理铺在邮票纸上，纸外深色底，红色椭圆邮戳。
      P('stamp-kraft', '牛皮纸邮票', 0xff2e2620, [
        t('note', 'text', '手写一句',
            font: 'caveat', size: 60, color: 0xff4a3220, text: 'Wish you were here'),
        t('place', 'place', '地点', size: 26, color: 0xff6b4c2e),
        t('time', 'time', '拍摄时间', font: 'jost', size: 22, color: 0xff6b4c2e, spacing: 1),
        postmarkNode('postmark', 'oval', 'red', opacity: 78),
      ], (o) => sides(140, 140, 90 + tall(o, 230, 270), 140), (o) {
        final b = tall(o, 230, 270), bt = 90 + b;
        final w = canvasW(o, sides(140, 140, 0, 140));
        return {
          'note': {'x': px(140, w), 'y': px(b * .34, bt)},
          'place': {'x': px(140, w), 'y': px(b * .6, bt)},
          'time': {'x': px(140, w), 'y': px(b * .76, bt)},
          'postmark': {'x': px(w - 140 - 105, w), 'y': px(b * .5, bt), 'w': 210},
        };
      }, (d) {
        d.fill = BackgroundStyle(
            mode: 'texture', texture: 'kraft', textureColor: 0xff5a3d22, textureOpacity: 40);
        d.stamp = StampStyle(
            enabled: true, paper: 0xffd9bf96, diameter: 28, gap: 16, margin: 90);
      }),
      // 5 票根：纵向分割，右侧票根放机型、地点、时间和蓝色波浪戳。
      P('ticket-stub', '票根', 0xff23303a, [
        t('admit', 'text', '票面文字',
            font: 'jost', size: 24, color: 0xffb04a3a, align: 'center', spacing: 6, text: 'ADMIT ONE'),
        t('camera', 'camera', '机型',
            font: 'jost', size: 32, color: 0xff2b2b2b, align: 'center', spacing: 1),
        t('place', 'place', '地点', size: 20, color: 0xff7a7468, align: 'center'),
        t('time', 'time', '拍摄时间',
            font: 'jost', size: 18, color: 0xff7a7468, align: 'center', spacing: 1),
        postmarkNode('postmark', 'waves', 'blue', opacity: 72),
      ], (o) => sides(140, 400, 140, 140), (o) {
        final w = o.w + 140 + 400, h = o.h + 280;
        final cx = (140 + o.w + 40 + w - 90) / 2;
        return {
          'admit': {'anchor': 'canvas', 'x': px(cx, w), 'y': px(h * .27, h)},
          'camera': {'anchor': 'canvas', 'x': px(cx, w), 'y': px(h * .41, h)},
          'place': {'anchor': 'canvas', 'x': px(cx, w), 'y': px(h * .5, h)},
          'time': {'anchor': 'canvas', 'x': px(cx, w), 'y': px(h * .57, h)},
          'postmark': {'anchor': 'canvas', 'x': px(cx, w), 'y': px(h * .73, h), 'w': 230},
        };
      }, (d) {
        d.stamp = StampStyle(
            enabled: true,
            sides: 'leftRight',
            paper: 0xfffbf5e9,
            diameter: 26,
            gap: 18,
            margin: 90,
            ticket: true,
            ticketAxis: 'vertical',
            ticketOffset: 40,
            ticketWidth: 2.5,
            ticketDash: 12,
            ticketGap: 8,
            ticketColor: 0xffc9bfae,
            notch: 44);
      }),
      // 6 复古邮票：奶油色纸，照片角上印面值，红色航空戳压住照片右下角。
      P('stamp-vintage', '复古邮票', 0xff31403a, [
        t('value', 'text', '面值',
            font: 'sourceSerif', size: 64, color: 0xfffaf6ec, align: 'right', text: '80分'),
        t('title', 'text', '标题',
            font: 'wenkai', size: 44, color: 0xff3a332a, spacing: 4, text: '山海有信'),
        t('sub', 'text', '副标题',
            font: 'jost', size: 18, color: 0xff8a7f6d, spacing: 6, text: 'LUMACRAFT  POST'),
        postmarkNode('postmark', 'airmail', 'red', anchor: 'photo', opacity: 72),
      ], (o) => sides(144, 144, 100 + tall(o, 200, 240), 144), (o) {
        final b = tall(o, 200, 240), bt = 100 + b;
        final w = canvasW(o, sides(144, 144, 0, 144));
        return {
          'value': {'anchor': 'photo', 'x': px(o.w - 40, o.w), 'y': px(70, o.h)},
          'title': {'x': px(144, w), 'y': px(b * .4, bt)},
          'sub': {'x': px(144, w), 'y': px(b * .68, bt)},
          'postmark': {'x': px(o.w - 120, o.w), 'y': px(o.h - 10, o.h), 'w': 300},
        };
      }, (d) {
        d.stamp = StampStyle(
            enabled: true, paper: 0xfff6eedc, diameter: 26, gap: 14, margin: 100);
      }),
    ];

void main() {
  testWidgets('邮票 / 车票 / 杂志预设草案效果图', (tester) async {
    await tester.runAsync(() async {
      for (final f in artworkFonts) {
        await (FontLoader(f.family)..addFont(rootBundle.load(f.asset))).load();
      }
      for (final kind in postmarkKinds.keys) {
        for (final ink in postmarkInks.keys) {
          marks['$kind-$ink'] = await buildPostmark(kind, ink);
        }
      }
      final prefix = TextPainter(
          text: TextSpan(
              text: 'PHOTOGRAPHED IN ·',
              style: artworkTextStyle('jost')
                  .copyWith(fontSize: 19, letterSpacing: 3, height: 1.4)),
          textDirection: TextDirection.ltr)
        ..layout();
      prefixWidth = prefix.width;
      final out = Directory('build/stamp-presets/out')..createSync(recursive: true);
      final defs = presets();
      final entries = [for (final d in defs) BuiltinEntry(d.id, build(d), folder: 'classic')];
      final library = BuiltinLibrary([const BuiltinFolder('classic', '创意边框')], entries);
      final text = library.encode();
      await File('build/stamp-presets/drafts.json').writeAsString(text);
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
        final cellW = entry.key == 'portrait' ? 420 : 560;
        final cells = [
          for (final i in entry.value)
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
        await File('${out.path}/sheet-${entry.key}.png').writeAsBytes(img.encodePng(sheet));
      }
      // ignore: avoid_print
      print('RESULT drafts=${decoded.entries.length} json=${text.length} bytes');
    });
  });
}
