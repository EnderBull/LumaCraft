import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/editor/builtin_library.dart';
import 'package:lumacraft/editor/preset_store.dart';
import 'package:lumacraft/editor/style_render.dart';
import 'package:lumacraft/main.dart' as app;
import 'package:lumacraft/photo_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('默认样式取内置“画廊签名”，随制作版里的修改同步，缺失时退回第一款', () async {
    final dir = await Directory.systemTemp.createTemp('lc-default-');
    addTearDown(() => dir.delete(recursive: true));
    final store =
        PresetStore(File('${dir.path}/presets.json'), authoring: true);
    await store.load();
    expect(store.defaultStyle().name, '画廊签名');
    expect(identical(store.defaultStyle(), store.defaultStyle()), false,
        reason: '每次返回副本，调用方改动不会污染内置库');
    final original = store.builtinOriginal('gallery')!;
    await store.saveBuiltin(
        'gallery', original.style.copy()..name = '我改过的画廊', original.folder);
    expect(store.defaultStyle().name, '我改过的画廊', reason: '默认样式跟着制作版里的修改走');
    await store.restoreBuiltin('gallery');
    expect(store.defaultStyle().name, '画廊签名');
    // 不再是早期的 template：文字组件是内置预设里的题签，而不是 Gallery Collection。
    final fromStore = store.defaultStyle();
    expect(fromStore.nodes.any((n) => n.text == 'Gallery Collection'), false);
    expect(fromStore.nodes.any((n) => n.text == 'MOUNTAIN SILENCE'), true);
    // 内置库里没有 gallery 时，退回第一款。
    final noGallery = store.builtinLibrary.entries
        .where((e) => e.id != 'gallery')
        .toList();
    await store.writeBuiltinLibrary(
        BuiltinLibrary(store.builtinLibrary.folders, noGallery));
    expect(store.defaultStyle().name, noGallery.first.style.name);
  });

  testWidgets('没设样式的照片，浏览页预览直接显示“画廊签名”', (tester) async {
    final root = PhotoStore.defaultFile().parent;
    expect(Platform.environment['LUMACRAFT_DATA_DIR'],
        contains('export-ui-check'));
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Directory input;
    await tester.runAsync(() async {
      input = await Directory('${root.path}/default-input').create(recursive: true);
      final image = img.Image(width: 240, height: 160);
      img.fill(image, color: img.ColorRgb8(70, 110, 130));
      await File('${input.path}/only.jpg').writeAsBytes(img.encodeJpg(image));
      await File('${root.path}/workspace.json').writeAsString(
          jsonEncode({'version': 1, 'lastDirectory': input.path}));
      final file = File('${root.path}/photo-state.json');
      if (await file.exists()) await file.delete();
    });
    await tester.pumpWidget(const app.LumaCraftApp());
    Future<void> waitFor(bool Function() done) async {
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump(const Duration(milliseconds: 40));
        if (done()) return;
      }
      fail('预览未在预期时间内出现');
    }

    // 主画布上的预览（预设面板里的缩略图也是 StylePreview，不算）。
    final main = find.byWidgetPredicate((w) => w is StylePreview && w.workspaceCanvas);
    await waitFor(() => main.evaluate().isNotEmpty);
    final preview = tester.widget<StylePreview>(main);
    expect(preview.document.name, '画廊签名');
    expect(preview.document.nodes.any((n) => n.text == 'Gallery Collection'),
        false);
    expect(find.text('画廊签名'), findsWidgets);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    // 让界面卸载后的延时任务（目录扫描、预览加载）跑完，避免测试结束时还有未完成的计时器。
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
