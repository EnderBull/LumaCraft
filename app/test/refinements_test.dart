import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/builtin_library.dart';
import 'package:lumacraft/editor/preset_package.dart';
import 'package:lumacraft/editor/preset_store.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/fonts/font_catalog.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/ui/editor/component_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('作者签名已移除：组件列表没有它，旧数据与旧 .lmp 自动当作自由文字', () async {
    expect(componentNames.containsKey('author'), false);
    expect(componentNames.keys.toList(), [
      'text', 'params', 'camera', 'lens', 'time', 'place', 'palette', 'image', 'shape'
    ]);
    final old = StyleNode.fromJson({
      'id': 'a1',
      'type': 'author',
      'name': '作者签名',
      'text': 'Alex Chen',
      'font': 'caveat'
    });
    expect(old.type, 'text');
    expect(old.content({}), 'Alex Chen');
    // 内置预设：画廊签名、胶片档案、手机经典·签名边框的原作者签名都变成了自由文字。
    final library = BuiltinLibrary.decode(
        await File('assets/builtins/library.json').readAsString());
    for (final e in library.entries) {
      for (final n in e.style.nodes) {
        expect(n.type == 'author', false, reason: '${e.id}/${n.id}');
      }
    }
    for (final pair in {
      'gallery': 'gallery-author',
      'film': 'film-author',
      'phone-signature': 'author'
    }.entries) {
      final n = library.entries
          .firstWhere((e) => e.id == pair.key)
          .style
          .node(pair.value)!;
      expect(n.type, 'text', reason: pair.key);
      expect(n.name, '签名');
      expect(n.text, 'Alex Chen');
      expect(n.font, 'caveat');
    }
    // 旧 .lmp：把一个新导出的预设改回 author 类型，导入后应成为自由文字。
    final doc = StyleDocument(name: '旧签名', nodes: [
      StyleNode(id: 'x', type: 'text', name: '作者签名', text: 'Alex Chen')
    ]);
    doc.order = ['x'];
    final json = jsonDecode(encodeLmp([SharedPreset(doc)])) as Map;
    ((json['presets'] as List).first['style']['nodes'] as List).first['type'] =
        'author';
    final back = decodeLmp(jsonEncode(json)).single.style;
    expect(back.nodes.single.type, 'text');
    expect(back.nodes.single.text, 'Alex Chen');
    // 新模板里的签名也是自由文字。
    expect(StyleDocument.template().nodes.any((n) => n.type == 'author'), false);
  });

  test('三个最早的字体只保留字体名', () {
    expect(legacyFontNames, {
      'sans': '微软雅黑',
      'serif': 'Georgia',
      'signature': 'Georgia Italic'
    });
    expect(artworkFontOptions['sans'], '微软雅黑');
  });

  test('制作版“恢复默认”：单款恢复、全部恢复，发行版不可用', () async {
    final dir = await Directory.systemTemp.createTemp('lc-restore-');
    addTearDown(() => dir.delete(recursive: true));
    final store =
        PresetStore(File('${dir.path}/presets.json'), authoring: true);
    await store.load();
    final original = store.builtinOriginal('gallery')!;
    expect(original.style.name, '画廊签名');
    await store.saveBuiltin('gallery', original.style.copy()..name = '改过的名字',
        original.folder);
    await store.saveBuiltin('p-extra', StyleDocument(name: '本机新建'), 'classic');
    expect(store.builtinLibrary.entries.first.style.name, '改过的名字');
    expect(store.hasBuiltinOriginal('p-extra'), false);

    await store.restoreBuiltin('gallery');
    expect(store.builtinLibrary.entries.firstWhere((e) => e.id == 'gallery').style.name,
        '画廊签名');
    expect(store.builtinLibrary.entries.any((e) => e.id == 'p-extra'), true,
        reason: '单款恢复不影响其他预设');

    await store.saveBuiltin('gallery', original.style.copy()..name = '又改了', original.folder);
    await store.restoreAllBuiltins();
    final names = store.builtinLibrary.entries.map((e) => e.style.name).toList();
    final packaged = BuiltinLibrary.decode(
        await File('assets/builtins/library.json').readAsString());
    expect(names, packaged.entries.map((e) => e.style.name).toList(),
        reason: '全部恢复默认后与封包库完全一致');
    expect(store.builtinLibrary.entries.any((e) => e.id == 'p-extra'), false,
        reason: '全部恢复默认会去掉本机新建的内置预设');
    // 重新打开仍是默认状态。
    final reopened =
        PresetStore(File('${dir.path}/presets.json'), authoring: true);
    await reopened.load();
    expect(reopened.builtinLibrary.entries.length,
        store.builtinLibrary.entries.length);

    final release =
        PresetStore(File('${dir.path}/presets.json'), authoring: false);
    await release.load();
    expect(release.restoreAllBuiltins, throwsStateError);
  });

  testWidgets('添加组件下拉菜单：贴按钮展开、3 列自动 3 行、点选返回类型、Esc 关闭', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? picked = 'unset';
    final choices = [
      for (final e in componentNames.entries)
        ComponentChoice(e.key, e.value, e.key == 'place' ? 'location' : e.key)
    ];
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: Scaffold(
            body: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Builder(
                        builder: (button) => TextButton(
                            onPressed: () async =>
                                picked = await showComponentPicker(button, choices),
                            child: const Text('添加组件')))))))); 
    expect(componentPickerColumns, 3);
    expect(componentPickerRows(9), 3);
    expect(componentPickerRows(10), 4, reason: '行数随组件数量自动增加');
    expect(componentPickerRows(3), 1);
    await tester.tap(find.text('添加组件'));
    await tester.pumpAndSettle();
    for (final e in componentNames.values) {
      expect(find.text(e), findsOneWidget);
    }
    final order = componentNames.values.toList();
    final points = [for (final name in order) tester.getCenter(find.text(name))];
    for (var i = 0; i < points.length; i++) {
      final row = i ~/ componentPickerColumns, col = i % componentPickerColumns;
      expect(points[i].dy, closeTo(points[row * componentPickerColumns].dy, .5),
          reason: '${order[i]} 与同行对齐');
      expect(points[i].dx, closeTo(points[col].dx, .5),
          reason: '${order[i]} 与同列对齐');
    }
    expect(points[3].dy, greaterThan(points[0].dy + 40));
    expect(points[6].dy, greaterThan(points[3].dy + 40));
    expect(points[1].dx, greaterThan(points[0].dx + 40));
    // 菜单贴着按钮下方展开。
    expect(points[0].dy, greaterThan(tester.getBottomLeft(find.text('添加组件')).dy));
    await tester.tap(find.text('形状'));
    await tester.pumpAndSettle();
    expect(picked, 'shape');
    expect(find.text('形状'), findsNothing, reason: '点选后立即关闭');
    picked = 'unset';
    await tester.tap(find.text('添加组件'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(tester.takeException(), null);
  });
}
