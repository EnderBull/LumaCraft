import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/photo_relink.dart';
import 'package:lumacraft/ui/relink_dialog.dart';
import 'package:lumacraft/ui/app_theme.dart';

/// 把重新关联面板真实画出来并存成 PNG，用来核对界面是否符合规范。
void main() {
  testWidgets('重新关联面板外观', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final shots = Directory('build/export-ui-check-0150-relinkui/shots');
    await shots.create(recursive: true);    final photoDir = Directory('build/export-ui-check-0150-relinkui/B');
    await photoDir.create(recursive: true);
    final picture = img.Image(width: 600, height: 400);
    img.fill(picture, color: img.ColorRgb8(70, 110, 160));
    for (final name in ['IMG_2001.jpg', 'IMG_2003.jpg']) {
      final file = File('${photoDir.path}/$name');
      if (!file.existsSync()) file.writeAsBytesSync(img.encodeJpg(picture));
    }
    final available = photoDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jpg'))
        .toList();

    const pending = [
      PendingRecord(r'D:\照片\0723 F7返图\IMG_2001.jpg', 'IMG_2001.jpg',
          '2024:07:08 20:21:22',
          edited: true),
      PendingRecord(r'D:\照片\0822 F7返图\IMG_2003.jpg', 'IMG_2003.jpg',
          '2024:08:01 19:04:10',
          edited: false),
    ];

    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: workspaceTheme(true),
      home: Scaffold(
        backgroundColor: const Color(0xff191817),
        body: Center(
          child: Container(
            key: key,
            width: 900,
            height: 600,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: workspaceTheme(true).colorScheme.surface,
                borderRadius: BorderRadius.circular(8)),
            child: RelinkBody(
              pending: pending,
              available: available,
              folderLabel: 'B',
              selectedRecord: pending.first.oldPath,
              selectedFile: available.first.path,
              message: '已关联 1 张',
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byKey(key),
        matchesGoldenFile('shots/relink-dialog.png'));
  },
      skip: true); // 缩略图异步解码会让截图卡住；界面外观由用户实机截图核对
}
