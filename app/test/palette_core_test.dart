import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/editor/style_render.dart';
import 'package:lumacraft/editor/photo_palette.dart';
import 'package:lumacraft/editor/palette_style.dart';
import 'package:lumacraft/editor/palette_render.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/editor_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('六色提取、单色回退、属性存储和形状绘制核心流程', () async {
    const colors = [
      0xff204080,
      0xff406040,
      0xffd09030,
      0xffb04050,
      0xffd0c090,
      0xff80b0c0
    ];
    final pixels = Uint8List(96 * 16 * 4);
    for (var i = 0; i < 96 * 16; i++) {
      final color = colors[(i % 96) ~/ 16];
      pixels[i * 4] = color >> 16 & 255;
      pixels[i * 4 + 1] = color >> 8 & 255;
      pixels[i * 4 + 2] = color & 255;
      pixels[i * 4 + 3] = 255;
    }
    final extracted = extractPhotoColors(pixels);
    expect(extracted.toSet(), colors.toSet());
    for (var i = 0; i < pixels.length; i += 4) {
      pixels[i] = 32;
      pixels[i + 1] = 64;
      pixels[i + 2] = 128;
    }
    expect(extractPhotoColors(pixels), List.filled(6, 0xff204080));
    final c = EditorController(StyleDocument());
    c.add('palette', 1.5);
    final node = c.doc.nodes.single;
    c.edit(() {
      node.palette.shape = 'hexagon';
      node.palette.radius = 9;
      node.palette.stroke = true;
      node.palette.strokeMode = 'each';
    });
    expect(c.doc.copy().nodes.single.palette.radius, 9);
    c.undo();
    expect(c.doc.nodes.single.palette.shape, 'circle');
    c.redo();
    expect(c.doc.nodes.single.palette.shape, 'hexagon');
    expect(PaletteStyle.fromJson({}).strokeGap, 0);
    expect(PaletteStyle.fromJson({'strokeGap': 99}).strokeGap, 10);
    for (final shape in ['circle', 'roundedRect', 'hexagon', 'strip']) {
      final separated = PaletteStyle(
          mode: shape == 'strip' ? 'strip' : 'blocks',
          shape: shape == 'strip' ? 'roundedRect' : shape,
          stroke: true,
          strokeGap: 3,
          strokeWidth: 2,
          strokeMode: 'each',
          radius: 0);
      expect(PaletteStyle.fromJson(separated.toJson()).strokeGap, 3);
      final size = paletteSize(separated), recorder = ui.PictureRecorder();
      paintPalette(
          Canvas(recorder), Offset.zero & size, separated, extracted, 100);
      final picture = recorder.endRecording();
      final image =
          await picture.toImage(size.width.ceil(), size.height.ceil());
      final pixels =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      int alpha(int x, int y) => pixels.getUint8((y * image.width + x) * 4 + 3);
      final y = (size.height / 2).floor();
      expect(alpha(3, y), 0, reason: '$shape描边与填充之间应有透明间隙');
      expect(alpha(1, y), greaterThan(240), reason: '$shape最外侧描边必须在选框以内完整绘制');
      expect(alpha(7, y), greaterThan(240), reason: '$shape填充大小保持不变');
      if (shape == 'strip') {
        for (var x = 6; x < size.width.floor() - 6; x++) {
          expect(alpha(x, y), 255, reason: '每块描边的连续色条内部不应被间距断开');
        }
      }
      image.dispose();
      picture.dispose();
    }
    final joined = PaletteStyle(
        mode: 'strip', size: 33.7, height: 30, radius: 4, scale: 1.137);
    final joinedSize = paletteSize(joined),
        joinedRecorder = ui.PictureRecorder();
    final joinedCanvas = Canvas(joinedRecorder)..translate(.37, .21);
    paintPalette(joinedCanvas, Offset.zero & joinedSize, joined, extracted, 50);
    final joinedPicture = joinedRecorder.endRecording();
    final joinedImage = await joinedPicture.toImage(
        joinedSize.width.ceil() + 2, joinedSize.height.ceil() + 2);
    final joinedPixels =
        (await joinedImage.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final middle = (joinedSize.height / 2).floor();
    for (var x = 3; x < joinedSize.width.floor() - 3; x++) {
      expect(joinedPixels.getUint8((middle * joinedImage.width + x) * 4 + 3),
          closeTo(128, 1),
          reason: '小数缩放与不透明度下，色条内部不能渗出背景形成细缝');
    }
    joinedImage.dispose();
    joinedPicture.dispose();
    final translucent = PaletteStyle(
        shape: 'roundedRect', radius: 0, stroke: true, strokeWidth: 4);
    final alphaSize = paletteSize(translucent),
        alphaRecorder = ui.PictureRecorder();
    paintPalette(Canvas(alphaRecorder), Offset.zero & alphaSize, translucent,
        extracted, 50);
    final alphaPicture = alphaRecorder.endRecording();
    final alphaImage = await alphaPicture.toImage(
        alphaSize.width.ceil(), alphaSize.height.ceil());
    final alphaPixels =
        (await alphaImage.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    expect(alphaPixels.getUint8((17 * alphaImage.width + 1) * 4 + 3),
        closeTo(128, 1),
        reason: '描边和填充应作为整个组件同步透明，而不是叠加变浓');
    alphaImage.dispose();
    alphaPicture.dispose();
    for (final shape in ['circle', 'roundedRect', 'hexagon', 'strip']) {
      final style = PaletteStyle(
          shape: shape == 'strip' ? 'roundedRect' : shape,
          mode: shape == 'strip' ? 'strip' : 'blocks',
          stroke: true,
          strokeMode: 'each',
          strokeWidth: 2,
          radius: 8);
      final size = paletteSize(style);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      paintPalette(canvas, Offset.zero & size, style, extracted, 100);
      final picture = recorder.endRecording();
      final image =
          await picture.toImage(size.width.ceil(), size.height.ceil());
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(data!.buffer.asUint8List().where((v) => v != 0).isNotEmpty, true);
      image.dispose();
      picture.dispose();
      final scaled = PaletteStyle.fromJson(style.toJson())..scale = 2;
      expect(paletteSize(scaled).width, closeTo(size.width * 2, .001));
    }
    c.dispose();
    final directory = await Directory(
            'test/palette-output/run-${DateTime.now().millisecondsSinceEpoch}')
        .create(recursive: true);
    final source = img.Image(width: 600, height: 240);
    for (var x = 0; x < 600; x++) {
      final color = colors[x ~/ 100];
      for (var y = 0; y < 240; y++) {
        source.setPixelRgb(
            x, y, color >> 16 & 255, color >> 8 & 255, color & 255);
      }
    }
    final file = File('${directory.path}/source.jpg');
    await file.writeAsBytes(img.encodeJpg(source));
    final actualColors = await photoPaletteForFile(file.path);
    expect(actualColors.length, 6);
    expect(await photoPaletteForFile(file.path), actualColors);
    final doc =
        StyleDocument(borders: {'top': 0, 'left': 0, 'right': 0, 'bottom': 30});
    final palette = StyleNode(type: 'palette', anchor: 'bottom', x: 50, y: 50);
    doc.nodes.add(palette);
    doc.order.add(palette.id);
    final output = await renderStyledPhoto(file.path, doc, {}, true);
    await File('${directory.path}/palette.png').writeAsBytes(output);
    final decoded = img.decodePng(output)!;
    final geometry = StyleGeometry(doc, 2.5), point = geometry.point(palette);
    final card = paletteSize(palette.palette), scale = 240 / 1000;
    for (var i = 0; i < 6; i++) {
      final x = point.dx -
          card.width / 2 +
          palette.palette.size / 2 +
          i * (palette.palette.size + palette.palette.gap);
      final color =
          decoded.getPixel((x * scale).floor(), (point.dy * scale).floor());
      expect(color.r, actualColors[i] >> 16 & 255);
      expect(color.g, actualColors[i] >> 8 & 255);
      expect(color.b, actualColors[i] & 255);
    }
  });
}
