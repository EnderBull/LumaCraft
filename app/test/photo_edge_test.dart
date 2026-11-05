import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/background_render.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/style_render.dart';

Future<ui.Image> solidPhoto(int w, int h, int r, int g, int b) {
  final pixels = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    pixels[i * 4] = r;
    pixels[i * 4 + 1] = g;
    pixels[i * 4 + 2] = b;
    pixels[i * 4 + 3] = 255;
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, w, h, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 照片贴着画布边缘（边框为 0）时，缩放到小数比例后，照片边缘像素不能混入底色。
  testWidgets('小数缩放下，照片边缘不出现底色白边', (tester) async {
    await tester.runAsync(() async {
      final photo = await solidPhoto(600, 400, 20, 20, 20);
      final doc = StyleDocument(
          background: 0xfff3f0e8,
          borders: {'top': 0, 'right': 0, 'bottom': 13, 'left': 0});
      for (final scale in [0.7311, 0.9137, 1.2653, 0.5]) {
        final scene = StyleScene(doc, photo, {});
        final size = scene.geometry.size;
        const dx = .37, dy = .21;
        final width = (size.width * scale + 3).ceil(),
            height = (size.height * scale + 3).ceil();
        final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
        canvas.translate(dx, dy);
        canvas.scale(scale);
        scene.paint(canvas);
        final picture = recorder.endRecording();
        final image = await picture.toImage(width, height);
        final data = (await image.toByteData(
                format: ui.ImageByteFormat.rawStraightRgba))!;
        int channel(int x, int y, int c) =>
            data.getUint8((y * width + x) * 4 + c);
        final photoBottom =
            ((size.height - scene.geometry.bottom) * scale + dy).floor();
        final rightColumn = (size.width * scale + dx).floor();
        void expectDark(int x, int y, String where) {
          if (channel(x, y, 3) == 0) return;
          for (var c = 0; c < 3; c++) {
            expect(channel(x, y, c), lessThanOrEqualTo(28),
                reason: '缩放 $scale：$where 像素 ($x,$y) 通道 $c 混入了浅色底色');
          }
        }

        for (var y = 6; y < photoBottom - 6; y += 7) {
          expectDark(0, y, '左边缘');
          expectDark(rightColumn, y, '右边缘');
        }
        for (var x = 6; x < rightColumn - 6; x += 11) {
          expectDark(x, 0, '上边缘');
        }
        // 底部边框区域仍然是底色。
        final borderY = ((size.height - scene.geometry.bottom / 2) * scale).round();
        expect(channel((width / 2).round(), borderY, 0), greaterThan(235),
            reason: '缩放 $scale：底边框内应是底色');
        image.dispose();
        picture.dispose();
        scene.dispose();
      }
      photo.dispose();
    });
  });

  testWidgets('有边框的各边：照片与边框交界处没有缝隙、没有白线', (tester) async {
    await tester.runAsync(() async {
      final photo = await solidPhoto(600, 400, 20, 20, 20);
      final doc = StyleDocument(
          background: 0xfff3f0e8,
          borders: {'top': 4, 'right': 4, 'bottom': 8, 'left': 4});
      for (final scale in [0.7311, 0.9137]) {
        final scene = StyleScene(doc, photo, {});
        final size = scene.geometry.size;
        final width = (size.width * scale).ceil(),
            height = (size.height * scale).ceil();
        final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
        canvas.scale(scale);
        scene.paint(canvas);
        final picture = recorder.endRecording();
        final image = await picture.toImage(width, height);
        final data = (await image.toByteData(
                format: ui.ImageByteFormat.rawStraightRgba))!;
        // 沿照片左边界横向扫描：像素值只能从底色过渡到照片色，不能出现透明缝隙。
        final y = (size.height / 2 * scale).round();
        // 最后一列只被画布覆盖了一部分，不参与检查。
        for (var x = 0; x < width - 1; x++) {
          expect(data.getUint8((y * width + x) * 4 + 3), 255,
              reason: '缩放 $scale：横向 x=$x 出现透明缝隙');
        }
        image.dispose();
        picture.dispose();
        scene.dispose();
      }
      expect(paintStyleBackground, isNotNull);
      photo.dispose();
    });
  });
}
