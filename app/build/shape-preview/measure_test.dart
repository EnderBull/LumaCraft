import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/fonts/font_catalog.dart';

// 临时测量：字符在画面上的实际墨迹尺寸（相对文字框中心）。
void main() {
  testWidgets('measure glyph ink', (tester) async {
    await tester.runAsync(() async {
      for (final f in artworkFonts) {
        await (FontLoader(f.family)..addFont(rootBundle.load(f.asset))).load();
      }
      Future<void> measure(String text, String font, double size) async {
        final painter = TextPainter(
            text: TextSpan(
                text: text,
                style: artworkTextStyle(font).copyWith(
                    fontSize: size,
                    letterSpacing: 0,
                    color: Colors.black,
                    height: 1.4)),
            textDirection: TextDirection.ltr)
          ..layout();
        const k = 8.0;
        final w = (painter.width + 40).ceil(), h = (painter.height + 40).ceil();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..scale(k);
        painter.paint(canvas, const Offset(20, 20));
        final image = await recorder
            .endRecording()
            .toImage((w * k).ceil(), (h * k).ceil());
        final data = (await image.toByteData())!;
        var minX = 1 << 30, minY = 1 << 30, maxX = -1, maxY = -1;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            if (data.getUint8((y * image.width + x) * 4 + 3) > 127) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }
        final ink = Rect.fromLTRB(minX / k, minY / k, (maxX + 1) / k, (maxY + 1) / k);
        final box = Rect.fromLTWH(20, 20, painter.width, painter.height);
        final c = box.center;
        // ignore: avoid_print
        print('RESULT "$text" $font $size => box ${painter.width}x${painter.height}; '
            'ink ${ink.width.toStringAsFixed(2)} x ${ink.height.toStringAsFixed(2)}; '
            'ink center offset from box center dx=${(ink.center.dx - c.dx).toStringAsFixed(2)} '
            'dy=${(ink.center.dy - c.dy).toStringAsFixed(2)}');
        image.dispose();
      }

      await measure('——', 'sourceSans', 16);
      await measure('▎', 'sourceSans', 42);
    });
  });
}
