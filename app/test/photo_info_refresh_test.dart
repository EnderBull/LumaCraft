import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/ui/photo_info_form.dart';

/// 信息表单要能跟着外部数据变化更新。
///
/// 记录里的字段是原地修改的同一个 Map，如果只比引用相等，界面就永远
/// 看不到变化——「地图选完地点，地点栏仍显示缺失」就是这个原因。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('外部填入地点后，输入框跟着更新', (tester) async {
    // 真实场景里这个 Map 由 PhotoStore 持有并原地修改。
    final manual = <String, String>{};
    Widget build() => MaterialApp(
        theme: workspaceTheme(true),
        home: Scaffold(
            body: PhotoInfoForm(
                existing: const {},
                manual: manual,
                keys: const ['place'],
                onChanged: (k, v) {})));

    await tester.pumpWidget(build());
    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);

    // 模拟用户在地图上选好地点后写入记录：同一个 Map，只改内容。
    manual['place'] = '浙江省杭州市西湖区文三路';
    await tester.pumpWidget(build());
    await tester.pump();

    expect(tester.widget<TextField>(field).controller!.text,
        '浙江省杭州市西湖区文三路',
        reason: '内容变了就该刷新，不能只比 Map 是不是同一个对象');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('地点清空后输入框也清空', (tester) async {
    final manual = <String, String>{'place': '某个地点'};
    Widget build() => MaterialApp(
        theme: workspaceTheme(true),
        home: Scaffold(
            body: PhotoInfoForm(
                existing: const {},
                manual: manual,
                keys: const ['place'],
                onChanged: (k, v) {})));

    await tester.pumpWidget(build());
    final field = find.byType(TextField);
    expect(tester.widget<TextField>(field).controller!.text, '某个地点');

    manual.remove('place');
    await tester.pumpWidget(build());
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);

    await tester.pumpWidget(const SizedBox());
  });
}
