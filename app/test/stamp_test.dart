import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/background_render.dart';
import 'package:lumacraft/editor/background_style.dart';
import 'package:lumacraft/editor/image_mark.dart';
import 'package:lumacraft/editor/postmark.dart';
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
  ui.decodeImageFromPixels(pixels, w, h, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

StyleDocument stamped({String sides = 'all'}) => StyleDocument(
    background: 0xff202020,
    borders: {'top': 12, 'right': 12, 'bottom': 12, 'left': 12})
  ..stamp = StampStyle(
      enabled: true, sides: sides, diameter: 20, gap: 10, margin: 40);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('打孔位置：孔心落在纸边上，短边随横竖图切换', () {
    for (final (ratio, sides, edges) in [
      (1.5, 'all', [true, true, true, true]),
      (1.5, 'topBottom', [true, false, true, false]),
      (1.5, 'leftRight', [false, true, false, true]),
      (1.5, 'short', [false, true, false, true]),
      (2 / 3, 'short', [true, false, true, false]),
    ]) {
      final d = stamped(sides: sides), g = StyleGeometry(d, ratio);
      final paper = stampPaper(d, g);
      expect(paper, Rect.fromLTRB(40, 40, g.size.width - 40, g.size.height - 40));
      final holes = stampHoles(d.stamp, paper);
      expect(holes, isNotEmpty);
      final hit = [
        holes.any((c) => (c.dy - paper.top).abs() < .01),
        holes.any((c) => (c.dx - paper.right).abs() < .01),
        holes.any((c) => (c.dy - paper.bottom).abs() < .01),
        holes.any((c) => (c.dx - paper.left).abs() < .01),
      ];
      expect(hit, edges, reason: '$sides @ $ratio');
    }
  });

  test('留白超过边框时纸边贴住照片；车票分割线两个方向', () {
    final d = stamped()..stamp.margin = 999;
    final g = StyleGeometry(d, 1.5);
    expect(stampPaper(d, g), g.photo);

    final t = stamped()
      ..stamp.ticket = true
      ..stamp.ticketOffset = 30;
    final tg = StyleGeometry(t, 1.5), paper = stampPaper(t, tg);
    final (a, b) = ticketEnds(t.stamp, paper, tg.photo);
    expect(a, Offset(paper.left, tg.photo.bottom + 30));
    expect(b, Offset(paper.right, tg.photo.bottom + 30));
    t.stamp.ticketAxis = 'vertical';
    final (c, e) = ticketEnds(t.stamp, paper, tg.photo);
    expect(c, Offset(tg.photo.right + 30, paper.top));
    expect(e, Offset(tg.photo.right + 30, paper.bottom));
  });

  test('邮票参数保存读取；开启邮票时不画胶片孔；分享文件带标记', () {
    final d = stamped(sides: 'short')
      ..film = FilmStyle(enabled: true)
      ..stamp.ticket = true
      ..stamp.ticketAxis = 'vertical'
      ..stamp.paper = 0xfff4ead8;
    expect(filmHoles(d, StyleGeometry(d, 1.5)), isEmpty);
    final back = d.copy().stamp;
    expect(back.enabled, isTrue);
    expect(back.sides, 'short');
    expect(back.ticketAxis, 'vertical');
    expect(back.paper, 0xfff4ead8);
    final legacy = StyleDocument().toJson()..remove('stamp');
    expect(StyleDocument.fromJson(legacy).stamp.enabled, isFalse);

    d.name = '邮票';
    final text = encodeLmp([SharedPreset(d)]);
    final j = jsonDecode(text);
    expect(j['requires'], contains('stampV1'));
    expect(decodeLmp(text).single.style.stamp.ticket, isTrue);
    j['presets'][0]['style']['stamp']['sides'] = 'diagonal';
    expect(() => decodeLmp(jsonEncode(j)), throwsFormatException);
    final plain = jsonDecode(encodeLmp([SharedPreset(StyleDocument(name: '普通'))]));
    expect(plain['requires'], isNot(contains('stampV1')));
  });

  testWidgets('邮票纸与孔洞只出现在边框里，照片不变', (tester) async {
    await tester.runAsync(() async {
      final photo = await solidPhoto(300, 200);
      final d = stamped()
        ..stamp.ticket = true
        ..stamp.ticketColor = 0xffff0000;
      final scene = StyleScene(d, photo, {});
      final g = scene.geometry;
      final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
      scene.paint(canvas);
      final picture = recorder.endRecording();
      final image =
          await picture.toImage(g.size.width.round(), g.size.height.round());
      final data =
          (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
      int px(Offset o) =>
          data.getUint32((o.dy.floor() * image.width + o.dx.floor()) * 4);
      const paperWhite = 0xffffffff, dark = 0x202020ff;
      // 纸外留白露出背景，孔里露出背景，孔与孔之间是纸。
      expect(px(const Offset(10, 10)), dark);
      final paper = stampPaper(d, g), hole = stampHoles(d.stamp, paper)[3];
      expect(px(hole + const Offset(0, 6)), dark);
      expect(px(Offset(paper.left + 60, paper.top + 30)), paperWhite);
      expect(px(g.photo.center), 0x285aa0ff);
      // 分割线是红色虚线，画在照片下方的纸上。
      final y = g.photo.bottom + d.stamp.ticketOffset;
      var red = 0;
      for (var x = paper.left; x < paper.right; x += 1) {
        final c = px(Offset(x, y));
        if (c >> 24 > 200 && (c >> 16) & 0xff < 120) red++;
      }
      expect(red, greaterThan(100));
      image.dispose();
      picture.dispose();
      scene.dispose();
      photo.dispose();
    });
  });

  testWidgets('内置邮戳：三款四色都能生成透明 PNG，并能从文件名认出', (tester) async {
    await tester.runAsync(() async {
      for (final kind in postmarkKinds.keys) {
        for (final ink in postmarkInks.keys) {
          final mark = await buildPostmark(kind, ink);
          expect(postmarkOf(mark), (kind, ink));
          final size = postmarkSize(kind);
          expect(mark.ratio, closeTo(size.width / size.height, .001));
          final codec =
              await ui.instantiateImageCodec(base64Decode(mark.data));
          final image = (await codec.getNextFrame()).image;
          final data = (await image.toByteData())!;
          var inked = 0, clear = 0;
          for (var i = 3; i < data.lengthInBytes; i += 4 * 13) {
            data.getUint8(i) > 0 ? inked++ : clear++;
          }
          expect(inked, greaterThan(500), reason: '$kind/$ink 应有墨迹');
          expect(clear, greaterThan(inked), reason: '$kind/$ink 背景应透明');
          image.dispose();
          codec.dispose();
        }
      }
      expect(postmarkOf(ImageMark(filename: 'logo.png')), isNull);
    });
  });
}
