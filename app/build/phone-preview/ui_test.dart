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

void main() {
  testWidgets('手机经典：分组提示、图片标识占位说明', (tester) async {
    tester.view.physicalSize = const Size(1400, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final output = Directory(
        'build/phone-preview/ui-${DateTime.now().millisecondsSinceEpoch}');
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
      store = PresetStore(File('${output.path}/users.json'));
      await store.load();
    });
    store.libraryFolder = 'builtin:phone';
    final settings = WorkspaceSettings(File('${output.path}/settings.json'));
    final boundary = GlobalKey();
    // 缩略图在后台异步解码占位图，界面上一直有加载动画，用固定轮数的真实等待代替 pumpAndSettle。
    Future<void> settle() async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> capture(String name) async {
      await settle();
      await tester.runAsync(() async {
        final img = await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 1.25);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await File('${output.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
    }

    final entry = store.entries.firstWhere((e) => e.id == 'phone-bar-white');
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
                sourceKey: 'phone-ui',
                settings: settings,
                presets: store,
                metadata: (_) async => {},
                apply: (_, __) async {}))));
    await settle();
    expect(tester.takeException(), null);
    expect(find.textContaining('与任何手机或相机品牌无关'), findsOneWidget);
    await capture('phone-folder-note');
    await tester.tap(find.text('品牌标识（占位）').first);
    await settle();
    expect(find.textContaining('灰色占位图'), findsOneWidget);
    await capture('image-panel-note');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
