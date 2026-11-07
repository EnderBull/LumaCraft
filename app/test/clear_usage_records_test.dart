import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/photo_state.dart';
import 'package:lumacraft/settings/app_settings.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/ui/settings_dialog.dart';
import 'package:lumacraft/usage_data.dart';
import 'package:lumacraft/workspace_settings.dart';

/// 清理使用记录：文件删掉后，已排队或延迟的保存、关窗时的保存，
/// 都不能把旧数据写回；内置预设工作库和照片不能被碰。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late Directory photos;
  late AppSettings app;
  late WorkspaceSettings workspace;
  late PhotoStore store;

  setUp(() async {
    UsageData.reset();
    dir = PhotoStore.defaultFile().parent;
    expect(dir.path, contains('export-ui-check'),
        reason: '测试必须在隔离数据目录里跑，不能删到真实数据');
    await dir.create(recursive: true);
    for (final name in UsageData.targetNames()) {
      final f = File('${dir.path}/$name');
      if (await f.exists()) await f.delete();
    }
    photos = await Directory(
            'build/export-ui-check-clear/photos-${DateTime.now().microsecondsSinceEpoch}')
        .create(recursive: true);
    for (final name in UsageData.files) {
      await File('${dir.path}/$name').writeAsString('{"old":true}');
    }
    await File('${dir.path}/export-recovery.dismissed').writeAsString('x');
    await File('${dir.path}/builtin-working.json').writeAsString('KEEP');
    await File('${dir.path}/export-batch-123.json').writeAsString('{}');
    await File('${photos.path}/a.jpg').writeAsBytes([1, 2, 3]);
    app = AppSettings(File('${dir.path}/app-settings.json'));
    workspace = WorkspaceSettings(File('${dir.path}/workspace.json'));
    store = PhotoStore(File('${dir.path}/photo-state.json'));
  });

  tearDown(() {
    // 数据目录是同一批测试共用的，别把假数据留给别的用例。
    for (final name in UsageData.targetNames()) {
      final f = File('${dir.path}/$name');
      if (f.existsSync()) f.deleteSync();
    }
    for (final f in dir.listSync().whereType<File>()) {
      if (f.path.contains('export-batch-') || f.path.endsWith('builtin-working.json')) {
        f.deleteSync();
      }
    }
    UsageData.reset();
    app.dispose();
    workspace.dispose();
  });

  bool exists(String name) => File('${dir.path}/$name').existsSync();

  /// 真实时间里等一会儿，让延迟保存的定时器有机会触发。
  Future<void> settle(WidgetTester tester, int ms) async {
    for (var i = 0; i < ms ~/ 50; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: Scaffold(
            body: SettingsDialog(workspace: workspace, app: app))));
    await tester.pump();
  }

  test('清理后，延迟保存、排队保存、关窗保存都不会把文件写回来', () async {
    // 一次改动留在防抖定时器里，一次已经排进写盘队列。
    workspace.lastDirectory = 'D:/旧目录';
    workspace.changed();
    app.autoFillPlace = false;
    app.changed();
    final queued = store.save();

    final result = await UsageData.clearAll(dir);
    expect(result.failed, isEmpty);
    await queued;
    // 关窗时各处都会再保存一次。
    await workspace.save();
    await app.flush();
    await store.save();
    await Future<void>.delayed(const Duration(milliseconds: 800));

    for (final name in UsageData.targetNames()) {
      expect(exists(name), isFalse, reason: '$name 清理后不应重现');
    }
    expect(File('${dir.path}/export-batch-123.json').existsSync(), isFalse,
        reason: '导出批次文件也要清掉');
    expect(File('${dir.path}/builtin-working.json').readAsStringSync(), 'KEEP',
        reason: '内置预设工作库必须保留');
    expect(File('${photos.path}/a.jpg').existsSync(), isTrue,
        reason: '照片必须保留');
  });

  test('删不掉的文件会逐个报出原因，重试后清干净，期间仍不写回', () async {
    // 保持句柄打开，Windows 上删除会因占用而失败。
    final locked = File('${dir.path}/workspace.json');
    final handle = await locked.open(mode: FileMode.append);
    var released = false;
    try {
      final first = await UsageData.clearAll(dir);
      if (first.failed.isEmpty) {
        // 个别环境允许删除被打开的文件，此时这条路径无法复现，跳过。
        markTestSkipped('当前环境允许删除被占用的文件');
        return;
      }
      expect(first.failed.single, contains('workspace.json'));
      expect(UsageData.frozen, isTrue, reason: '清理未完成时必须继续冻结写入');
      await workspace.save();
      expect(File('${dir.path}/workspace.json.pending').existsSync(), isFalse);
      await handle.close();
      released = true;
      final again = await UsageData.clearAll(dir);
      expect(again.failed, isEmpty);
      expect(exists('workspace.json'), isFalse);
    } finally {
      if (!released) await handle.close();
    }
  });

  test('放弃清理后恢复保存', () async {
    await UsageData.clearAll(dir);
    UsageData.unfreeze();
    await workspace.save();
    expect(exists('workspace.json'), isTrue);
  });

  testWidgets('界面：取消、点弹窗外、输错文字都不清理', (tester) async {
    await mount(tester);
    await tester.tap(find.text('清理…'));
    await tester.pumpAndSettle();
    // 输错
    await tester.enterText(find.byType(TextField), '清理');
    await tester.tap(find.text('确认清理').last);
    await tester.pump();
    expect(find.text('清理使用记录？'), findsOneWidget);
    // 取消
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('清理使用记录？'), findsNothing);
    // 点弹窗外
    await tester.tap(find.text('清理…'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('清理使用记录？'), findsNothing);
    await settle(tester, 300);
    for (final name in UsageData.files) {
      expect(exists(name), isTrue, reason: '$name 不应被清理');
    }
    expect(UsageData.frozen, isFalse);
  });

  testWidgets('界面：输入确认文字后清理、关闭软件，旧数据不重现', (tester) async {
    var closed = 0;
    final original = restartApp;
    restartApp = () async => closed++;
    addTearDown(() => restartApp = original);
    await mount(tester);
    workspace.lastDirectory = 'D:/旧目录';
    workspace.changed(); // 延迟保存还在等
    await tester.tap(find.text('清理…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '确认清理');
    await tester.tap(find.text('确认清理').last);
    await tester.pump();
    await settle(tester, 2000);
    for (final name in UsageData.targetNames()) {
      expect(exists(name), isFalse, reason: '$name 应已清理');
    }
    await settle(tester, 1500);
    expect(closed, 1, reason: '清理完成后要关闭并重新打开软件');
    // 关窗时的保存。
    await tester.runAsync(() async {
      await workspace.save();
      await app.flush();
    });
    await settle(tester, 600);
    for (final name in UsageData.targetNames()) {
      expect(exists(name), isFalse, reason: '关窗保存后 $name 不应重现');
    }
    expect(File('${dir.path}/builtin-working.json').existsSync(), isTrue);
    expect(File('${photos.path}/a.jpg').existsSync(), isTrue);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 1)));

  testWidgets('界面：正在导出时拒绝清理', (tester) async {
    UsageData.exportsRunning = 1;
    await mount(tester);
    await tester.tap(find.text('清理…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '确认清理');
    await tester.tap(find.text('确认清理').last);
    await tester.pumpAndSettle();
    await settle(tester, 300);
    for (final name in UsageData.files) {
      expect(exists(name), isTrue, reason: '导出中不能清理');
    }
    expect(UsageData.frozen, isFalse);
    UsageData.exportsRunning = 0;
  });
}
