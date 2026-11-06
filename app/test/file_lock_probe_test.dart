import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/export/color_management.dart';
import 'package:lumacraft/photo_state.dart';

/// 找出到底哪一步会锁住照片文件：读完、算完指纹之后还能不能删除。
void main() {
  late File file;
  setUp(() {
    final dir = Directory('build/export-ui-check-0164-probe')
      ..createSync(recursive: true);
    final picture = img.Image(width: 200, height: 140);
    img.fill(picture, color: img.ColorRgb8(60, 110, 170));
    file = File('${dir.path}/probe.jpg')
      ..writeAsBytesSync(img.encodeJpg(picture));
  });

  bool canDelete(File target) {
    try {
      target.deleteSync();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  test('只读字节不锁', () {
    file.readAsBytesSync();
    expect(canDelete(file), isTrue);
  });

  test('判断广色域后不锁', () {
    jpegUsesWideGamut(file.path);
    expect(canDelete(file), isTrue);
  });

  test('算指纹后不锁', () {
    photoFingerprint(file.path);
    expect(canDelete(file), isTrue);
  });

  test('读拍摄信息后不锁', () {
    readCapture(file.path);
    expect(canDelete(file), isTrue);
  });

  test('解码成图片后释放 codec 仍不锁', () async {
    final bytes = file.readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes,
        targetWidth: 240, allowUpscaling: false);
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    expect(canDelete(file), isTrue);
    image.dispose();
  });

  test('用文件路径建缓冲后释放不锁', () async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
    buffer.dispose();
    expect(canDelete(file), isTrue);
  });
}
