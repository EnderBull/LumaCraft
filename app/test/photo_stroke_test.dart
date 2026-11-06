import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/palette_style.dart';
import 'package:lumacraft/editor/preset_package.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/style_render.dart';

Future<ui.Image> solidPhoto(int w, int h) {
  final pixels = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    pixels[i * 4] = 40;
    pixels[i * 4 + 1] = 90;
    pixels[i * 4 + 2] = 160;
    pixels[i * 4 + 3] = 255;
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(
      pixels, w, h, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('照片描边随文档保存；旧文件没有这项时默认关闭', () {
    final d = StyleDocument(name: '描边')
      ..photoStroke.enabled = true
      ..photoStroke.target = 'canvas'
      ..photoStroke.color = 0xffc9c2b4
      ..photoStroke.width = 2.5
      ..photoStroke.opacity = 55
      ..photoStroke.inset = -8;
    final back = d.copy().photoStroke;
    expect(back.enabled, isTrue);
    expect(back.target, 'canvas');
    expect(back.width, 2.5);
    expect(back.opacity, 55);
    expect(back.inset, -8);
    final legacy = StyleDocument(name: '旧').toJson()..remove('photoStroke');
    expect(StyleDocument.fromJson(legacy).photoStroke.enabled, isFalse);

    final text = encodeLmp([SharedPreset(d)]);
    expect(jsonDecode(text)['requires'], contains('photoStrokeV1'));
    expect(decodeLmp(text).single.style.photoStroke.target, 'canvas');
    final plain =
        jsonDecode(encodeLmp([SharedPreset(StyleDocument(name: '普通'))]));
    expect(plain['requires'], isNot(contains('photoStrokeV1')));
    final bad = jsonDecode(text);
    bad['presets'][0]['style']['photoStroke']['target'] = 'frame';
    expect(() => decodeLmp(jsonEncode(bad)), throwsFormatException);
  });

  test('色卡描边不透明度默认 100，改小后分享文件带标记', () {
    expect(PaletteStyle().strokeOpacity, 100);
    final faded = PaletteStyle(stroke: true, strokeOpacity: 40);
    expect(PaletteStyle.fromJson(faded.toJson()).strokeOpacity, 40);
    final old = faded.toJson()..remove('strokeOpacity');
    expect(PaletteStyle.fromJson(old).strokeOpacity, 100);
    final doc = StyleDocument(name: '色卡');
    final node = StyleNode(type: 'palette', name: '色卡')
      ..palette.stroke = true
      ..palette.strokeOpacity = 40;
    doc.nodes.add(node);
    doc.order.add(node.id);
    expect(jsonDecode(encodeLmp([SharedPreset(doc)]))['requires'],
        contains('paletteStrokeOpacity'));
    node.palette.strokeOpacity = 100;
    expect(
        jsonDecode(encodeLmp([SharedPreset(doc)]))['requires'],
        isNot(contains('paletteStrokeOpacity')));
  });

  testWidgets('描边跟着照片或画布走，照片中间不被盖住', (tester) async {
    await tester.runAsync(() async {
      Future<void> check(int w, int h) async {
        final photo = await solidPhoto(w, h);
        final d = StyleDocument(
            name: '描边',
            background: 0xff202020,
            borders: {'top': 20, 'right': 20, 'bottom': 20, 'left': 20})
          ..photoStroke.enabled = true
          ..photoStroke.color = 0xffffffff
          ..photoStroke.width = 16
          ..photoStroke.inset = -8;
        final scene = StyleScene(d, photo, {});
        final g = scene.geometry;
        final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
        scene.paint(canvas);
        final picture = recorder.endRecording();
        final image = await picture.toImage(
            g.size.width.round(), g.size.height.round());
        final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba))!;
        int px(Offset o) => data.getUint32(
            (o.dy.round() * image.width + o.dx.round()) * 4);
        expect(px(g.photo.center), 0x285aa0ff, reason: '${w}x$h 照片中间应保持原色');
        final onStroke = g.photo.centerLeft + const Offset(-8, 0);
        expect(px(onStroke) >> 24, greaterThan(220),
            reason: '${w}x$h 线应落在照片外侧');
        final clear = g.photo.centerLeft + const Offset(-28, 0);
        expect(px(clear), 0x202020ff, reason: '${w}x$h 更外侧仍是背景');
        image.dispose();
        picture.dispose();
        scene.dispose();
        photo.dispose();
      }

      await check(300, 200);
      await check(200, 300);

      final photo = await solidPhoto(300, 200);
      final d = StyleDocument(
          name: '画布线',
          background: 0xff202020,
          borders: {'top': 20, 'right': 20, 'bottom': 20, 'left': 20})
        ..photoStroke.enabled = true
        ..photoStroke.target = 'canvas'
        ..photoStroke.color = 0xffff0000
        ..photoStroke.width = 4
        ..photoStroke.inset = 22;
      final scene = StyleScene(d, photo, {});
      final g = scene.geometry;
      final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
      scene.paint(canvas);
      final picture = recorder.endRecording();
      final image =
          await picture.toImage(g.size.width.round(), g.size.height.round());
      final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba))!;
      int px(Offset o) =>
          data.getUint32((o.dy.round() * image.width + o.dx.round()) * 4);
      expect(px(g.photo.center), 0x285aa0ff);
      final edge = px(Offset(22, g.size.height / 2));
      expect((edge >> 24) & 0xff, greaterThan(200), reason: '画布内侧的线应是红色');
      expect(px(const Offset(4, 4)), 0x202020ff, reason: '线内侧以外仍是背景');
      image.dispose();
      picture.dispose();
      scene.dispose();
      photo.dispose();
    });
  });
}
