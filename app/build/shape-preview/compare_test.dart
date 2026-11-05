import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/editor/builtin_library.dart';
import 'package:lumacraft/editor/style_render.dart';
import 'package:lumacraft/fonts/font_catalog.dart';

// 对比内置预设“字符短线 → 形状”前后的实际成片：同一张照片、同一比例，逐像素比较。
void main() {
  testWidgets('字符短线与形状短线的成片对比', (tester) async {
    await tester.runAsync(() async {
      for (final f in artworkFonts) {
        await (FontLoader(f.family)..addFont(rootBundle.load(f.asset))).load();
      }
      final before = BuiltinLibrary.decode(
          await File('build/shape-preview/compare/library-before.json')
              .readAsString());
      final after = BuiltinLibrary.decode(
          await File('assets/builtins/library.json').readAsString());
      final out = Directory('build/shape-preview/compare')..createSync();
      for (final size in [(1500, 1000), (1333, 1000), (1000, 1500), (1000, 1000)]) {
        final photo = img.Image(width: size.$1, height: size.$2);
        img.fill(photo, color: img.ColorRgb8(120, 130, 140));
        final file = File('${out.path}/photo-${size.$1}x${size.$2}.jpg');
        await file.writeAsBytes(img.encodeJpg(photo, quality: 100));
        for (final id in ['gallery', 'travel']) {
          final a = await renderStyledPhoto(file.path,
              before.entries.firstWhere((e) => e.id == id).style, {}, true);
          final b = await renderStyledPhoto(file.path,
              after.entries.firstWhere((e) => e.id == id).style, {}, true);
          final ia = img.decodePng(a)!, ib = img.decodePng(b)!;
          expect(ia.width, ib.width);
          expect(ia.height, ib.height);
          var changed = 0, strong = 0, maxDiff = 0;
          var minX = 1 << 30, minY = 1 << 30, maxX = -1, maxY = -1;
          for (var y = 0; y < ia.height; y++) {
            for (var x = 0; x < ia.width; x++) {
              final p = ia.getPixel(x, y), q = ib.getPixel(x, y);
              final d = ((p.r - q.r).abs() + (p.g - q.g).abs() + (p.b - q.b).abs())
                  .toInt();
              if (d > 0) {
                changed++;
                if (d > maxDiff) maxDiff = d;
                if (d > 90) strong++;
                if (x < minX) minX = x;
                if (x > maxX) maxX = x;
                if (y < minY) minY = y;
                if (y > maxY) maxY = y;
              }
            }
          }
          // ignore: avoid_print
          print('RESULT $id ${size.$1}x${size.$2}: changed=$changed strong(>90)=$strong '
              'maxDiff=$maxDiff bbox=($minX,$minY)-($maxX,$maxY)');
          await File('${out.path}/$id-${size.$1}x${size.$2}-before.png')
              .writeAsBytes(a);
          await File('${out.path}/$id-${size.$1}x${size.$2}-after.png')
              .writeAsBytes(b);
        }
      }
    });
  });
}
