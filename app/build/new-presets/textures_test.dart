import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/background_style.dart';
import 'package:lumacraft/editor/texture_render.dart';

// 18 种纹理样张：每格一个底色 + 纹理颜色组合，只写 build/new-presets/out。

const swatches = <String, (int, int, double)>{
  'finePaper': (0xfff6f2e9, 0xff6b5a40, 30),
  'kraft': (0xffc9a57a, 0xff5a3d22, 35),
  'xuan': (0xfff3ecdc, 0xff8a7350, 30),
  'watercolor': (0xfffbf8f2, 0xff7a6a55, 35),
  'linen': (0xffe8e1d3, 0xff6a5d48, 30),
  'canvas': (0xffded6c6, 0xff5d5242, 30),
  'dots': (0xfffafaf8, 0xff2b2b2b, 18),
  'diagonal': (0xfff7f7f5, 0xff2b2b2b, 12),
  'grid': (0xfffbfbfa, 0xff2b2b2b, 14),
  'marble': (0xfff4f2ef, 0xff5b5650, 45),
  'grain': (0xff1b1b1d, 0xffffffff, 16),
  'brushed': (0xffb9bcc0, 0xff3a3d42, 35),
  'polka': (0xfff9d8d6, 0xffffffff, 70),
  'stars': (0xffcfe3f5, 0xffffffff, 80),
  'gingham': (0xfffdfbf6, 0xffd96c6c, 28),
  'circuit': (0xff0d1b2a, 0xff3ad1c7, 45),
  'honeycomb': (0xff111418, 0xff6aa8ff, 35),
  'scanlines': (0xff0b0f14, 0xff7cf0ff, 12),
};

void main() {
  testWidgets('纹理样张', (tester) async {
    await tester.runAsync(() async {
      for (final k in textureKindNames.keys) {
        await ensureTexture(k);
      }
      final all = textureKindNames.keys.toList();
      for (var page = 0; page < 3; page++) {
        await sheet(all.sublist(page * 6, page * 6 + 6), 'textures-${page + 1}');
      }
      await sheet(all, 'textures', cols: 6, scale: 1);
    });
  });
}

Future<void> sheet(List<String> kinds, String name,
    {int cols = 3, double scale = 1.6}) async {
      const cellW = 300.0, cellH = 200.0, gap = 16.0;
      final rows = (kinds.length / cols).ceil();
      {
      final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
      canvas.scale(scale);
      canvas.drawRect(
          Rect.fromLTWH(0, 0, cols * (cellW + gap) + gap, rows * (cellH + gap) + gap),
          Paint()..color = const Color(0xff2a2a2a));
      for (var i = 0; i < kinds.length; i++) {
        final kind = kinds[i];
        final (bg, ink, opacity) = swatches[kind]!;
        final rect = Rect.fromLTWH(gap + (i % cols) * (cellW + gap),
            gap + (i ~/ cols) * (cellH + gap), cellW, cellH);
        canvas.save();
        canvas.clipRect(rect);
        canvas.drawRect(rect, Paint()..color = Color(bg));
        paintTexture(
            canvas,
            BackgroundStyle(
                texture: kind, textureColor: ink, textureOpacity: opacity),
            rect,
            Rect.zero);
        canvas.restore();
      }
      final w = ((cols * (cellW + gap) + gap) * scale).round(),
          h = ((rows * (cellH + gap) + gap) * scale).round();
      final image = await recorder.endRecording().toImage(w, h);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      Directory('build/new-presets/out').createSync(recursive: true);
      await File('build/new-presets/out/$name.png')
          .writeAsBytes(png.buffer.asUint8List());
      }
}
