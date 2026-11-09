import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/editor_controller.dart';
import 'package:lumacraft/editor/preset_store.dart';
import 'package:lumacraft/editor/style_render.dart';
import 'package:lumacraft/editor/photo_palette.dart';
import 'package:lumacraft/photo_state.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/ui/preset_thumbnail.dart';
import 'package:lumacraft/ui/editor/editor_page.dart';
import 'package:lumacraft/ui/editor/mode_transition.dart';
import 'package:lumacraft/ui/editor/hsb_color_picker.dart';
import 'package:lumacraft/workspace_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory output;
  late File source;
  setUpAll(() async {
    output = await Directory(
            'test/editor-output/run-${DateTime.now().millisecondsSinceEpoch}')
        .create(recursive: true);
    source = File('${output.path}/source.jpg');
    final image = img.Image(width: 360, height: 240);
    img.fill(image, color: img.ColorRgb8(78, 130, 150));
    image.exif.imageIfd[0x0110] = 'CORE CAMERA';
    image.exif.exifIfd[0x8827] = img.IfdValueShort(400);
    image.exif.exifIfd[0x9003] = '2021:06:20 16:45:01';
    image.exif.gpsIfd[1] = 'N';
    await source.writeAsBytes(img.encodeJpg(image));
  });
  test('样式、分组、锚点、撤销与预设保存核心流程', () async {
    final c = EditorController(StyleDocument.template());
    final first = c.doc.nodes.first, id = first.id;
    final old = StyleGeometry(c.doc, 1.5).point(first);
    c.changeAnchor(first, 'canvas', 1.5);
    expect((StyleGeometry(c.doc, 1.5).point(first) - old).distance,
        lessThan(.0001));
    c.undo();
    expect(c.doc.node(id)!.anchor, 'bottom');
    c.selection.addAll(c.doc.nodes.take(2).map((n) => n.id));
    c.group();
    final group = c.selection.single;
    expect(c.doc.leaves(group).length, 2);
    final clone = c.doc.copy();
    expect(clone.leaves(group).length, 2);
    c.doc.nodes.first.locked = true;
    final countBefore = c.doc.nodes.length;
    c.remove();
    expect(c.doc.nodes.length, countBefore);
    expect(c.reorderMany([group], null, 0), false);
    c.doc.nodes.first.locked = false;
    c.border('bottom', 0, 1.5, {});
    expect(c.doc.nodes.every((n) => n.anchor == 'photo'), true);
    expect(c.doc.leaves(group).length, 2);
    c.undo();
    expect(c.doc.borders['bottom'], 16);
    expect(c.doc.nodes.every((n) => n.anchor == 'bottom'), true);
    c.duplicate();
    expect(c.doc.nodes.length, 5);
    c.undo();
    expect(c.doc.nodes.length, 3);
    final store = PresetStore(File('${output.path}/presets.json'));
    await store
        .save(presets: [UserPreset('stable-id', c.doc.copy())], draft: c.doc);
    final overwrite = c.doc.copy()..name = '覆盖后的预设';
    final saving = store.save(presets: [UserPreset('stable-id', overwrite)]);
    final draft = store.save(draft: c.doc);
    await Future.wait([saving, draft]);
    final loaded = PresetStore(store.file);
    await loaded.load();
    expect(loaded.presets.length, 1);
    expect(loaded.presets.single.id, 'stable-id');
    expect(loaded.presets.single.style.name, '覆盖后的预设');
    await store.save(draft: c.doc, sourceKey: 'style-A');
    await store.save(draft: StyleDocument.template(true), sourceKey: 'style-B');
    await loaded.load();
    expect(loaded.draftFor('style-A')!.name, c.doc.name);
    expect(loaded.draftFor('style-B')!.name, '胶片档案');
    expect(File('${store.file.path}.pending').existsSync(), false);

    final rapid = PresetStore(File('${output.path}/rapid-presets.json'));
    for (var i = 0; i < 12; i++) {
      await rapid.save(
          draft: StyleDocument.template(i.isEven)..name = '连续保存-$i',
          sourceKey: 'rapid-$i');
    }
    final rapidLoaded = PresetStore(rapid.file);
    await rapidLoaded.load();
    expect(rapidLoaded.draftFor('rapid-11')!.name, '连续保存-11');
    expect(File('${rapid.file.path}.pending').existsSync(), false);

    final state =
        PhotoState.fromJson({'film': true, 'edited': true, 'fields': {}});
    expect(state.film, true);
    final sourceKey = state.editorSourceKey(source.path);
    state.style = StyleDocument.template();
    expect(state.editorSourceKey(source.path), sourceKey);
    state.styleSource = 'user:test';
    expect(state.editorSourceKey(source.path), isNot(sourceKey));
    expect(
        PhotoState.fromJson(jsonDecode(jsonEncode(state.toJson())))
            .editorSourceKey(source.path),
        state.editorSourceKey(source.path));

    state.style = c.doc.copy();
    expect(
        PhotoState.fromJson(jsonDecode(jsonEncode(state.toJson())))
            .style!
            .groups
            .length,
        1);
    c.dispose();
  });
  test('锚点不限制跨区域移动，混合锚点编组保持相对位置', () {
    final bottom = StyleNode(anchor: 'bottom', x: 50, y: 50),
        photo = StyleNode(anchor: 'photo', x: 50, y: 50);
    final d =
        StyleDocument(nodes: [bottom, photo], order: [bottom.id, photo.id]);
    final c = EditorController(d);
    final g = StyleGeometry(d, 1.5), p = g.point(bottom);
    c.begin();
    c.moveNodes({bottom.id: bottom.copy()}, const Offset(0, -500), 1.5);
    c.end();
    expect(c.doc.node(bottom.id)!.anchor, 'bottom');
    expect(c.doc.node(bottom.id)!.y, lessThan(0));
    expect(
        (StyleGeometry(c.doc, 1.5).point(c.doc.node(bottom.id)!) -
                (p + const Offset(0, -500)))
            .distance,
        lessThan(.00001));
    c.undo();
    expect(c.doc.node(bottom.id)!.y, 50);
    c.redo();
    final oldPhoto = c.doc.node(photo.id)!.copy();
    c.edit(() => c.moveNodes({photo.id: oldPhoto}, const Offset(0, 1100), 1.5));
    expect(c.doc.node(photo.id)!.anchor, 'photo');
    expect(c.doc.node(photo.id)!.y, greaterThan(100));
    c.selection.addAll([bottom.id, photo.id]);
    c.group();
    final originals = {for (final n in c.selectedNodes) n.id: n.copy()};
    final before = StyleGeometry(c.doc, 1.5);
    c.edit(() => c.moveNodes(originals, const Offset(120, -50), 1.5));
    for (final n in c.selectedNodes) {
      expect(
          (StyleGeometry(c.doc, 1.5).point(n) -
                  (before.point(originals[n.id]!) + const Offset(120, -50)))
              .distance,
          lessThan(.00001));
      expect(n.anchor, originals[n.id]!.anchor);
    }
    final n = c.doc.node(bottom.id)!,
        point = StyleGeometry(c.doc, 1.5).point(c.doc.node(bottom.id)!);
    c.changeAnchor(n, 'photo', 1.5);
    c.changeAnchor(n, 'canvas', 1.5);
    expect((StyleGeometry(c.doc, 1.5).point(n) - point).distance,
        lessThan(.00001));
    c.selection
      ..clear()
      ..add(photo.id);
    final outside = c.doc.node(photo.id)!.copy();
    c.duplicate();
    expect(c.selectedNodes.single.y, closeTo(outside.y + 1, .00001));
    expect(c.doc.copy().nodes.any((n) => n.y > 100), true);
    final zero =
        StyleDocument(borders: {'top': 0, 'bottom': 0, 'left': 0, 'right': 0});
    final z = StyleNode(anchor: 'bottom');
    final geometry = StyleGeometry(zero, 1.5);
    geometry.reanchor(z, 'bottom', point: const Offset(500, 1200));
    expect(z.anchor, 'bottom');
    expect((geometry.point(z) - const Offset(500, 1200)).distance,
        lessThan(.00001));
    zero.borders['bottom'] = .01;
    final tiny = StyleGeometry(zero, 1.5);
    tiny.reanchor(z, 'bottom', point: const Offset(500, 800));
    expect((tiny.point(z) - const Offset(500, 800)).distance, lessThan(.00001));
    c.dispose();
  });

  test('含大图片字符串的开关撤销不重复序列化且保持深复制', () {
    final d = StyleDocument.template();
    final node = StyleNode(type: 'image');
    node.image.data = List.filled(500000, 'A').join();
    d.nodes.add(node);
    d.order.add(node.id);
    final c = EditorController(d), snapshot = d.copy();
    expect(identical(snapshot.nodes.last.image.data, d.nodes.last.image.data),
        true);
    c.edit(() => c.doc.nodes.last.visible = false);
    expect(styleEquals(snapshot, c.doc), false);
    c.undo();
    expect(styleEquals(snapshot, c.doc), true);
    c.edit(() => c.doc.nodes.last.locked = true);
    c.undo();
    expect(styleEquals(snapshot, c.doc), true);
    snapshot.nodes.last.image.width = 500;
    expect(c.doc.nodes.last.image.width, 180);
    c.dispose();
  });

  testWidgets('图层开关下一帧生效且不切换选择与属性面板', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: PresetEditor(
            files: [],
            current: 0,
            selected: {},
            initial: StyleDocument.template(),
            settings:
                WorkspaceSettings(File('${output.path}/toggle-settings.json')),
            presets: _MemoryPresets(File('${output.path}/toggle-presets.json')),
            metadata: (_) async => {},
            apply: (_, __) async {})));
    await tester.pump();
    final dynamic state = tester.state(find.byType(PresetEditor));
    final c = state.c as EditorController, id = c.doc.nodes.last.id;
    c.select(c.doc.nodes.first.id);
    state.update(() {
      state.panel = 0;
    });
    await tester.pump();
    final selected = {...c.selection};
    await tester.tap(find.byTooltip('隐藏').first);
    await tester.pump(const Duration(milliseconds: 16));
    expect(c.doc.node(id)!.visible, false, reason: '不可等待双击超时才隐藏');
    expect(c.selection, selected);
    expect(state.panel, 0);
    await tester.tap(find.byTooltip('锁定').first);
    await tester.pump(const Duration(milliseconds: 16));
    expect(c.doc.node(id)!.locked, true);
    expect(c.selection, selected);
    expect(state.panel, 0);
    await tester.tap(find.byTooltip('解锁').first);
    await tester.pump(const Duration(milliseconds: 16));
    expect(c.doc.node(id)!.locked, false);
    await tester.tap(find.byTooltip('显示').first);
    await tester.pump(const Duration(milliseconds: 16));
    expect(c.doc.node(id)!.visible, true);
    Future<void> renameLayer(String id, String value,
        {bool cancel = false}) async {
      final name = find
          .descendant(
              of: find.byKey(ValueKey('layer-name:$id')),
              matching: find.byType(Text))
          .first;
      await tester.tap(name);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(name);
      await tester.pump();
      final field = find.byKey(ValueKey('layer-name-edit:$id'));
      expect(field, findsOneWidget);
      await tester.enterText(field, value);
      await tester.sendKeyEvent(
          cancel ? LogicalKeyboardKey.escape : LogicalKeyboardKey.enter);
      await tester.pump();
    }

    final content = c.doc.node(id)!.text;
    await renameLayer(id, '新的图层名');
    expect(c.doc.node(id)!.name, '新的图层名');
    expect(c.doc.node(id)!.text, content);
    await renameLayer(id, '取消改名', cancel: true);
    expect(c.doc.node(id)!.name, '新的图层名');
    c.selection
      ..clear()
      ..addAll(c.doc.nodes.take(2).map((n) => n.id));
    c.group();
    await tester.pump();
    final group = c.selection.single,
        children = List.of(c.doc.group(group)!.children);
    await renameLayer(group, '新的组名');
    expect(c.doc.group(group)!.name, '新的组名');
    expect(c.doc.group(group)!.children, children);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 60));
  });

  testWidgets('真实照片编辑→保存预设→应用样式', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final presets = _MemoryPresets(File('${output.path}/ui-presets.json'));
    final initial = StyleDocument.template();
    final card = StyleNode(type: 'palette', name: '照片色卡')
      ..palette.shape = 'roundedRect';
    initial.nodes.add(card);
    initial.order.add(card.id);
    StyleDocument? applied;
    EditorBrowseState? returned;
    final editorPixels = GlobalKey();
    late ui.Image seed;
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(await source.readAsBytes());
      seed = (await codec.getNextFrame()).image;
      codec.dispose();
    });
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: Builder(
            builder: (context) => Scaffold(
                    body: Column(children: [
                  TextButton(
                      onPressed: () => Navigator.of(context).push(
                          WorkspaceModeRoute(
                              reduceMotion: false,
                              builder: (_) => RepaintBoundary(
                                  key: editorPixels,
                                  child: PresetEditor(
                                      files: [source],
                                      current: 0,
                                      selected: {source.path},
                                      initial: initial,
                                      settings: WorkspaceSettings(File(
                                          '${output.path}/workspace.json')),
                                      presets: presets,
                                      metadata: (f) async =>
                                          readCapture(f.path),
                                      initialPhoto: seed,
                                      initialDirectory: output.parent.path,
                                      initialFields: {
                                        ...readCapture(source.path),
                                        photoPaletteField:
                                            List.filled(6, 0xff4e8296).join(',')
                                      },
                                      onReturn: (state) async =>
                                          returned = state,
                                      apply: (d, paths) async {
                                        expect(paths, {source.path});
                                        applied = d;
                                      })))),
                      child: const Text('进入编辑')),
                  SizedBox(
                      width: 300,
                      height: 200,
                      child: WorkspaceCanvas(
                          child: SizedBox(
                              width: 360,
                              height: 240,
                              child: RawImage(image: seed))))
                ])))));
    await tester.tap(find.text('进入编辑'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.takeException(), isNull, reason: '共享照片画布飞行期间应能正确排版');
    await tester.pumpAndSettle();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary = editorPixels.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final photoCenter =
        boundary.globalToLocal(tester.getCenter(find.byType(WorkspaceCanvas)));
    await tester.runAsync(() async {
      final pixels = await boundary.toImage();
      try {
        final rgba =
            (await pixels.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final offset =
            (photoCenter.dy.floor() * pixels.width + photoCenter.dx.floor()) *
                4;
        final original =
            img.decodeJpg(await source.readAsBytes())!.getPixel(180, 120);
        for (final channel in [
          (0, original.r),
          (1, original.g),
          (2, original.b)
        ]) {
          expect(rgba.getUint8(offset + channel.$1), closeTo(channel.$2, 2),
              reason: '编辑画布内部的照片亮度不应被上层阴影压暗');
        }
      } finally {
        pixels.dispose();
      }
    });
    await tester.tap(find.text('题签'));
    await tester.pumpAndSettle();
    final beforePicker = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller?.text)
        .toList();
    await tester.tap(find.text('Georgia'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .map((field) => field.controller?.text)
            .toList(),
        beforePicker,
        reason: '下拉键盘导航与关闭不应移动或取消选择后台组件');
    final content = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == 'Gallery Collection');
    expect(content, findsOneWidget);
    await tester.enterText(content, 'CORE FLOW');
    await tester.tap(find.text('画布').first);
    await tester.pumpAndSettle();
    final bottom = find
        .byWidgetPredicate((w) => w is TextField && w.controller?.text == '16');
    expect(bottom, findsOneWidget);
    await tester.enterText(bottom, '0');
    await tester.tap(find.text('背景填充'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用样式'));
    await tester.pumpAndSettle();
    // 只选中一张照片时不弹范围对话框，直接应用。
    expect(find.text('确认应用'), findsNothing);
    expect(applied, isNotNull);
    expect(applied!.nodes.first.text, 'CORE FLOW');
    expect(applied!.nodes.every((n) => n.anchor == 'photo'), true);
    await tester.tap(find.text('保存预设'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建保存'));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    for (var i = 0; i < 8 && presets.presets.isEmpty; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }
    expect(presets.presets.length, 1);
    await tester.tap(find.text('保存预设'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byWidgetPredicate((w) => w is AlertDialog),
            matching: find.byType(PresetThumbnail)),
        findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('画布').first);
    await tester.pumpAndSettle();
    final focusedHex = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '#F3F0E8');
    await tester.enterText(focusedHex, '#AABBCC');
    await tester.pump();
    final draftBeforePicker = presets.draft?.background;
    final originalBackground = tester
        .widget<ColorSwatchButton>(find.byWidgetPredicate(
            (w) => w is ColorSwatchButton && w.label == '背景颜色'))
        .color;
    await tester.tap(find
        .byWidgetPredicate((w) => w is ColorSwatchButton && w.label == '背景颜色'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('hsb-hex')), '#123ABC');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    expect(presets.draft?.background, draftBeforePicker,
        reason: '取色实时预览期间不应把未确认颜色自动保存到草稿');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ColorSwatchButton>(find.byWidgetPredicate(
                (w) => w is ColorSwatchButton && w.label == '背景颜色'))
            .color,
        originalBackground);
    await tester.tap(find
        .byWidgetPredicate((w) => w is ColorSwatchButton && w.label == '背景颜色'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('hsb-hex')), '#123ABC');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ColorSwatchButton>(find.byWidgetPredicate(
                (w) => w is ColorSwatchButton && w.label == '背景颜色'))
            .color
            .toARGB32(),
        0xff123abc);
    await tester.tap(find.byTooltip('撤销 Ctrl+Z'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ColorSwatchButton>(find.byWidgetPredicate(
                (w) => w is ColorSwatchButton && w.label == '背景颜色'))
            .color,
        originalBackground);
    await tester.tap(find.text('照片色卡').first);
    await tester.pumpAndSettle();
    for (final labels in [('形式', '形状'), ('宽度', '高度'), ('间距', '圆角')]) {
      expect(tester.getTopLeft(find.text(labels.$1)).dy,
          tester.getTopLeft(find.text(labels.$2)).dy,
          reason: '${labels.$1}/${labels.$2}应当同排两列');
    }
    expect(find.text('不透明度'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    final widthInput = find
        .byWidgetPredicate((w) => w is TextField && w.controller?.text == '34')
        .first;
    final widthDrag = await tester.startGesture(tester.getCenter(widthInput),
        kind: ui.PointerDeviceKind.mouse);
    await widthDrag.moveBy(const Offset(40, 0));
    await widthDrag.up();
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate(
            (w) => w is TextField && w.controller?.text == '44'),
        findsOneWidget);
    await tester.tap(find.byTooltip('撤销 Ctrl+Z'));
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate(
            (w) => w is TextField && w.controller?.text == '34'),
        findsNWidgets(2));
    await tester.tap(find.text('浏览'));
    await tester.pumpAndSettle();
    expect(returned, isNotNull);
    expect(returned!.selected, {source.path});
    expect(returned!.current, 0);
    expect(returned!.directory, output.parent.path,
        reason: '递归浏览目录不能从第一张照片的父目录反推');
    expect(returned!.scanning, false);
    expect(returned!.scrollOffset, 0);
    expect(find.text('进入编辑'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    seed.dispose();
  });
  test('同一排版导出 JPG/PNG 并保留 EXIF', () async {
    final d = StyleDocument.template();
    d.nodes.first.text = 'CORE FLOW';
    final fields = readCapture(source.path);
    for (final png in [false, true]) {
      final bytes = await renderStyledPhoto(source.path, d, fields, png);
      final file = File('${output.path}/styled.${png ? 'png' : 'jpg'}');
      await file.writeAsBytes(bytes);
      final decoded = img.decodeImage(bytes)!;
      expect(decoded.width, 374);
      expect(decoded.height, 286);
      final meta = png
          ? img.ExifData.fromInputBuffer(img.InputBuffer(Uint8List.sublistView(
              bytes, 41, 41 + ByteData.sublistView(bytes).getUint32(33))))
          : img.decodeJpgExif(bytes)!;
      expect(meta.imageIfd[0x0110].toString(), 'CORE CAMERA');
      expect(meta.exifIfd[0x8827].toString(), '400');
      expect(meta.gpsIfd.isEmpty, true);
      expect(readCapture(file.path)['camera'], 'CORE CAMERA');
    }
    // The actual export pixel dimensions follow the shared scene geometry.
    final codec = await ui.instantiateImageCodec(await source.readAsBytes());
    final photo = (await codec.getNextFrame()).image;
    final scene = StyleScene(d, photo, fields);
    expect(scene.bounds.length, 3);
    scene.dispose();
    photo.dispose();
    codec.dispose();
  });

  testWidgets('图层点按只选中，挪开超过20像素才拖动', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: PresetEditor(
            files: [],
            current: 0,
            selected: {},
            initial: StyleDocument.template(),
            settings:
                WorkspaceSettings(File('${output.path}/layer-drag-settings.json')),
            presets:
                _MemoryPresets(File('${output.path}/layer-drag-presets.json')),
            metadata: (_) async => {},
            apply: (_, __) async {})));
    await tester.pump();
    final dynamic state = tester.state(find.byType(PresetEditor));
    final c = state.c as EditorController;
    final id = c.doc.nodes.first.id;
    final label = find.descendant(
        of: find.byType(ListView), matching: find.text('题签'));
    final feedback = find.byKey(const ValueKey('layer-drag-feedback'));
    c.select(null);
    await tester.pump();
    final row = tester.getRect(label);
    final list = tester.getRect(
        find.ancestor(of: label, matching: find.byType(ListView)).first);
    await tester.tapAt(Offset(
        (row.right + 40).clamp(list.left + 8, list.right - 80), row.center.dy));
    await tester.pump();
    expect(c.selection.contains(id), true, reason: '点在图层行文字旁边的空白处也应选中');
    final short = await tester.startGesture(tester.getCenter(label));
    await tester.pump();
    expect(c.selection.contains(id), true, reason: '按下后应立刻选中');
    await short.moveBy(const Offset(12, 0));
    await tester.pump();
    expect(feedback, findsNothing, reason: '挪开不到 20 像素时不应出现拖动浮层');
    await short.moveBy(const Offset(16, 0));
    await tester.pump();
    expect(feedback, findsOneWidget, reason: '挪开超过 20 像素后应立刻出现拖动浮层');
    await short.up();
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('按住方向键连续移动只记一步撤销', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: PresetEditor(
            files: [],
            current: 0,
            selected: {},
            initial: StyleDocument.template(),
            settings:
                WorkspaceSettings(File('${output.path}/nudge-settings.json')),
            presets: _MemoryPresets(File('${output.path}/nudge-presets.json')),
            metadata: (_) async => {},
            apply: (_, __) async {})));
    await tester.pump();
    final dynamic state = tester.state(find.byType(PresetEditor));
    final c = state.c as EditorController;
    final id = c.doc.nodes.first.id;
    c.select(id);
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final start = c.doc.node(id)!.x;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    final moved = c.doc.node(id)!.x;
    expect(moved, greaterThan(start));
    c.undo();
    expect(c.doc.node(id)!.x, start);
    c.redo();
    expect(c.doc.node(id)!.x, closeTo(moved, .001));
  });
}

// Widget tests use a fake clock; real atomic file IO is checked above.
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
