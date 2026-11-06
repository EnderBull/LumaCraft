import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/ui/relink_dialog.dart';
import 'package:lumacraft/photo_relink.dart';

/// 右栏没有可关联照片时，“选择其他文件…”按钮也必须出现，
/// 否则用户根本没法手动挑照片。
void main() {
  testWidgets('没有可选照片时也能看到手动选择按钮', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var picked = 0;
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: Scaffold(
            body: SizedBox(
                width: 900,
                height: 520,
                child: RelinkBody(
                    pending: const [
                      PendingRecord(r'D:\照片\旧名.jpg', '旧名.jpg',
                          '2024:05:04 16:50:37',
                          edited: true),
                    ],
                    available: const [],
                    folderLabel: 'test',
                    onPickFiles: () => picked++)))));
    await tester.pump();
    expect(find.text('选择其他文件…'), findsOneWidget);
    expect(find.textContaining('还没有可手动选的照片'), findsOneWidget);
    await tester.tap(find.text('选择其他文件…'));
    expect(picked, 1);
  });

  testWidgets('有可选照片时按钮同样在', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: Scaffold(
            body: SizedBox(
                width: 900,
                height: 520,
                child: RelinkBody(
                    pending: const [],
                    available: [File('D:/照片/a.jpg')],
                    folderLabel: 'test',
                    onPickFiles: () {})))));
    await tester.pump();
    expect(find.text('选择其他文件…'), findsOneWidget);
  });
}
