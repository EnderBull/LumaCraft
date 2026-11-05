import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/editor/editor_controller.dart';
import 'package:lumacraft/editor/preset_package.dart';
import 'package:lumacraft/editor/preset_store.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/style_render.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/ui/editor/editor_page.dart';
import 'package:lumacraft/ui/editor/prototype_controls.dart';
import 'package:lumacraft/workspace_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory output;
  setUpAll(() async {
    output = await Directory(
            'test/layout-output/run-${DateTime.now().millisecondsSinceEpoch}')
        .create(recursive: true);
  });
  test('横竖独立编辑、共享内容、复制撤销、继承与离线保存', () async {
    final c = EditorController(StyleDocument.template());
    final id = c.doc.nodes.first.id;
    c.edit(() => c.doc.setAdaptive(true));
    c.doc.switchLayout('landscape');
    c.edit(() {
      c.doc.node(id)!.x = 20;
      c.doc.node(id)!.fontSize = 68;
      c.doc.borders['bottom'] = 10;
    });
    c.doc.switchLayout('portrait');
    expect(c.doc.node(id)!.x, 50);
    c.edit(() {
      c.doc.node(id)!.x = 72;
      c.doc.node(id)!.fontSize = 22;
      c.doc.node(id)!.align = 'right';
      c.doc.node(id)!.text = '共享文字';
      c.doc.node(id)!.color = 0xff008899;
      c.doc.borders['bottom'] = 25;
      c.doc.nodes.last.visible = false;
    });
    expect(c.doc.forRatio(1.5).node(id)!.text, '共享文字');
    expect(c.doc.forRatio(1.5).node(id)!.fontSize, 68);
    expect(c.doc.forRatio(1).node(id)!.fontSize, 32);
    expect(c.doc.forRatio(2 / 3).nodes.last.visible, false);
    expect(c.doc.forRatio(1.5).nodes.last.visible, true);
    c.selection.add(id);
    c.duplicate();
    final copyId = c.selection.single;
    expect(c.doc.forRatio(1.5).node(copyId)!.x, 21);
    expect(c.doc.forRatio(2 / 3).node(copyId)!.x, 73);
    c.undo();
    expect(c.doc.node(copyId), null);
    expect(c.doc.node(id)!.x, 72);
    c.edit(() => c.doc.suitability = 'portrait');
    final store = PresetStore(File('${output.path}/presets.json'));
    await store.save(
        draft: c.doc,
        sourceKey: 'adaptive',
        presets: [UserPreset('adaptive', c.doc.copy())]);
    final loaded = PresetStore(store.file);
    await loaded.load();
    expect(loaded.draftFor('adaptive')!.forRatio(.7).node(id)!.x, 72);
    final package = encodeLmp([SharedPreset(loaded.presets.single.style)]);
    expect(jsonDecode(package)['requires'], contains('adaptiveLayout'));
    final imported = decodeLmp(package).single.style;
    expect(imported.forRatio(1.5).borders['bottom'], 10);
    expect(imported.forRatio(.7).borders['bottom'], 25);
    expect(imported.suitability, 'portrait');
    imported.switchLayout('portrait');
    imported.resetLayout();
    imported.switchLayout('general');
    imported.nodes.first.fontSize = 44;
    expect(imported.forRatio(.7).nodes.first.fontSize, 44);
    imported.switchLayout('portrait');
    imported.copyGeneralLayout();
    imported.switchLayout('general');
    imported.nodes.first.fontSize = 55;
    expect(imported.forRatio(.7).nodes.first.fontSize, 44);
    final malformed = jsonDecode(package);
    malformed['presets'][0]['style']['layouts']['portrait']['nodes'][id]
        ['fontSize'] = -3;
    expect(() => decodeLmp(jsonEncode(malformed)), throwsFormatException);
    final legacy = StyleDocument.template().toJson()
      ..remove('adaptive')
      ..remove('layouts')
      ..remove('suitability');
    expect(StyleDocument.fromJson(legacy).adaptive, false);
    c.dispose();
  });
  test('混合横竖方图按原图比例导出并与预览共用布局', () async {
    final style = StyleDocument.template()..setAdaptive(true);
    style.nodes.clear();
    style.order.clear();
    style.switchLayout('landscape');
    style.borders['bottom'] = 10;
    style.switchLayout('portrait');
    style.borders['bottom'] = 25;
    for (final size in [(300, 200), (200, 300), (200, 200)]) {
      final source = img.Image(width: size.$1, height: size.$2);
      img.fill(source, color: img.ColorRgb8(80, 130, 150));
      final file = File('${output.path}/${size.$1}x${size.$2}.jpg');
      await file.writeAsBytes(img.encodeJpg(source));
      final bytes = await renderStyledPhoto(file.path, style, {}, true);
      await File('${output.path}/${size.$1}x${size.$2}-styled.png')
          .writeAsBytes(bytes);
      final rendered = img.decodePng(bytes)!;
      final ratio = size.$1 / size.$2;
      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final photo = (await codec.getNextFrame()).image;
      final scene = StyleScene(style, photo, {});
      final short = size.$1 < size.$2 ? size.$1 : size.$2;
      expect(
          rendered.width, (scene.geometry.size.width * short / 1000).round());
      expect(
          rendered.height, (scene.geometry.size.height * short / 1000).round());
      expect(
          scene.document.borders['bottom'],
          ratio > 1
              ? 10
              : ratio < 1
                  ? 25
                  : 16);
      scene.dispose();
      photo.dispose();
      codec.dispose();
    }
  });
  testWidgets('画布适配控件显示当前布局并可恢复通用', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = PresetStore(File('${output.path}/ui-presets.json'));
    await tester.runAsync(() async {
      final fontFile = File('C:/Windows/Fonts/msyh.ttc');
      if (Platform.isWindows && await fontFile.exists()) {
        for (final family in ['Microsoft YaHei UI', 'Microsoft YaHei']) {
          final loader = FontLoader(family)
            ..addFont(fontFile.readAsBytes().then(ByteData.sublistView));
          await loader.load();
        }
      }
    });
    final surface = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: surface,
        child: MaterialApp(
            theme: workspaceTheme(true),
            home: PresetEditor(
                files: [],
                current: 0,
                selected: {},
                initial: StyleDocument.template(),
                presets: store,
                settings:
                    WorkspaceSettings(File('${output.path}/settings.json')),
                metadata: (_) async => {},
                apply: (_, __) async {}))));
    final dynamic state = tester.state(find.byType(PresetEditor));
    state.update(() => state.panel = 1);
    await tester.pump();
    await tester.tap(find.widgetWithText(PrototypeSelect, '统一布局'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('横竖独立').last);
    await tester.pumpAndSettle();
    expect(find.text('正在编辑'), findsOneWidget);
    expect(find.text('从通用复制'), findsOneWidget);
    final c = state.c as EditorController;
    expect(c.doc.editingLayout, 'landscape');
    await tester.tap(find.widgetWithText(PrototypeSelect, '横图布局'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('竖图布局').last);
    await tester.pumpAndSettle();
    expect(c.doc.editingLayout, 'portrait');
    await tester.runAsync(() async {
      final boundary =
          surface.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${output.path}/layout-panel.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    c.edit(() => c.doc.nodes.first.x = 90);
    await tester.pump();
    await tester.tap(find.text('恢复通用'));
    await tester.pumpAndSettle();
    expect(c.doc.nodes.first.x, 50);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 60));
  });
}
