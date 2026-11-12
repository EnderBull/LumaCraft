import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/preset_package.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/ui/android/preset_import_confirmation.dart';

void main() {
  testWidgets('导入确认在选择前不返回同意，并区分取消和确认', (tester) async {
    bool? approved;
    final entries = [
      SharedPreset(StyleDocument.template()..name = '测试画廊'),
      SharedPreset(StyleDocument.template(true)..name = '测试胶片'),
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          approved = null;
          approved = await confirmMobilePresetImport(context, entries);
        },
        child: const Text('打开'),
      ),
    ))));
    for (final action in ['取消', '确认导入']) {
      await tester.tap(find.text('打开'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(approved, isNull);
      expect(find.text('导入预设 · 2 个'), findsOneWidget);
      expect(find.text('测试画廊'), findsOneWidget);
      expect(find.text('测试胶片'), findsOneWidget);
      await tester.tap(find.text(action));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(approved, action == '确认导入');
    }
  });
}
