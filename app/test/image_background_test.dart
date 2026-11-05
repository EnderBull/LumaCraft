import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:lumacraft/ui/editor/editor_page.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/ui/editor/hsb_color_picker.dart';
import 'package:lumacraft/workspace_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/style_render.dart';
import 'package:lumacraft/editor/image_mark.dart';
import 'package:lumacraft/editor/background_render.dart';
import 'package:lumacraft/editor/editor_controller.dart';
import 'package:lumacraft/editor/preset_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('深色模糊填充在非整数缩放下不露出浅色底边', () async {
    final source = ui.PictureRecorder();
    Canvas(source).drawColor(const Color(0xff101010), BlendMode.src);
    final sourcePicture = source.endRecording();
    final photo = await sourcePicture.toImage(200, 300);
    final doc = StyleDocument(background: 0xffffffff)
      ..fill.mode = 'blur'
      ..fill.blur = 35;
    final geometry = StyleGeometry(doc, 2 / 3);
    for (final scale in [.271, .371, .6667, 1.25]) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..drawColor(const Color(0xff181818), BlendMode.src)
        ..translate(.37, .63)
        ..scale(scale);
      paintStyleBackground(canvas, doc, geometry, photo);
      final picture = recorder.endRecording();
      final result = await picture.toImage(
          (geometry.size.width * scale).ceil() + 3,
          (geometry.size.height * scale).ceil() + 3);
      final bytes = await result.toByteData(format: ui.ImageByteFormat.rawRgba);
      for (var i = 0; i < bytes!.lengthInBytes; i += 4) {
        expect(bytes.getUint8(i), lessThan(60), reason: '缩放$scale 不应出现白色底边');
      }
      result.dispose();
      picture.dispose();
    }
    photo.dispose();
    sourcePicture.dispose();
  });
  test('图片素材随预设保存，背景独立调色，半孔与导出核心流程', () async {
    final output = await Directory(
            'test/background-output/run-${DateTime.now().millisecondsSinceEpoch}')
        .create(recursive: true);
    final photo = img.Image(width: 150, height: 100);
    for (var y = 0; y < 100; y++) {
      for (var x = 0; x < 150; x++) {
        photo.setPixelRgb(x, y, x < 75 ? 30 : 160, 90, 140);
      }
    }
    photo.exif.exifIfd[0x8827] = img.IfdValueShort(320);
    final source = File('${output.path}/source.jpg');
    await source.writeAsBytes(img.encodeJpg(photo));
    final logo = img.Image(width: 20, height: 10, numChannels: 4);
    for (var y = 0; y < 10; y++) {
      for (var x = 0; x < 20; x++) {
        logo.setPixelRgba(x, y, 255, 20, 10, x < 10 ? 255 : 0);
      }
    }
    final logoFile = File('${output.path}/logo.png');
    await logoFile.writeAsBytes(img.encodePng(logo));
    final mark = await importImageMark(logoFile.path);
    mark.width = 200;
    expect(mark.ratio, 2);
    final jpegMark = await importImageMark(source.path);
    expect(jpegMark.ratio, 1.5);
    expect(base64Decode(jpegMark.data).take(2), [0xff, 0xd8]);
    final d = StyleDocument(
        background: 0xff000000,
        borders: {'top': 10, 'right': 10, 'bottom': 10, 'left': 10});
    final n =
        StyleNode(type: 'image', image: mark, anchor: 'bottom', opacity: 50);
    d.nodes.add(n);
    d.order.add(n.id);
    d.fill
      ..mode = 'gradient'
      ..secondColor = 0xffffffff
      ..angle = 0;
    d.film
      ..enabled = true
      ..width = 24
      ..height = 40
      ..inset = 10
      ..radius = 0;
    final c = EditorController(d);
    c.edit(() => c.doc.fill.saturation = 25);
    c.undo();
    expect(c.doc.fill.saturation, 100);
    c.redo();
    expect(c.doc.fill.saturation, 25);
    final old = d.toJson()
      ..remove('fill')
      ..remove('film');
    expect(StyleDocument.fromJson(old).fill.mode, 'solid');
    final store = PresetStore(File('${output.path}/presets.json'));
    await store
        .save(presets: [UserPreset('test', d)], draft: d, sourceKey: 'photo');
    final reloaded = PresetStore(store.file);
    await reloaded.load();
    final style = reloaded.presets.single.style;
    expect(style.nodes.single.image.data, mark.data);
    final g = StyleGeometry(style, 1.5),
        holes = filmHoles(style, StyleGeometry(style, 1.5));
    expect(holes.first.top, lessThan(0));
    expect(holes.first.bottom, greaterThan(0));
    await prepareImageMarks([style.nodes.single.image]);
    final bytes = await renderStyledPhoto(source.path, style, {}, true);
    await File('${output.path}/gradient-logo.png').writeAsBytes(bytes);
    final result = img.decodePng(bytes)!;
    expect(result.width, 170);
    expect(result.height, 120);
    // Gradient endpoint and clipped half-hole visible, foreground unchanged.
    expect(result.getPixel(6, 5).r, lessThan(result.getPixel(163, 5).r));
    expect(result.getPixel(2, 0).r, greaterThan(180));
    final original = img.decodeJpg(await source.readAsBytes())!;
    expect((result.getPixel(85, 60).r - original.getPixel(75, 50).r).abs(),
        lessThan(3));
    // Transparent right half of mark exposes the original gradient.
    final left = result.getPixel(81, 115), right = result.getPixel(88, 115);
    expect(
        left.r,
        greaterThan(
            left.g + 40)); // approximate 50% red over neutral background
    expect((right.r - right.g).abs(), lessThan(3));
    for (final mode in ['gradient', 'blur']) {
      style.fill
        ..mode = mode
        ..blur = 12
        ..brightness = -30
        ..contrast = 130
        ..saturation = 0;
      final exported =
          img.decodePng(await renderStyledPhoto(source.path, style, {}, true))!;
      expect((exported.getPixel(85, 60).r - original.getPixel(75, 50).r).abs(),
          lessThan(3));
      if (mode == 'blur') {
        final bg = exported.getPixel(80, 5);
        expect((bg.r - bg.g).abs(), lessThan(3));
        expect((bg.g - bg.b).abs(), lessThan(3));
      }
    }
    style.film.orientation = 'horizontal';
    expect(filmHoles(style, g).first.left, lessThan(0));
    style.borders.updateAll((key, value) => 0);
    expect(filmHoles(style, StyleGeometry(style, 1.5)), isEmpty);
    // Missing or invalid embedded assets must fail explicitly during export.
    style.nodes.single.image.data = 'broken';
    await expectLater(renderStyledPhoto(source.path, style, {}, true),
        throwsA(isA<FormatException>()));
    final shadowDoc = StyleDocument(
        background: 0xffffffff,
        borders: {'top': 20, 'bottom': 20, 'left': 20, 'right': 20});
    expect(shadowDoc.shadow.color, 0xff000000);
    shadowDoc.shadow
      ..enabled = true
      ..angle = 180
      ..distance = 40
      ..size = 10
      ..opacity = 100
      ..feather = 0
      ..color = 0xffff0000;
    final copied = shadowDoc.copy();
    expect(copied.shadow.color, 0xffff0000);
    expect(copied.shadow.distance, 40);
    final legacy = shadowDoc.toJson()..remove('shadow');
    expect(StyleDocument.fromJson(legacy).shadow.enabled, false);
    final shadowBytes = await renderStyledPhoto(source.path, copied, {}, true);
    await File('${output.path}/photo-shadow.png').writeAsBytes(shadowBytes);
    final cast = img.decodePng(shadowBytes)!;
    expect(cast.getPixel(173, 70).r, 255);
    expect(cast.getPixel(173, 70).g, 0);
    expect(cast.getPixel(17, 70).g, 255);
    expect((cast.getPixel(95, 70).r - original.getPixel(75, 50).r).abs(),
        lessThan(3));
    copied.shadow
      ..opacity = 50
      ..feather = 40;
    final soft =
        img.decodePng(await renderStyledPhoto(source.path, copied, {}, true))!;
    expect(soft.getPixel(173, 70).g, inExclusiveRange(0, 255));
    expect((soft.getPixel(95, 70).r - original.getPixel(75, 50).r).abs(),
        lessThan(3));
    copied.shadow.enabled = false;
    copied.fill
      ..mode = 'gradient'
      ..gradientType = 'radial'
      ..centerX = 0
      ..centerY = 0
      ..radius = 100
      ..secondColor = 0xff000000;
    final radial =
        img.decodePng(await renderStyledPhoto(source.path, copied, {}, true))!;
    expect(radial.getPixel(1, 1).r, greaterThan(240));
    expect(radial.getPixel(188, 138).r, lessThan(10));
    expect(copied.copy().fill.gradientType, 'radial');
    final matrix = backgroundColorMatrix(0, 100, 100);
    expect(
        matrix, [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]);
  });
  testWidgets('快速切换图片样式及缩略图缓存压力不丢失当前素材', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ImageMark mark(int value) {
      final pixels = img.Image(width: 8, height: 4, numChannels: 4);
      img.fill(pixels, color: img.ColorRgba8(value, 120, 220, 255));
      return ImageMark(data: base64Encode(img.encodePng(pixels)), ratio: 2);
    }

    final presets = _MemoryPresets();
    final settings =
        WorkspaceSettings(File('test/background-output/settings.json'));
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: PresetEditor(
            files: [],
            current: 0,
            selected: {},
            initial: StyleDocument(),
            settings: settings,
            presets: presets,
            metadata: (_) async => {},
            apply: (_, __) async {})));
    final dynamic state = tester.state(find.byType(PresetEditor));
    final c = state.c as EditorController;
    final first = mark(221), second = mark(222);
    await tester.runAsync(() async {
      c.edit(() {
        final n = StyleNode(type: 'image', image: first);
        c.doc.nodes.add(n);
        c.doc.order.add(n.id);
      });
      expect(state.marksLoading, true);
      c.edit(() => c.doc.nodes.single.image = second);
      for (var i = 0; i < 30 && !imageMarkReady(second.data); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(imageMarkReady(second.data), true, reason: '快速切换后的第二份素材也必须加载');
    await tester.runAsync(() async {
      await prepareImageMarks([for (var i = 0; i < 20; i++) mark(i)]);
    });
    expect(imageMarkReady(second.data), true, reason: '编辑文档的素材不能被缩略图淘汰');
    final clone = imageMarkClone(second.data);
    expect(clone, isNotNull);
    clone?.dispose();
    c.edit(() {
      c.doc.fill.mode = 'blur';
      c.doc.film.enabled = true;
      c.doc.shadow.enabled = true;
    });
    state.update(() {
      state.panel = 1;
    });
    await tester.pump();
    for (final labels in [
      ['明度', '对比度', '饱和度'],
      ['孔宽', '孔高', '圆角']
    ]) {
      final y = tester.getTopLeft(find.text(labels.first)).dy;
      for (final label in labels.skip(1)) {
        expect(tester.getTopLeft(find.text(label)).dy, closeTo(y, .1));
      }
    }
    expect(tester.getTopLeft(find.text('孔间距')).dy,
        closeTo(tester.getTopLeft(find.text('距外缘')).dy, .1));
    expect(find.text('明暗'), findsNothing);
    expect(find.text('尺寸以照片短边 1000 px 为基准；装饰可与任意背景填充组合。'), findsNothing);
    final canvasPanel = find.ancestor(
        of: find.text('照片投影'), matching: find.byType(SingleChildScrollView));
    expect(find.descendant(of: canvasPanel, matching: find.text('添加组件')),
        findsNothing);
    final shadowColor = find
        .byWidgetPredicate((w) => w is ColorSwatchButton && w.label == '投影颜色');
    expect(tester.widget<ColorSwatchButton>(shadowColor).color,
        const Color(0xff000000));
    expect(tester.getTopLeft(find.text('背景填充')).dy,
        lessThan(tester.getTopLeft(find.text('照片投影')).dy));
    expect(tester.getTopLeft(find.text('照片投影')).dy,
        lessThan(tester.getTopLeft(find.text('胶片打孔')).dy));
    await tester.ensureVisible(shadowColor);
    await tester.tap(shadowColor);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('hsb-hex')), '#336699');
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(c.doc.shadow.color, 0xff336699);
    c.undo();
    await tester.pump();
    expect(c.doc.shadow.color, 0xff000000);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
  });
}

class _MemoryPresets extends PresetStore {
  _MemoryPresets() : super(File('test/background-output/memory.json'));
  @override
  Future<void> save(
      {StyleDocument? draft,
      List<UserPreset>? presets,
      String? sourceKey}) async {
    if (draft != null) this.draft = draft.copy();
    if (presets != null) this.presets = presets;
  }
}
