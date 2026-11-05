import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
      store = PresetStore(File('${output.path}/users.json'), authoring: true);
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
                initialBuiltinId: entry.id,
                sourceKey: 'phone-ui',
                settings: settings,
                presets: store,
                metadata: (_) async => {},
                apply: (_, __) async {}))));
    await settle();
    expect(tester.takeException(), null);
    expect(find.textContaining('与任何手机或相机品牌无关'), findsOneWidget);
    // 底栏：缩放比例和“适合窗口”必须紧贴中间画布区的右下角（右侧留白只有行边距加按钮内边距）。
    final bar = find.ancestor(
        of: find.text('适合窗口'),
        matching: find.byWidgetPredicate((w) => w is SizedBox && w.height == 60));
    expect(bar, findsOneWidget);
    final gap = tester.getTopRight(bar).dx - tester.getTopRight(find.text('适合窗口')).dx;
    expect(gap, lessThan(36), reason: '适合窗口右侧空了 $gap px');
    await capture('phone-folder-note');
    await tester.tap(find.text('品牌标识（占位）').first);
    await settle();
    expect(find.textContaining('灰色占位图'), findsOneWidget);
    await capture('image-panel-note');
    // 状态提示：布局名｜状态词，一条细竖线分隔，没有圆点和“·”。
    expect(find.text('横图布局'), findsOneWidget);
    expect(find.text('草稿'), findsOneWidget);
    final pill = find.byWidgetPredicate(
        (w) => w is Tooltip && w.message == '草稿预览，尚未应用到照片');
    expect(pill, findsOneWidget);
    for (final symbol in ['●', '·', '草稿预览', '尚未应用']) {
      expect(find.descendant(of: pill, matching: find.textContaining(symbol)),
          findsNothing,
          reason: '提示框里不应再有 $symbol');
    }
    await capture('status-pill');
    // 添加组件：轻量下拉菜单，3×3 图标平铺。
    await tester.tap(find.text('添加组件').first);
    await settle();
    for (final name in ['自由文字', '拍摄参数', '相机型号', '镜头型号', '拍摄时间', '拍摄地点', '照片色卡', '图片标识', '形状']) {
      expect(find.text(name), findsWidgets, reason: name);
    }
    expect(find.text('作者签名'), findsNothing);
    await capture('add-component-menu');
    await tester.tap(find.text('形状').last);
    await settle();
    expect(find.text('7 个组件'), findsOneWidget);
    // 编辑内置预设：工具条上的“恢复默认”按钮。
    expect(find.text('恢复默认'), findsOneWidget);
    await tester.tap(find.text('恢复默认'));
    await settle();
    await capture('restore-default-dialog');
    await tester.tap(find.widgetWithText(FilledButton, '恢复默认'));
    await settle();
    expect(find.text('6 个组件'), findsOneWidget, reason: '恢复默认后去掉了新加的形状');
    expect(find.textContaining('已恢复默认'), findsOneWidget);
    // 预设卡片右键菜单：内置预设可“恢复默认”。
    await tester.tap(find.text('预设').first);
    await settle();
    await tester.tap(find.text('底栏参数条·白').first, buttons: kSecondaryButton);
    await settle();
    expect(
        find.descendant(
            of: find.byType(PopupMenuItem<String>),
            matching: find.text('恢复默认')),
        findsOneWidget);
    await capture('card-menu');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle();
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
