import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/background_render.dart';
import 'package:lumacraft/editor/background_style.dart';
import 'package:lumacraft/editor/preset_package.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/style_render.dart';
import 'package:lumacraft/editor/texture_render.dart';

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

StyleDocument framed() => StyleDocument(
    background: 0xfff3f0e8,
    borders: {'top': 8, 'right': 8, 'bottom': 8, 'left': 8});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('胶片“沿长边”：横图孔在上下，竖图孔在左右，方图在上下', () {
    final d = framed()
      ..film = FilmStyle(
          enabled: true, orientation: 'long', width: 24, height: 14, inset: 10);
    for (final (ratio, vertical) in [(1.5, false), (2 / 3, true), (1.0, false)]) {
      final g = StyleGeometry(d, ratio), holes = filmHoles(d, g);
      expect(holes, isNotEmpty);
      for (final h in holes) {
        final rect = h.outerRect;
        // 孔洞沿胶片方向的长度始终是“孔宽”。
        expect(vertical ? rect.height : rect.width, 24);
        if (vertical) {
          expect(rect.right <= g.photo.left || rect.left >= g.photo.right, isTrue,
              reason: '竖图孔洞应在左右边框');
        } else {
          expect(rect.bottom <= g.photo.top || rect.top >= g.photo.bottom, isTrue,
              reason: '横图孔洞应在上下边框');
        }
      }
    }
    final back = FilmStyle.fromJson(d.film.toJson());
    expect(back.orientation, 'long');
  });

  test('纹理参数保存与读取；未启用时不写入', () {
    expect(BackgroundStyle().toJson().containsKey('texture'), isFalse);
    final f = BackgroundStyle(
        texture: 'kraft',
        textureColor: 0xff5a3d22,
        textureOpacity: 22,
        textureScale: 150);
    final back = BackgroundStyle.fromJson(f.toJson());
    expect(back.texture, 'kraft');
    expect(back.textureColor, 0xff5a3d22);
    expect(back.textureOpacity, 22);
    expect(back.textureScale, 150);
    expect(BackgroundStyle.fromJson({'texture': 'unknown'}).texture, 'none');
    expect(textureKindNames.length, 18);
    for (final kind in textureKindNames.keys) {
      expect(textureGroupOf(kind), isNot('none'));
    }
  });

  test('分享文件：用到新功能才标记，旧版本会拒绝；未知纹理被拒绝', () {
    final plain = framed()..name = '普通';
    final plainJson = jsonDecode(encodeLmp([SharedPreset(plain)]));
    expect(plainJson['requires'], isNot(contains('textureV1')));
    expect(plainJson['requires'], isNot(contains('filmLongEdge')));

    final fancy = framed()
      ..name = '纹理'
      ..fill.texture = 'stars'
      ..film = FilmStyle(enabled: true, orientation: 'long');
    final text = encodeLmp([SharedPreset(fancy)]);
    final j = jsonDecode(text);
    expect(j['requires'], containsAll(['textureV1', 'filmLongEdge']));
    final back = decodeLmp(text).single.style;
    expect(back.fill.texture, 'stars');
    expect(back.film.orientation, 'long');

    j['presets'][0]['style']['fill']['texture'] = 'lava';
    expect(() => decodeLmp(jsonEncode(j)), throwsFormatException);
  });

  test('材质图块：每种都有明暗变化', () {
    for (final kind in rasterTextureSpan.keys) {
      final p = textureTilePixels(kind);
      expect(p.length, 512 * 512 * 4);
      var low = 255, high = 0;
      for (var i = 3; i < p.length; i += 4 * 97) {
        low = p[i] < low ? p[i] : low;
        high = p[i] > high ? p[i] : high;
      }
      expect(high - low, greaterThan(40), reason: '$kind 纹理过于平淡');
    }
  });

  testWidgets('每种纹理只改变边框，不改变照片', (tester) async {
    await tester.runAsync(() async {
      final photo = await solidPhoto(300, 200);
      Future<ByteData> render(StyleDocument d) async {
        await ensureTexture(d.fill.texture);
        final scene = StyleScene(d, photo, {});
        final size = scene.geometry.size;
        final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
        canvas.scale(.5);
        scene.paint(canvas);
        final picture = recorder.endRecording();
        final image = await picture.toImage(
            (size.width * .5).round(), (size.height * .5).round());
        final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba))!;
        image.dispose();
        picture.dispose();
        scene.dispose();
        return data;
      }

      final base = await render(framed());
      final g = StyleGeometry(framed(), 1.5);
      final width = (g.size.width * .5).round();
      final photoArea = Rect.fromLTRB(g.photo.left * .5 + 2, g.photo.top * .5 + 2,
          g.photo.right * .5 - 2, g.photo.bottom * .5 - 2);
      for (final kind in textureKindNames.keys) {
        final d = framed()
          ..fill.texture = kind
          ..fill.textureOpacity = 60;
        final out = await render(d);
        var borderChanged = 0, photoChanged = 0;
        for (var i = 0; i < out.lengthInBytes; i += 4) {
          final p = i ~/ 4, x = p % width, y = p ~/ width;
          final diff = (out.getUint8(i) - base.getUint8(i)).abs();
          if (photoArea.contains(Offset(x + .5, y + .5))) {
            if (diff > 0) photoChanged++;
          } else if (diff > 6) {
            borderChanged++;
          }
        }
        expect(photoChanged, 0, reason: '$kind 不能画到照片上');
        expect(borderChanged, greaterThan(200), reason: '$kind 应在边框上可见');
      }
      photo.dispose();
    });
  });
}
