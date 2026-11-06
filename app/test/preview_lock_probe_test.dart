import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/export/color_management.dart';
import 'package:lumacraft/photo_state.dart';

/// 找出预览之后到底是谁还占着照片文件。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('预览解码后可以删除', () async {
    final dir = Directory('build/export-ui-check-0173-probe')
      ..createSync(recursive: true);
    final picture = img.Image(width: 200, height: 140);
    img.fill(picture, color: img.ColorRgb8(60, 110, 170));
    final file = File('${dir.path}/probe.jpg')
      ..writeAsBytesSync(img.encodeJpg(picture));
    final image = await decodePhotoImage(file.path, maxEdge: 1200);
    final deleted = () {
      try {
        file.deleteSync();
        return true;
      } on FileSystemException {
        return false;
      }
    }();
    image.dispose();
    expect(deleted, isTrue, reason: '预览解码后文件应可删除');
  });

  test('读取拍摄信息后可以删除', () async {
    final dir = Directory('build/export-ui-check-0173-probe2')
      ..createSync(recursive: true);
    final picture = img.Image(width: 200, height: 140);
    img.fill(picture, color: img.ColorRgb8(60, 110, 170));
    final file = File('${dir.path}/probe.jpg')
      ..writeAsBytesSync(img.encodeJpg(picture));
    readCapture(file.path);
    photoFingerprint(file.path);
    try {
      file.deleteSync();
    } on FileSystemException catch (e) {
      fail('读信息后文件被占用：$e');
    }
  });
}
