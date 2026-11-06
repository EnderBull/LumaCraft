import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/photo_state.dart';
import 'package:lumacraft/ui/photo_thumb.dart';
import 'package:lumacraft/ui/app_theme.dart';

/// 缩略图不能长期占用照片文件，否则用户在资源管理器里删不掉。
/// 等缩略图解码完成后（而不是解码过程中）再去删，应当成功。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
  }

  bool tryDelete(File file) {
    try {
      file.deleteSync();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  testWidgets('JPG 缩略图显示后不再占用文件', (tester) async {
    final dir = Directory('build/export-ui-check-0164-lock/jpg2')
      ..createSync(recursive: true);
    final picture = img.Image(width: 200, height: 140);
    img.fill(picture, color: img.ColorRgb8(60, 110, 170));
    final file = File('${dir.path}/a.jpg')
      ..writeAsBytesSync(img.encodeJpg(picture));
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 80, height: 60, child: PhotoThumb(file))))));
    await settle(tester);
    expect(tryDelete(file), isTrue, reason: '缩略图显示后文件应可删除');
  });

  /// 删除在 Windows 上可能因短暂读取而失败，重试几次再判定。
  Future<bool> tryDeleteWithRetry(WidgetTester tester, File file) async {
    for (var i = 0; i < 10; i++) {
      try {
        file.deleteSync();
        return true;
      } on FileSystemException {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump();
      }
    }
    return false;
  }

  testWidgets('删除的缩略图会从缓存移除', (tester) async {
    final dir = Directory('build/export-ui-check-0164-lock/forget')
      ..createSync(recursive: true);
    final picture = img.Image(width: 120, height: 90);
    img.fill(picture, color: img.ColorRgb8(30, 90, 160));
    final file = File('${dir.path}/b.jpg')
      ..writeAsBytesSync(img.encodeJpg(picture));
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 80, height: 60, child: PhotoThumb(file))))));
    await settle(tester);
    forgetThumbnail(file.path);
    await tester.pump();
    expect(tryDelete(file), isTrue);
  });
}
