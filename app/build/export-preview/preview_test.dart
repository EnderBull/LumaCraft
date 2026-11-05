import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/export/export_options.dart';
import 'package:lumacraft/ui/export/export_dialog.dart';
import 'package:lumacraft/ui/export/vertical_toggle.dart';
import 'package:lumacraft/ui/export/export_conflict_dialog.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/ui/export/naming_template_editor.dart';
import 'package:lumacraft/ui/editor/prototype_controls.dart';

void main() {
  testWidgets('导出面板命名模块交互及样式截图', (tester) async {
    tester.view.physicalSize = const Size(960, 1010);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (final family in ['Microsoft YaHei UI', 'Microsoft YaHei']) {
        final font = FontLoader(family)
          ..addFont(File('C:/Windows/Fonts/msyh.ttc')
              .readAsBytes()
              .then(ByteData.sublistView));
        await font.load();
      }
      final material = FontLoader('MaterialIcons')
        ..addFont(File(
                '.toolchain/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
            .readAsBytes()
            .then(ByteData.sublistView));
      await material.load();
    });
    final surface = GlobalKey();
    final options = ExportOptions()..directory = r'D:\照片\导出';
    final parts = defaultNamingTemplate();
    await tester.pumpWidget(RepaintBoundary(
        key: surface,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: workspaceTheme(true),
            home: Scaffold(
                body: ExportDialog(
                    options: options,
                    template: parts,
                    selectedCount: 8,
                    editedCount: 12,
                    chooseDirectory: () async => r'D:\照片\导出',
                    onCancel: () {},
                    onExport: () {})))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    Future<void> capture(String name) => tester.runAsync(() async {
          final image = await (surface.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1.5);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('build/export-preview/$name.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
    expect(parts.any((p) => p.variable && p.value.startsWith('seq')), false);
    expect(tester.widget<Dialog>(find.byType(Dialog)).clipBehavior,
        Clip.antiAlias);
    final sizeInput = find.descendant(
        of: find.byKey(const ValueKey('export-edge-pixels')),
        matching: find.byType(TextField));
    expect(options.edgePixels, null);
    expect(tester.widget<TextField>(sizeInput).controller!.text, '');
    double baseline(Finder finder) {
      final box = tester.renderObject<RenderBox>(finder);
      return tester.getTopLeft(finder).dy +
          box.getDryBaseline(box.constraints, TextBaseline.alphabetic)!;
    }

    expect((baseline(find.text('长边')) - baseline(find.text('原尺寸'))).abs(),
        lessThan(.5));
    final selectedStyle = tester.widget<Text>(find.text('长边')).style!;
    final placeholderStyle =
        tester.widget<TextField>(sizeInput).decoration!.hintStyle!;
    expect(selectedStyle.fontSize, placeholderStyle.fontSize);
    expect(selectedStyle.fontFamily, placeholderStyle.fontFamily);
    expect(selectedStyle.fontWeight, placeholderStyle.fontWeight);
    expect(placeholderStyle.color!.a, closeTo(.40, .01));
    await capture('export-panel');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('{seq:3}  序号补零'));
      await tester.pumpAndSettle();
      expect(
          find.byWidgetPredicate(
              (w) => w is TextField && w.decoration?.hintText == '输入文字…'),
          findsOneWidget);
    }
    final templateFields = find.descendant(
        of: find.byType(NamingTemplateEditor),
        matching: find.byType(TextField));
    for (final field in tester.widgetList<TextField>(templateFields)) {
      if (field.decoration?.hintText == null &&
          field.controller!.text.isEmpty) {
        expect(
            tester.getSize(find.byWidget(field)).width, lessThanOrEqualTo(8));
      }
    }
    final literalPart =
        parts.firstWhere((p) => !p.variable && p.value.isNotEmpty);
    final literalField = find.byKey(ValueKey('literal:${literalPart.id}'));
    final literalWidget = tester.widget<TextField>(literalField);
    final measure = TextPainter(
        text: TextSpan(text: literalPart.value, style: literalWidget.style),
        textDirection: TextDirection.ltr)
      ..layout();
    expect(tester.getSize(literalField).width,
        lessThanOrEqualTo(measure.width.ceil() + 6));
    measure.dispose();
    await capture('naming-compact');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('移除 {seq:3}').first);
      await tester.pumpAndSettle();
    }
    final tailPart = parts.last;
    await tester.tap(find.byKey(ValueKey('literal:${tailPart.id}')));
    await tester.enterText(
        find.byKey(ValueKey('literal:${tailPart.id}')), 'abc');
    await tester.pumpAndSettle();
    expect(parts.where((p) => !p.variable).map((p) => p.value).join(),
        '_LumaCraftabc');
    final merged = parts.firstWhere((p) => !p.variable && p.value.isNotEmpty);
    expect(
        tester
            .widget<TextField>(find.byKey(ValueKey('literal:${merged.id}')))
            .focusNode!
            .hasFocus,
        true);
    await tester.enterText(
        find.byKey(ValueKey('literal:${merged.id}')), '_LumaCraft');
    await tester.pumpAndSettle();

    // Insert at the caret without moving the suffix or creating middle hints.
    final caretField = find.byKey(ValueKey('literal:${merged.id}'));
    await tester.tap(caretField);
    await tester.pump();
    tester.widget<TextField>(caretField).controller!.selection =
        const TextSelection.collapsed(offset: 5);
    await tester.tap(find.text('{date}  拍摄日期'));
    await tester.pumpAndSettle();
    expect(parts.map((p) => p.variable ? '{${p.value}}' : p.value).join(),
        '{name}_Luma{date}Craft');
    await tester.tap(find.text('{time}  拍摄时间'));
    await tester.pumpAndSettle();
    expect(parts.map((p) => p.variable ? '{${p.value}}' : p.value).join(),
        '{name}_Luma{date}{time}Craft');
    await tester.tap(find.byTooltip('移除 {time}'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('移除 {date}'));
    await tester.pumpAndSettle();
    expect(parts.where((p) => !p.variable).map((p) => p.value).join(),
        '_LumaCraft');

    await tester.enterText(sizeInput, '2400');
    await tester.pump();
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    final start = tester.getCenter(sizeInput);
    await mouse.down(start);
    await mouse.moveTo(start + const Offset(40, 0));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(options.edgePixels, greaterThan(2400));
    final horizontalValue = options.edgePixels!;
    await mouse.down(start);
    await mouse.moveTo(start + const Offset(0, -24));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(options.edgePixels, greaterThan(horizontalValue));
    await tester.enterText(sizeInput, '');
    await tester.pump();
    expect(options.edgePixels, null);
    await tester.enterText(sizeInput, '2400');
    await tester.pump();
    await tester.tap(find.widgetWithText(PrototypeSelect, '长边'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('短边').last);
    await tester.pumpAndSettle();
    expect(options.sizeEdge, 'short');
    expect(options.edgePixels, 2400);
    await tester.tap(find.byType(VerticalToggle).first);
    await tester.pumpAndSettle();
    expect(options.retainCaptureInfo, false);
    await tester.tap(find.byType(VerticalToggle).first);
    await tester.pumpAndSettle();
    expect(options.retainCaptureInfo, true);
    await capture('export-panel-short-edge');

    await tester.tap(find.text('{date}  拍摄日期'));
    await tester.pumpAndSettle();
    expect(parts.where((p) => p.variable && p.value == 'date'), hasLength(1));
    await tester.tap(find.byTooltip('移除 {date}'));
    await tester.pumpAndSettle();
    expect(parts.where((p) => p.variable && p.value == 'date'), isEmpty);
    final text = parts.where((p) => !p.variable).first;
    await tester.enterText(find.byKey(ValueKey('literal:${text.id}')), '_成片_');
    await tester.pumpAndSettle();
    expect(text.value, '_成片_');
    await tester.tap(find.widgetWithText(PrototypeSelect, 'JPG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PNG').last);
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, null);
    expect(find.textContaining('.png'), findsOneWidget);
    expect(find.byType(NamingTemplateEditor), findsOneWidget);
    expect(tester.takeException(), null);
    await capture('export-panel-png');
    ExportConflictChoice? chosen;
    await tester.pumpWidget(RepaintBoundary(
        key: surface,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: workspaceTheme(true),
            home: Scaffold(
                body: ExportConflictDialog(filenames: const [
              'DSC_3079_LumaCraft.jpg',
              'DSC_3134_LumaCraft.jpg'
            ], onChoose: (choice) => chosen = choice)))));
    await tester.pumpAndSettle();
    final cancelSize = tester.getSize(find.widgetWithText(TextButton, '取消导出'));
    expect(cancelSize, const Size(112, 40));
    expect(tester.getSize(find.widgetWithText(TextButton, '替换保存')), cancelSize);
    expect(
        tester.getSize(find.widgetWithText(FilledButton, '全部保留')), cancelSize);
    final contentRect = tester.getRect(find
        .descendant(of: find.byType(Dialog), matching: find.byType(Material))
        .first);
    await tester.runAsync(() async {
      final boundary =
          surface.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final original = await boundary.toImage(pixelRatio: 1.5);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final crop = contentRect.inflate(12);
      canvas.drawImageRect(
          original,
          Rect.fromLTWH(crop.left * 1.5, crop.top * 1.5, crop.width * 1.5,
              crop.height * 1.5),
          Rect.fromLTWH(0, 0, crop.width * 1.5, crop.height * 1.5),
          Paint());
      final picture = recorder.endRecording();
      final image = await picture.toImage(
          (crop.width * 1.5).ceil(), (crop.height * 1.5).ceil());
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('build/export-preview/export-conflicts.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
      original.dispose();
      picture.dispose();
    });
    for (final item in {
      '全部保留': ExportConflictChoice.keepAll,
      '替换保存': ExportConflictChoice.replace,
      '取消导出': ExportConflictChoice.cancel
    }.entries) {
      await tester.tap(find.text(item.key));
      await tester.pump();
      expect(chosen, item.value);
    }
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
}
