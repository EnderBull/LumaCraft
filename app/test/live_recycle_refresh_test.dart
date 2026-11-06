import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/main.dart' as app;
import 'package:lumacraft/photo_state.dart';

/// 删除到回收站（不进「彻底删除」通道）后，软件也要自己跟上。
///
/// 单独成一个文件：同一个文件里连续挂载两次主界面会互相干扰，
/// 每个测试文件跑在独立进程里，这样测的就是真实的一条路径。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitTicks(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('浏览模式：删除到回收站后列表和底栏同步减少', (tester) async {
    expect(Platform.environment['LUMACRAFT_DATA_DIR'],
        contains('export-ui-check'));
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Directory dir;
    await tester.runAsync(() async {
      dir = await Directory(
              'test/live-recycle-${DateTime.now().microsecondsSinceEpoch}')
          .create(recursive: true);
      final picture = img.Image(width: 120, height: 80);
      img.fill(picture, color: img.ColorRgb8(90, 130, 160));
      final bytes = img.encodeJpg(picture);
      for (var i = 0; i < 3; i++) {
        await File('${dir.path}/p$i.jpg').writeAsBytes(bytes);
      }
      final root = PhotoStore.defaultFile().parent;
      await root.create(recursive: true);
      await File('${root.path}/workspace.json').writeAsString(
          jsonEncode({'version': 1, 'lastDirectory': dir.path}));
    });
    await tester.pumpWidget(const app.LumaCraftApp());
    final dynamic state = tester.state(find.byType(app.Workshop));
    for (var i = 0; i < 100 && (state.ready != true || state.files.length != 3);
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(state.files.length, 3);
    // 先让预览都解码完：用户是在空闲时手动删的。
    await waitTicks(tester, 3);
    // 真正走一次资源管理器的「删除到回收站」。
    var gone = false;
    for (var i = 0; i < 10 && !gone; i++) {
      final result = await tester.runAsync(() async {
        final ps = 'Add-Type -AssemblyName Microsoft.VisualBasic;'
            r"[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('" +
            '${dir.path}/p2.jpg' +
            r"','OnlyErrorDialogs','SendToRecycleBin')";
        return Process.run('powershell', ['-NoProfile', '-Command', ps]);
      });
      gone = result != null &&
          result.exitCode == 0 &&
          !File('${dir.path}/p2.jpg').existsSync();
    }
    expect(gone, isTrue, reason: '照片应能被移到回收站（软件不能占用文件）');
    await waitTicks(tester, 6);
    expect(state.files.length, 2, reason: '移到回收站的一张也要自己从列表消失');
    expect(find.textContaining('p2.jpg'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 3)));
}
