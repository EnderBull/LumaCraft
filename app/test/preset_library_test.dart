import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/editor/preset_selection.dart';
import 'package:lumacraft/editor/preset_store.dart';
import 'package:lumacraft/editor/preset_package.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/image_mark.dart';
import 'package:lumacraft/ui/preset_panel.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/ui/editor/prototype_controls.dart';
import 'package:lumacraft/ui/preset_thumbnail.dart';
import 'package:lumacraft/workspace_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('多选只应用首项，Ctrl/Shift/框选与普通单击分离', () {
    final s = PresetSelection(), order = ['a', 'b', 'c', 'd'];
    expect(s.choose('a', order), 'a');
    expect(s.choose('b', order, control: true), isNull);
    expect(s.choose('d', order, shift: true), isNull);
    expect(s.ids, {'b', 'c', 'd'});
    expect(s.primary, 'a');
    expect(s.choose('b', order, control: true), isNull);
    s.clear();
    expect(s.marquee({'d', 'c'}, order, {}), 'c');
    expect(s.marquee({'a'}, order, {'c', 'd'}), isNull);
    expect(s.choose('d', order), 'd');
    expect(s.ids, {'d'});
  });
  test('分组持久化、两种删除路径、LMP素材往返及冲突合并', () async {
    final output = await Directory(
            'test/preset-output/run-${DateTime.now().millisecondsSinceEpoch}')
        .create(recursive: true);
    final store = PresetStore(File('${output.path}/library.json'));
    final pixels = img.Image(width: 4, height: 2, numChannels: 4);
    img.fill(pixels, color: img.ColorRgba8(70, 120, 180, 128));
    final style = StyleDocument.template()..name = '旅行样式';
    final logo = StyleNode(
        type: 'image',
        image: ImageMark(
            data: base64Encode(img.encodePng(pixels)),
            ratio: 2,
            filename: r'C:\private\signature.png'));
    style.nodes.add(logo);
    style.order.add(logo.id);
    style.shadow.enabled = true;
    await Future.wait([
      store.saveLibrary(
          [UserPreset('a', style, folder: 'g')], [PresetFolder('g', '旅行')]),
      store.save(draft: style, sourceKey: 'photo')
    ]);
    final loaded = PresetStore(store.file);
    await loaded.load();
    expect(loaded.folders.single.name, '旅行');
    expect(loaded.presets.single.folder, 'g');
    final bytes = encodeLmp([SharedPreset(style, folder: '旅行')]);
    expect(bytes.contains('private'), false);
    expect(bytes.contains('draft'), false);
    final file = File('${output.path}/travel.lmp');
    await file.writeAsString(bytes);
    final decoded = await readLmp(file);
    expect(decoded.single.style.nodes.last.image.filename, 'signature.png');
    final restored = img
        .decodePng(base64Decode(decoded.single.style.nodes.last.image.data))!;
    expect(restored.getPixel(1, 1).a, 128);
    expect(decoded.single.style.shadow.enabled, true);
    final copied = mergeLmp(loaded, decoded, {});
    expect(copied.presets.length, 2);
    expect(copied.presets.last.style.name, '旅行样式 (2)');
    final replaced = mergeLmp(loaded, decoded, {0: 'replace'});
    expect(replaced.presets.length, 1);
    expect(replaced.presets.single.id, 'a');
    expect(mergeLmp(loaded, decoded, {0: 'skip'}).count, 0);
    final snapshot = jsonEncode(loaded.presets.single.style.toJson());
    final bad = jsonDecode(bytes);
    bad['presets'][0]['style']['order'] = ['missing'];
    expect(() => decodeLmp(jsonEncode(bad)), throwsFormatException);
    expect(jsonEncode(loaded.presets.single.style.toJson()), snapshot);
    bad['presets'][0]['style'] = style.toJson();
    bad['requires'] = ['future3d'];
    expect(() => decodeLmp(jsonEncode(bad)), throwsFormatException);
    await loaded.deleteFolder('g', deleteContents: false);
    expect(loaded.presets.single.folder, '');
    expect(loaded.folders, isEmpty);
    await loaded.saveLibrary(
        [UserPreset('a', style, folder: 'g')], [PresetFolder('g', '旅行')]);
    await loaded.deleteFolder('g', deleteContents: true);
    expect(loaded.presets, isEmpty);
    final jpg = img.Image(width: 4, height: 3);
    img.fill(jpg, color: img.ColorRgb8(10, 90, 140));
    jpg.exif.exifIfd[0x8827] = img.IfdValueShort(320);
    final jpegStyle = StyleDocument(nodes: [
      StyleNode(
          type: 'image',
          image:
              ImageMark(data: base64Encode(img.encodeJpg(jpg)), ratio: 4 / 3))
    ]);
    jpegStyle.order = jpegStyle.nodes.map((n) => n.id).toList();
    final jpegOut = decodeLmp(encodeLmp([SharedPreset(jpegStyle)]))
        .single
        .style
        .nodes
        .single
        .image;
    expect(img.decodeJpg(base64Decode(jpegOut.data))!.exif.exifIfd[0x8827],
        isNull);
    store.dispose();
    loaded.dispose();
  });
  testWidgets('共用面板单击、多选、框选不重复套用，删除组须选处理方式', (tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _MemoryStore();
    store.presets = [
      for (var i = 0; i < 4; i++)
        UserPreset('p$i', StyleDocument.template()..name = '用户预设$i',
            folder: 'g')
    ];
    store.folders = [PresetFolder('g', '旅行')];
    store.presets[0].style.suitability = 'landscape';
    store.presets[1].style.suitability = 'portrait';
    final settings =
        WorkspaceSettings(File('test/preset-output/settings.json'));
    late ui.Image photo;
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(
          img.encodePng(img.Image(width: 60, height: 40)));
      photo = (await codec.getNextFrame()).image;
      codec.dispose();
    });
    final applied = <String>[];
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: Scaffold(
            body: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                    width: 312,
                    child: PresetPanel(
                        store: store,
                        settings: settings,
                        photo: photo,
                        onApply: (e) async {
                          applied.add(e.id);
                        }))))));
    await tester.pumpAndSettle();
    final landscapeBadge =
        find.byKey(const ValueKey('composition-badge:landscape'));
    final portraitBadge =
        find.byKey(const ValueKey('composition-badge:portrait'));
    final universalBadge =
        find.byKey(const ValueKey('composition-badge:universal')).first;
    expect(landscapeBadge, findsOneWidget);
    expect(portraitBadge, findsOneWidget);
    expect(
        find.descendant(
            of: landscapeBadge, matching: find.byType(PrototypeIcon)),
        findsOneWidget);
    expect(
        find.descendant(
            of: portraitBadge, matching: find.byType(PrototypeIcon)),
        findsOneWidget);
    expect(
        find.descendant(
            of: universalBadge, matching: find.byType(PrototypeIcon)),
        findsNWidgets(2));
    expect(find.text('横图优先'), findsNothing);
    expect(find.text('竖图优先'), findsNothing);
    expect(find.text('横竖通用'), findsNothing);
    for (final expected in ['universal', 'landscape', 'portrait', 'all']) {
      await tester.tap(find.byWidgetPredicate(
          (w) => w is Tooltip && (w.message ?? '').startsWith('构图筛选：')));
      await tester.pumpAndSettle();
      expect(store.librarySuitability, expected);
    }
    await tester.tap(find.text('画廊签名'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('胶片档案'));
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(store.selection.ids, {'gallery', 'film'});
    expect(applied, ['gallery']);
    expect(find.text('重命名'), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('用户预设1'));
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(applied, ['gallery']);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(store.selection.ids, isEmpty);
    final dynamic state = tester.state(find.byType(PresetPanel));
    final grid = tester.getTopLeft(find.byKey(state.gridKey));
    final width = state.cellWidth as double,
        height = state.cellHeight as double;
    final gesture = await tester.startGesture(grid + const Offset(2, 10));
    await gesture.moveTo(grid + const Offset(8, 35));
    await tester.pump();
    await gesture.moveTo(grid + Offset(width + 36, height + 25));
    await tester.pump();
    expect(applied, ['gallery']);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(applied, ['gallery', 'gallery']);
    expect(store.selection.ids.length, greaterThan(1));
    state.update(store.selection.clear);
    await tester.pump();
    final right = await tester.startGesture(grid +
        Offset(tester.getSize(find.byKey(state.gridKey)).width - 12, 10));
    await right.moveTo(grid +
        Offset(tester.getSize(find.byKey(state.gridKey)).width - 12, 35));
    await tester.pump();
    await right.moveTo(grid + Offset(width + 35, height + 25));
    await right.up();
    await tester.pumpAndSettle();
    expect(store.selection.ids, {'film', 'user:p1'});
    await tester.tap(find.byTooltip('预设管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理分组'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(Dialog), matching: find.byType(PresetThumbnail)),
        findsNWidgets(3));
    await tester.tap(find.text('旅行'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(Dialog), matching: find.byType(PresetThumbnail)),
        findsNWidgets(4));
    expect(find.text('用户预设0'), findsWidgets);
    await tester.tap(find.byTooltip('返回分组列表'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('旅行'));
    await tester.pumpAndSettle();
    final renameButton = find.widgetWithText(TextButton, '重命名分组'),
        exportButton = find.widgetWithText(TextButton, '导出分组'),
        deleteButton = find.widgetWithText(TextButton, '删除分组');
    final renameStyle = tester.widget<TextButton>(renameButton).style!,
        exportStyle = tester.widget<TextButton>(exportButton).style!,
        deleteStyle = tester.widget<TextButton>(deleteButton).style!;
    expect(renameStyle.backgroundColor!.resolve({}),
        exportStyle.backgroundColor!.resolve({}));
    expect(deleteStyle.backgroundColor!.resolve({}),
        isNot(renameStyle.backgroundColor!.resolve({})));
    expect(renameStyle.textStyle!.resolve({})!.fontSize, 13);
    expect(renameStyle.textStyle!.resolve({})!.fontWeight, FontWeight.w500);
    expect(tester.getSize(renameButton).height, 40);
    expect(
        (renameStyle.shape!.resolve({})! as RoundedRectangleBorder)
            .borderRadius,
        BorderRadius.circular(6));
    await tester.tap(find.text('删除分组'));
    await tester.pumpAndSettle();
    expect(find.text('保留预设，移至未分组'), findsOneWidget);
    expect(
        tester
            .widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>))
            .groupValue,
        false);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(store.folders, isEmpty);
    expect(store.presets.length, 4);
    expect(store.presets.every((p) => p.folder.isEmpty), true);
    await tester.tap(find.byTooltip('关闭分组管理'));
    await tester.pumpAndSettle();
    final dynamic fresh = tester.state(find.byType(PresetPanel));
    final origin = tester.getTopLeft(find.byKey(fresh.gridKey));
    await tester.tapAt(origin + Offset((fresh.cellWidth as double) + 24, 8),
        buttons: 2);
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建分组'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '新旅行');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(store.folders.single.name, '新旅行');
    await tester.tap(find.text('全部分组'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('＋ 新建分组'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '下拉新分组');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(store.folders.last.name, '下拉新分组');
    expect(store.libraryFolder, store.folders.last.id);

    await tester.pumpWidget(const SizedBox());
    photo.dispose();
    settings.dispose();
    store.dispose();
  });
}

class _MemoryStore extends PresetStore {
  _MemoryStore() : super(File('test/preset-output/memory.json'));
  @override
  Future<void> saveLibrary(
      List<UserPreset> presets, List<PresetFolder> folders) async {
    this.presets = presets;
    this.folders = folders;
    notifyListeners();
  }
}
