import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/editor/preset_store.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/main.dart' as app;
import 'package:lumacraft/photo_state.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/ui/editor/editor_page.dart';
import 'package:lumacraft/workspace_settings.dart';

/// 照片在软件外面被彻底删除（Shift+Delete，不进回收站）后，
/// 浏览模式和编辑模式都必须自己跟上，不需要切换目录。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Directory> photos(WidgetTester tester, String tag, int count) async {
    late Directory dir;
    await tester.runAsync(() async {
      dir = await Directory(
              'test/live-delete-$tag-${DateTime.now().microsecondsSinceEpoch}')
          .create(recursive: true);
      final picture = img.Image(width: 120, height: 80);
      img.fill(picture, color: img.ColorRgb8(90, 130, 160));
      final bytes = img.encodeJpg(picture);
      for (var i = 0; i < count; i++) {
        await File('${dir.path}/p$i.jpg').writeAsBytes(bytes);
      }
    });
    return dir;
  }

  /// 等一会儿真实时间并多次 pump，让定时核对有机会跑完。
  Future<void> waitTicks(WidgetTester tester, {int seconds = 5}) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('浏览模式：外部删除后列表和底栏同步减少', (tester) async {
    expect(Platform.environment['LUMACRAFT_DATA_DIR'],
        contains('export-ui-check'));
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = await photos(tester, 'browse', 3);
    await tester.runAsync(() async {
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
    // 等软件把预览都解码完，用户是在空闲时手动删的。
    await waitTicks(tester, seconds: 3);
    var gone = false;
    for (var i = 0; i < 20 && !gone; i++) {
      gone = await tester.runAsync(() async {
        try {
          await File('${dir.path}/p0.jpg').delete();
          return true;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return false;
        }
      }) ??
          false;
    }
    expect(gone, isTrue, reason: '照片应能在软件外被彻底删除');
    await waitTicks(tester, seconds: 6);
    expect(state.files.length, 2, reason: '彻底删除的一张要自己从列表消失');
    expect(find.textContaining('p0.jpg'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('编辑模式：外部删除后照片条同步减少', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = await photos(tester, 'editor', 3);
    final files = [
      for (var i = 0; i < 3; i++) File('${dir.path}/p$i.jpg'),
    ];
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: PresetEditor(
            files: files,
            current: 0,
            selected: {files.first.path},
            initial: StyleDocument.template(),
            settings: WorkspaceSettings(File('${dir.path}/workspace.json')),
            presets: _MemoryPresets(File('${dir.path}/presets.json')),
            metadata: (f) async => <String, String>{},
            initialDirectory: dir.path,
            apply: (doc, paths) async {})));
    await waitTicks(tester, seconds: 4);
    expect(find.textContaining('3 张照片'), findsWidgets);
    await tester.runAsync(() => File('${dir.path}/p1.jpg').delete());
    await waitTicks(tester, seconds: 6);
    expect(find.textContaining('2 张照片'), findsWidgets,
        reason: '编辑模式删除照片后照片条要跟着少一张');
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 2)));
}

class _MemoryPresets extends PresetStore {
  _MemoryPresets(super.file);
  @override
  Future<void> save(
      {StyleDocument? draft,
      List<UserPreset>? presets,
      String? sourceKey}) async {
    if (draft != null) this.draft = draft.copy();
    if (presets != null) this.presets = presets;
  }
}
