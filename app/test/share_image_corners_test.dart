import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// 保存分享图时要把底栏裁掉，但下边缘仍要有圆角。
/// 这里直接验证圆角处理：四角透明、中间不透明，尺寸不变。
void main() {
  test('下边缘两角变透明，其余保持', () {
    // 复刻面板的实际像素：1200×900，圆角半径 28。
    final image = img.Image(width: 1200, height: 900);
    img.fill(image, color: img.ColorRgb8(40, 38, 35));
    final png = Uint8List.fromList(img.encodePng(image));
    // 与对话框内同一段逻辑
    final rounded = _round(png, 28);
    final back = img.decodePng(rounded)!;
    expect(back.width, 1200);
    expect(back.height, 900);
    // 左下角、右下角应为透明。
    expect(back.getPixel(0, 899).a, 0);
    expect(back.getPixel(1199, 899).a, 0);
    // 底边中间、顶部两角必须仍然不透明。
    expect(back.getPixel(600, 899).a, 255);
    expect(back.getPixel(0, 0).a, 255);
    expect(back.getPixel(1199, 0).a, 255);
  });
}

Uint8List _round(Uint8List png, int radius) {
  final image = img.decodePng(png)!;
  final canvas = image.hasAlpha ? image : image.convert(numChannels: 4);
  final width = canvas.width, height = canvas.height;
  final cy = height - 1 - radius;
  for (var y = height - radius; y < height; y++) {
    final dy = y - cy;
    for (var x = 0; x < radius; x++) {
      final dx = x - radius;
      if (dx * dx + dy * dy > radius * radius)
        canvas.setPixelRgba(x, y, 0, 0, 0, 0);
      final rx = width - 1 - x - (width - 1 - radius);
      if (rx * rx + dy * dy > radius * radius)
        canvas.setPixelRgba(width - 1 - x, y, 0, 0, 0, 0);
    }
  }
  return Uint8List.fromList(img.encodePng(canvas));
}
