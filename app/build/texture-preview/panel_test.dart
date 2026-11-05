import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/fonts/font_catalog.dart';
import 'package:lumacraft/editor/preset_store.dart';
import 'package:lumacraft/ui/editor/editor_page.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/workspace_settings.dart';

// 编辑器“边框纹理”面板与“沿长边”选项截图，只写 build/texture-preview。

void main() {
  testWidgets('边框纹理面板与胶片沿长边截图', (tester) async {
    tester.view.physicalSize = const Size(1400, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final output = Directory(
        'build/texture-preview/run-${DateTime.now().millisecondsSinceEpoch}');
    late PresetStore store;
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
        await File('build/texture-preview/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
    }

    Future<void> open(String id) async {
      final entry = store.entries.firstWhere((e) => e.id == id);
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
                  initial: entry.style,
                  initialBuiltinId: entry.id,
                  sourceKey: 'test-$id',
                  settings: settings,
                  presets: store,
                  metadata: (_) async => {},
                  apply: (_, __) async {}))));
      await settle();
      await tester.tap(find.text('画布').first);
      await settle();
      expect(tester.takeException(), null);
    }

    await open('kraft-letter');
    await tester.ensureVisible(find.text('边框纹理'));
    await capture('texture-panel');
    await tester.tap(find.text('纸张'));
    await settle();
    await capture('texture-style-menu');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle();
    await tester.tap(find.text('牛皮纸'));
    await settle();
    await capture('texture-kind-menu');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle();

    await open('film-strip');
    await tester.ensureVisible(find.text('沿长边'));
    await capture('film-panel');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    await settle();
  });
}
