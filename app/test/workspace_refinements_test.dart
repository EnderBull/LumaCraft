import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/style_render.dart';
import 'package:lumacraft/editor/preset_store.dart';
import 'package:lumacraft/ui/folder_select.dart';
import 'package:lumacraft/ui/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('缺失EXIF仅编辑时显示可选中占位，渲染默认不输出提示', () async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
    final picture = recorder.endRecording();
    final photo = await picture.toImage(300, 200);
    final doc = StyleDocument.template();
    final lens = StyleNode(type: 'lens');
    doc.nodes.add(lens);
    doc.order.add(lens.id);
    final editor = StyleScene(doc, photo, {}, showMissingInfo: true);
    expect(editor.painters[lens.id]!.text!.toPlainText(), '缺少镜头型号信息');
    expect(editor.bounds.containsKey(lens.id), true);
    final exported = StyleScene(doc, photo, {});
    expect(exported.bounds.containsKey(lens.id), false);
    final complete =
        StyleScene(doc, photo, {'lens': '35mm'}, showMissingInfo: true);
    expect(complete.painters[lens.id]!.text!.toPlainText(), '35mm');
    editor.dispose();
    exported.dispose();
    complete.dispose();
    photo.dispose();
    picture.dispose();
  });
  testWidgets('大量分组时新建弹窗按内容收缩，错误标签不撑满窗口', (tester) async {
    final store = PresetStore(File('build/refinements-unused.json'))
      ..folders = [for (var i = 0; i < 60; i++) PresetFolder('$i', '组$i')];
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => createPresetFolder(context, store),
                    child: const Text('打开'))))));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(
        tester.getBottomRight(find.text('确定')).dy -
            tester.getTopLeft(find.text('新建分组')).dy,
        lessThan(300));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(
        tester.getBottomRight(find.text('确定')).dy -
            tester.getTopLeft(find.text('新建分组')).dy,
        lessThan(330));
    expect(find.text('请输入不重复的分组名称'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
