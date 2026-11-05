import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/fonts/font_catalog.dart';
import 'package:lumacraft/editor/preset_store.dart';
import 'package:lumacraft/editor/shape_style.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/ui/editor/editor_page.dart';
import 'package:lumacraft/ui/editor/shape_picker.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/workspace_settings.dart';

void main() {
  testWidgets('形状组件：属性面板、抓点与旋转截图', (tester) async {
    tester.view.physicalSize = const Size(1400, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final output = Directory(
        'build/shape-preview/run-${DateTime.now().millisecondsSinceEpoch}');
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
    final settings = WorkspaceSettings(File('${output.path}/settings.json'));
    final boundary = GlobalKey();
    // 缩略图在后台异步解码素材，界面上有持续的加载动画，用固定轮数的真实等待代替 pumpAndSettle。
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
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
        await File('${output.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
    }

    final doc = StyleDocument(
        name: '形状预览', borders: {'top': 3, 'right': 3, 'bottom': 20, 'left': 3});
    final nodes = [
      StyleNode(type: 'shape', name: '分隔线', anchor: 'bottom', x: 50, y: 50)
        ..shape = (ShapeStyle()
          ..applyKind('line')
          ..width = 260),
      StyleNode(type: 'shape', name: '三角形', anchor: 'photo', x: 30, y: 50)
        ..shape = (ShapeStyle(
            kind: 'triangle',
            width: 200,
            height: 173,
            fillColor: 0xffd7aa59,
            fillColor2: 0xff8a6a2a)
          ..split = true),
      StyleNode(type: 'shape', name: '梯形', anchor: 'photo', x: 70, y: 50)
        ..shape = (ShapeStyle(
            kind: 'trapezoid',
            width: 240,
            height: 140,
            fillColor: 0xff3a6ea5,
            radius: 14,
            rotation: 20)
          ..stroke = true
          ..strokeColor = 0xffffffff
          ..strokeOpacity = 60
          ..strokeWidth = 6),
    ];
    for (final n in nodes) {
      doc.nodes.add(n);
      doc.order.add(n.id);
    }
    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: MaterialApp(
            theme: workspaceTheme(true),
            debugShowCheckedModeBanner: false,
            home: PresetEditor(
                files: const [],
                current: 0,
                selected: const {},
                initial: doc,
                sourceKey: 'shape-preview',
                settings: settings,
                presets: store,
                metadata: (_) async => {},
                apply: (_, __) async {}))));
    await settle();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await settle();
    expect(tester.takeException(), null);
    await capture('all-shapes');
    await tester.tap(find.text('梯形').first);
    await settle();
    await capture('trapezoid-selected');
    await tester.tap(find.text('三角形').first);
    await settle();
    await capture('triangle-selected');
    // 形状选择器：展开后的 4×2 图标网格。
    await tester.tap(find.byType(ShapePicker));
    await settle();
    await capture('shape-picker-open');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle();
    // 坐标取自上一张截图：逻辑坐标 = 截图坐标 / 1024 * 1400。
    Offset at(double x, double y) => Offset(x / 1024 * 1400, y / 702 * 960);
    Future<void> drag(Offset from, Offset to, String name) async {
      final g = await tester.startGesture(from);
      await tester.pump();
      for (var i = 1; i <= 8; i++) {
        await g.moveTo(Offset.lerp(from, to, i / 8)!);
        await tester.pump();
      }
      if (name.isNotEmpty) await capture('$name-during');
      await g.up();
      await settle();
      if (name.isNotEmpty) await capture(name);
    }

    // 三角形：拖右下角方块放大、拖金色圆点加圆角。
    await drag(at(413, 315), at(450, 345), 'triangle-resized');
    await drag(at(437, 344), at(395, 344), 'triangle-rounded');
    // 三角形：上方旋转抓点。
    await tester.tap(find.text('三角形').first);
    await settle();
    await capture('triangle-before-rotate');
    await drag(at(383, 239), at(470, 270), 'triangle-rotated');
    // 梯形：金色圆点调上边收窄。
    await tester.tap(find.text('梯形').first);
    await settle();
    await drag(at(559, 262), at(585, 258), 'trapezoid-adjusted');
    await tester.tap(find.text('分隔线').first);
    await settle();
    await capture('line-selected');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    await settle();
  });
}
