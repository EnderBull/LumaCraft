import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/fonts/font_catalog.dart';
import 'package:lumacraft/editor/preset_store.dart';
import 'package:lumacraft/editor/style_render.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/ui/builtin_manager.dart';
import 'package:lumacraft/ui/editor/editor_page.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/workspace_settings.dart';

void main() {
  testWidgets('维护入口、原位字体菜单与保存内置预设截图', (tester) async {
    tester.view.physicalSize = const Size(1400, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final output = Directory(
        'build/builtin-preview/run-${DateTime.now().millisecondsSinceEpoch}');
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
      await (FontLoader('Georgia')
            ..addFont(File('C:/Windows/Fonts/georgia.ttf')
                .readAsBytes()
                .then(ByteData.sublistView)))
          .load();
      store = PresetStore(File('${output.path}/users.json'), authoring: true);
      await store.load();
    });
    final settings = WorkspaceSettings(File('${output.path}/settings.json'));
    final boundary = GlobalKey();
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final img = await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 1.25);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await File('build/builtin-preview/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
    }

    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: MaterialApp(
            theme: workspaceTheme(true),
            debugShowCheckedModeBanner: false,
            home: Scaffold(
                body: BuiltinManager(
                    store: store,
                    preview: (e) => ColoredBox(
                        color: Color(e.style.background),
                        child: Center(
                            child: Text(e.style.name,
                                style:
                                    artworkTextStyle(e.style.nodes.first.font)
                                        .copyWith(
                                            color: const Color(0xffbcaa8c),
                                            fontSize: 22)))))))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    await capture('manager');
    await tester.tap(find.text('新建分组'));
    await tester.pumpAndSettle();
    expect(find.text('分组名称'), findsOneWidget);
    await capture('new-group');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    final entry = store.entries.first;
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
                sourceKey: 'test-builtin',
                settings: settings,
                presets: store,
                metadata: (_) async => {},
                apply: (_, __) async {}))));
    await tester.pumpAndSettle();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    await tester.tap(find.text('题签').first);
    await tester.pumpAndSettle();
    await capture('editor');
    await tester.tap(find.text('Playfair Display'));
    await tester.pumpAndSettle();
    await capture('font-menu');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存预设'));
    await tester.pumpAndSettle();
    expect(find.text('保存内置预设'), findsOneWidget);
    await capture('save-builtin');
    final name = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '画廊签名');
    await tester.enterText(name, '手工维护样式');
    await tester.tap(find.text('保存内置'));
    await tester.pump();
    for (var i = 0; i < 30 && store.entries.first.style.name != '手工维护样式'; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(store.entries.first.style.name, '手工维护样式');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
