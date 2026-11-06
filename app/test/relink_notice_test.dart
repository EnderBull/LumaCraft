import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/ui/editor/workspace_chrome.dart';
import 'package:lumacraft/ui/smooth_scroll.dart';

/// 自动关联成功后，底栏要能看到「已自动关联 N 张」，样式与需要手动处理的
/// 「重新关联」区分开。
void main() {
  testWidgets('自动关联提示与手动关联按钮同时存在且区分开', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var shown = 0;
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: Scaffold(
            body: SizedBox(
                height: 260,
                child: WorkspaceFilmstrip(
                  files: const [],
                  selected: const {},
                  current: 0,
                  controller: SmoothScrollController(),
                  onSelect: (_, __, ___) {},
                  onSelectAll: () {},
                  onClear: () {},
                  relinkCount: 2,
                  onRelink: () {},
                  autoRelinkCount: 3,
                  onShowAutoRelink: () => shown++,
                )))));
    await tester.pump();
    expect(find.text('重新关联 2 张'), findsOneWidget);
    expect(find.text('已自动关联 3 张'), findsOneWidget);
    await tester.tap(find.text('已自动关联 3 张'));
    expect(shown, 1);
  });

  testWidgets('没有自动关联时不显示该提示', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: Scaffold(
            body: SizedBox(
                height: 260,
                child: WorkspaceFilmstrip(
                  files: const [],
                  selected: const {},
                  current: 0,
                  controller: SmoothScrollController(),
                  onSelect: (_, __, ___) {},
                  onSelectAll: () {},
                  onClear: () {},
                  relinkCount: 0,
                  onRelink: () {},
                  onShowAutoRelink: () {},
                )))));
    await tester.pump();
    expect(find.textContaining('已自动关联'), findsNothing);
    expect(find.textContaining('重新关联'), findsNothing,
        reason: '没有待关联时不该出现按钮');
  });
}
