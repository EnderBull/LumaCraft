import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/editor/preset_store.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/ui/editor/editor_page.dart';
import 'package:lumacraft/workspace_settings.dart';

/// 应用样式的范围规则：只选中一张时直接应用，选中多张才问范围。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory output;
  late List<File> photos;
  late ui.Image seed;

  setUpAll(() async {
    output = await Directory(
            'build/export-ui-check-0163-apply/run-${DateTime.now().millisecondsSinceEpoch}')
        .create(recursive: true);
    final picture = img.Image(width: 300, height: 200);
    img.fill(picture, color: img.ColorRgb8(70, 120, 150));
    picture.exif.exifIfd[0x9003] = '2024:05:05 10:00:00';
    final bytes = img.encodeJpg(picture);
    photos = [
      for (final name in ['one.jpg', 'two.jpg'])
        File('${output.path}/$name')..writeAsBytesSync(bytes)
    ];
    final codec = await ui.instantiateImageCodec(bytes);
    seed = (await codec.getNextFrame()).image;
    codec.dispose();
  });

  Future<List<Set<String>>> mount(WidgetTester tester,
      {required Set<String> selected}) async {
    final applied = <Set<String>>[];
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: PresetEditor(
            files: photos,
            current: 0,
            selected: selected,
            initial: StyleDocument.template(),
            settings: WorkspaceSettings(File('${output.path}/workspace.json')),
            presets: _MemoryPresets(File('${output.path}/presets.json')),
            metadata: (f) async => <String, String>{},
            initialPhoto: seed,
            initialDirectory: output.path,
            apply: (doc, paths) async => applied.add(paths))));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 200));
    return applied;
  }

  testWidgets('只选中一张时不弹范围对话框，直接应用', (tester) async {
    final applied = await mount(tester, selected: {photos.first.path});
    await tester.tap(find.text('应用样式'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('确认应用'), findsNothing);
    expect(applied.length, 1);
    expect(applied.single, {photos.first.path});
  });

  testWidgets('选中多张时弹范围对话框', (tester) async {
    final applied = await mount(tester,
        selected: {photos[0].path, photos[1].path});
    await tester.tap(find.text('应用样式'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('确认应用'), findsOneWidget);
    expect(find.textContaining('选中照片 · 2 张'), findsOneWidget);
    // 默认选中「选中照片」，确认后两张都应用。
    await tester.tap(find.text('确认应用'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(applied.length, 1);
    expect(applied.single.length, 2);
  });
}

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
