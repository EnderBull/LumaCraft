import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/preset_store.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/ui/android/alpha_workspace.dart';
import 'package:lumacraft/ui/android/mobile_editor_page.dart';
import 'package:lumacraft/ui/android/preset_demo_preview.dart';

void main() {
  testWidgets('组件面板横滑切换标签，数值框优先处理拖动', (tester) async {
    final workspace = AlphaWorkspace();
    addTearDown(workspace.dispose);
    final id = workspace.style.nodes.first.id;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: workspace,
          builder: (context, _) => MobileEditorPanel(
            workspace: workspace,
            selected: id,
            onSelected: (_) {},
            onDragUpdate: (_) {},
            onDragEnd: (_) {},
            onDragCancel: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final fontSize = workspace.style.node(id)!.fontSize;
    final number = find
        .ancestor(
          of: find.text('字号 px'),
          matching: find.byType(Column),
        )
        .first;
    final rect = tester.getRect(number);
    await tester.dragFrom(
        rect.bottomCenter - const Offset(0, 20), const Offset(85, 0));
    await tester.pumpAndSettle();
    expect(workspace.style.node(id)!.fontSize, greaterThan(fontSize));
    expect(find.text('字体'), findsOneWidget);

    await tester.dragFrom(const Offset(794, 205), const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(find.text('请先选择照片。'), findsOneWidget);

    await tester.tap(find.text('批次样式'));
    await tester.pumpAndSettle();
    // The separate label and the dropdown are distinct touch targets.
    await tester.tap(find.byKey(const ValueKey('mobile-font-picker')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    final option = find.text('Jost').last;
    expect(tester.widget<Text>(option).style?.fontFamily, 'LCJost');
    final fontList =
        find.ancestor(of: option, matching: find.byType(ListView)).first;
    expect(tester.widget<ListView>(fontList).physics,
        isA<BouncingScrollPhysics>());
  });

  test('用户缩略图跨实例复用，覆盖样式后重新生成', () async {
    final dir = await Directory.systemTemp.createTemp('lumacraft-preview-test');
    addTearDown(() async {
      for (final file in dir.listSync().whereType<File>()) {
        await file.delete();
      }
      await dir.delete();
    });
    final style = StyleDocument.template();
    final cache = PresetDemoCache(dir);
    final bytes = await cache.read(PresetEntry('user:one', style));
    expect(bytes, isNotNull);
    cache.dispose();

    final file = dir.listSync().whereType<File>().single;
    final oldTime = DateTime.utc(2020);
    await file.setLastModified(oldTime);

    final restarted = PresetDemoCache(dir);
    addTearDown(restarted.dispose);
    final renamed = style.copy()..name = '改名';
    expect(await restarted.read(PresetEntry('user:one', renamed)), bytes);
    expect((await file.lastModified()).toUtc(), oldTime);

    final changed = renamed.copy()..background = 0xff0000ff;
    final updated = await restarted.read(PresetEntry('user:one', changed));
    expect(updated, isNotNull);
    expect(updated, isNot(equals(bytes)));
    expect(dir.listSync().whereType<File>(), hasLength(1));
  });
}
