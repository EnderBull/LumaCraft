import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/editor_controller.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/ui/editor/number_drag_input.dart';

void main() {
  testWidgets('数值输入支持双轴拖动、修饰键、范围和单次撤销', (tester) async {
    final c = EditorController(StyleDocument.template());
    final input = TextEditingController(text: '32'), focus = FocusNode();
    final scroll = ScrollController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                controller: scroll,
                child: Column(children: [
                  SizedBox(
                      width: 260,
                      child: NumberDragInput(
                          controller: input,
                          focusNode: focus,
                          spec: const NumberDragSpec(
                              min: 8, max: 110, fallback: 32),
                          onChanged: (s) {
                            c.begin();
                            c.doc.nodes.first.fontSize = double.parse(s);
                            c.update();
                          },
                          onDone: c.end,
                          onCancel: () => c.end(cancel: true))),
                  const SizedBox(height: 1600)
                ])))));
    final target = find.byType(TextField);
    Future<void> drag(Offset delta) async {
      final gesture = await tester.startGesture(tester.getCenter(target),
          kind: PointerDeviceKind.mouse);
      await gesture.moveBy(delta);
      await gesture.up();
      await tester.pump();
    }

    await drag(const Offset(40, 0));
    expect(c.doc.nodes.first.fontSize, 42);
    expect(focus.hasFocus, false, reason: '拖动结束后释放文本焦点，使Ctrl+Z交给编辑器按整次拖动撤销');
    c.undo();
    expect(c.doc.nodes.first.fontSize, 32);
    input.text = '32';
    await drag(const Offset(0, -20));
    expect(c.doc.nodes.first.fontSize, 37);
    expect(scroll.offset, 0, reason: '纵向拖动数值不应同时滚动侧栏');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await drag(const Offset(40, 0));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(c.doc.nodes.first.fontSize, 110);
    input.text = '32';
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await drag(const Offset(40, 0));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    expect(c.doc.nodes.first.fontSize, 33);
    await tester.tap(find.byType(NumberDragInput));
    await tester.enterText(target, '24');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(c.doc.nodes.first.fontSize, 24);
    final axisDrag = await tester.startGesture(tester.getCenter(target),
        kind: PointerDeviceKind.mouse);
    await axisDrag.moveBy(const Offset(8, 0));
    await axisDrag.moveBy(const Offset(0, -80));
    await axisDrag.up();
    await tester.pump();
    expect(c.doc.nodes.first.fontSize, 26, reason: '横轴锁定后，竖向移动不应继续加值');
    c.undo();
    input.text = '24';
    final cancelled = await tester.startGesture(tester.getCenter(target),
        kind: PointerDeviceKind.mouse);
    await cancelled.moveBy(const Offset(16, 0));
    await cancelled.cancel();
    await tester.pump();
    expect(c.doc.nodes.first.fontSize, 24, reason: '指针取消应回滚本次拖动');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    input.dispose();
    focus.dispose();
    scroll.dispose();
    c.dispose();
  });
}
