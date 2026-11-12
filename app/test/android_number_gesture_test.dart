import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/ui/android/mobile_fields.dart';

void main() {
  testWidgets('数值框纵向滚动、横向拖动只提交一次、双击复位', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final commits = <double?>[];
    final previews = <double?>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          controller: scroll,
          children: [
            const SizedBox(height: 120),
            StatefulBuilder(
                builder: (context, setState) => MobileNumberField(
                      label: '长度 px',
                      value: commits.isEmpty ? 42 : commits.last,
                      defaultValue: 42,
                      step: .1,
                      onPreview: previews.add,
                      onChanged: (value) => setState(() => commits.add(value)),
                    )),
            const SizedBox(height: 900),
          ],
        ),
      ),
    ));
    final number = find.byType(InputDecorator);
    await tester.drag(number, const Offset(3, -85));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(commits, isEmpty);

    scroll.jumpTo(0);
    await tester.pump();
    final drag = await tester.startGesture(tester.getCenter(number));
    await drag.moveBy(const Offset(26, 1));
    await drag.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(previews.last, greaterThan(42));
    expect(commits, isEmpty);
    await drag.up();
    await tester.pumpAndSettle();
    expect(commits, hasLength(1));
    expect(commits.single, greaterThan(42));

    await tester.tap(number);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(number);
    await tester.pumpAndSettle();
    expect(commits.last, 42);
    expect(find.byType(TextField), findsNothing);
  });
}
