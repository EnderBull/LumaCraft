import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/builtin_library.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/fonts/font_catalog.dart';
import 'package:lumacraft/editor/preset_store.dart';
import 'package:lumacraft/ui/editor/editor_page.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/workspace_settings.dart';

// 0.13.0 面板截图：纹理填充、纹理缩略图、边框造型（邮票 / 车票）、内置邮戳。只写 build/stamp-presets/panel。

void main() {
  testWidgets('0.13.0 面板截图', (tester) async {
    tester.view.physicalSize = const Size(1400, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final output = Directory(
        'build/stamp-presets/panel/run-${DateTime.now().millisecondsSinceEpoch}');
    late PresetStore store;
    late BuiltinLibrary drafts;
    await tester.runAsync(() async {
      await output.create(recursive: true);
      for (final f in artworkFonts) {
        await (FontLoader(f.family)..addFont(rootBundle.load(f.asset))).load();
      }
      for (final family in ['Microsoft YaHei UI', 'Microsoft YaHei']) {
        await (FontLoader(family)
              ..addFont(File('C:/Windows/Fonts/msyh.ttc')
                  .readAsBytes()
                  .then(ByteData.sublistView)))
            .load();
      }
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
      store = PresetStore(File('${output.path}/users.json'), authoring: true);
      await store.load();
      drafts = BuiltinLibrary.decode(
          await File('build/stamp-presets/drafts.json').readAsString());
    });
    final settings = WorkspaceSettings(File('${output.path}/settings.json'));
    final boundary = GlobalKey();
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 30));
      }
    }

    Future<void> capture(String name) async {
      await settle();
      await tester.runAsync(() async {
        final img = await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 1.25);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await File('build/stamp-presets/panel/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
    }

    Future<void> open(String id, StyleDocument style, String tab) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(RepaintBoundary(
          key: boundary,
          child: MaterialApp(
              theme: workspaceTheme(true),
              debugShowCheckedModeBanner: false,
              home: PresetEditor(
                  files: const [],
                  current: 0,
                  selected: const {},
                  initial: style,
                  sourceKey: 'test-$id',
                  settings: settings,
                  presets: store,
                  metadata: (_) async => {},
                  apply: (_, __) async {}))));
      await settle();
      await tester.tap(find.text(tab).first);
      await settle();
      expect(tester.takeException(), null);
    }

    StyleDocument builtin(String id) =>
        store.entries.firstWhere((e) => e.id == id).style;
    StyleDocument draft(String id) =>
        drafts.entries.firstWhere((e) => e.id == id).style;

    // 纹理：填充方式里选“纹理”，下方是纹理风格 + 缩略图选择器。
    await open('kraft-letter', builtin('kraft-letter'), '画布');
    await tester.ensureVisible(find.text('纹理风格'));
    await capture('texture-fill-panel');
    await tester.tap(find.text('牛皮纸'));
    await settle();
    await capture('texture-picker-menu');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle();
    await tester.tap(find.text('纸张'));
    await settle();
    await tester.tap(find.text('高级').last);
    await settle();
    await tester.tap(find.text('大理石'));
    await settle();
    await capture('texture-picker-luxe');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle();

    // 边框造型：车票（横向分割）与票根（纵向分割）。
    await open('ticket', draft('ticket'), '画布');
    await tester.ensureVisible(find.text('分割线颜色'));
    await capture('ticket-panel');
    await tester.ensureVisible(find.text('造型'));
    await tester.tap(find.text('邮票打孔').first);
    await settle();
    await capture('shape-menu');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle();

    // 内置邮戳：选中邮戳图层，面板里有“内置邮戳”和墨色。
    await open('stamp-blur', draft('stamp-blur'), '组件');
    await tester.tap(find.text('邮戳').first);
    await settle();
    await tester.ensureVisible(find.text('邮戳墨色'));
    await capture('postmark-panel');
    await tester.ensureVisible(find.text('内置邮戳'));
    await settle();
    await tester.tap(find.text('内置邮戳'));
    await settle();
    await capture('postmark-menu');
    await tester.tap(find.text('椭圆邮戳'));
    await settle();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.tap(find.text('红'));
    await settle();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)));
    await capture('postmark-red-oval');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    await settle();
  });
}
