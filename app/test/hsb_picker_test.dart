import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/editor_controller.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/ui/editor/hsb_color_picker.dart';
import 'package:lumacraft/ui/editor/number_drag_input.dart';

void main() {
  testWidgets('HSB与HEX同步、实时预览、确定撤销和取消恢复', (tester) async {
    final c = EditorController(StyleDocument());
    final original = c.doc.background;
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      c.begin();
                      final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => HsbColorPicker(
                              initialColor: Color(c.doc.background),
                              onChanged: (color) {
                                c.doc.background = color.toARGB32();
                                c.update();
                              }));
                      c.end(cancel: confirmed != true);
                    },
                    child: const Text('取色'))))));
    await tester.tap(find.text('取色'));
    await tester.pumpAndSettle();
    final fields = find.byType(NumberDragInput);
    for (var i = 0; i < 3; i++) {
      final label = find.text(['H 色相', 'S 饱和度', 'B 亮度'][i]);
      expect(
          tester.getTopLeft(fields.at(i)).dy - tester.getBottomLeft(label).dy,
          closeTo(7, .01));
      expect(tester.getSize(fields.at(i)).height, 40);
    }
    expect(
        tester.getTopLeft(find.byKey(const ValueKey('hsb-hex'))).dy -
            tester.getBottomLeft(find.text('HEX')).dy,
        closeTo(7, .01));
    await tester.enterText(find.byKey(const ValueKey('hsb-hex')), '#00FF00');
    await tester.pumpAndSettle();
    expect(c.doc.background, 0xff00ff00);
    final channels = tester
        .widgetList<NumberDragInput>(find.byType(NumberDragInput))
        .toList();
    expect(
        channels.map((n) => n.controller.text).toList(), ['120', '100', '100']);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(c.doc.background, original);
    expect(c.canUndo, false);
    await tester.tap(find.text('取色'));
    await tester.pumpAndSettle();
    final brightness = find.descendant(
        of: find.byType(NumberDragInput).at(2),
        matching: find.byType(TextField));
    await tester.enterText(brightness, '15');
    await tester.pumpAndSettle();
    expect(c.doc.background, isNot(original));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(c.doc.background, original);
    expect(c.canUndo, false);
    await tester.tap(find.text('取色'));
    await tester.pumpAndSettle();
    final plane = tester.getRect(find.byKey(const ValueKey('hsb-plane')));
    await tester
        .tapAt(plane.topLeft + Offset(plane.width / 2, plane.height / 2));
    await tester.pumpAndSettle();
    final hsv = HSVColor.fromColor(Color(c.doc.background));
    expect(hsv.saturation, closeTo(.5, .02));
    expect(hsv.value, closeTo(.5, .02));
    await tester.enterText(find.byKey(const ValueKey('hsb-hex')), '123ABC');
    await tester.pumpAndSettle();
    expect(c.doc.background, 0xff123abc);
    await tester.ensureVisible(find.text('确定'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(c.doc.background, 0xff123abc);
    expect(c.canUndo, true);
    c.undo();
    expect(c.doc.background, original);
    expect(c.canUndo, false);
    await tester.tap(find.text('取色'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('hsb-hex')), '错误');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '确定'))
            .onPressed,
        isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(c.doc.background, original);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
