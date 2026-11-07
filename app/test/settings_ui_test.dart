import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/settings/app_settings.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/ui/settings_dialog.dart';
import 'package:lumacraft/workspace_settings.dart';

/// 设置面板：三个标签页能切换，关键控件都在。
///
/// 这些用例只验证界面和内存状态，不触发落盘：设置类在改动后会启动一个
/// 防抖保存定时器，写真实文件在测试环境里会挂住。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late AppSettings app;
  late WorkspaceSettings workspace;

  setUp(() {
    dir = Directory(
        'build/export-ui-check-0275-ui/run-${DateTime.now().microsecondsSinceEpoch}')
      ..createSync(recursive: true);
    app = AppSettings(File('${dir.path}/app-settings.json'));
    workspace = WorkspaceSettings(File('${dir.path}/workspace.json'));
  });

  tearDown(() {
    app.dispose();
    workspace.dispose();
  });

  Future<void> mount(WidgetTester tester, {bool dark = true}) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(dark),
        home: Scaffold(
            body: SettingsDialog(workspace: workspace, app: app))));
    await tester.pump();
  }

  /// 收起界面。先让待保存的改动落地，再切走。
  ///
  /// flush 会等写盘完成，定时器随之清空；否则测试结束时会报「定时器还在等」。
  Future<void> unmount(WidgetTester tester) async {
    await tester.runAsync(() async {
      await app.flush();
      await workspace.save();
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('三个标签页都能打开', (tester) async {
    await mount(tester);
    // 通用页
    expect(find.text('深色模式'), findsOneWidget);
    expect(find.text('打开预设文件夹'), findsOneWidget);
    expect(find.text('重新加载缩略图'), findsOneWidget);
    expect(find.text('清理使用记录'), findsOneWidget);

    await tester.tap(find.text('高德 API'));
    await tester.pump();
    expect(find.text('高德地图 Key'), findsOneWidget);
    expect(find.text('安全密钥'), findsOneWidget);
    expect(find.text('测试连接'), findsOneWidget);
    expect(find.text('获取教程'), findsOneWidget);
    // 教程默认收起
    expect(find.text('注册并登录'), findsNothing);

    await tester.tap(find.text('获取教程'));
    await tester.pump();
    expect(find.text('注册并登录'), findsOneWidget);
    // 白名单要出现在教程里，并且是可直接点击的说明文字。
    expect(find.textContaining('127.0.0.1'), findsWidgets);
    // 详细教程：每一步都有标题。
    expect(find.text('完成实名认证'), findsOneWidget);
    expect(find.text('创建应用'), findsOneWidget);
    // 「添加 Key」在标题和正文里各出现一次，不限定数量。
    expect(find.text('添加 Key'), findsWidgets);
    expect(find.text('配置域名白名单'), findsOneWidget);
    expect(find.text('填进这里'), findsOneWidget);
    // 关键提醒要出现（平台选错是常见错误）。
    expect(find.textContaining('服务平台选错'), findsOneWidget);
    // 可点击链接：控制台地址。
    expect(find.text('高德开放平台控制台'), findsOneWidget);

    await tester.tap(find.text('关于'));
    await tester.pump();
    expect(find.text('框印工坊'), findsOneWidget);
    expect(find.text('GitHub 仓库'), findsOneWidget);
    expect(find.text('查看全部快捷键'), findsOneWidget);
    // 快捷键默认收起
    expect(find.text('Ctrl + Z'), findsNothing);

    await tester.tap(find.text('查看全部快捷键'));
    await tester.pump();
    expect(find.text('Ctrl + Z'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('深色模式开关改变设置值', (tester) async {
    await mount(tester);
    expect(workspace.dark, isTrue);
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(workspace.dark, isFalse);
    await unmount(tester);
  });

  testWidgets('浅色模式下也能正常显示', (tester) async {
    await mount(tester, dark: false);
    expect(find.text('深色模式'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('填写的密钥写进内存设置', (tester) async {
    await mount(tester);
    await tester.tap(find.text('高德 API'));
    await tester.pump();
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.first, 'my-amap-key');
    await tester.pump();
    expect(app.amapKey, 'my-amap-key');
    await unmount(tester);
  });

  testWidgets('自动填地点开关默认打开', (tester) async {
    await mount(tester);
    await tester.tap(find.text('高德 API'));
    await tester.pump();
    expect(find.text('有坐标时自动填地点'), findsOneWidget);
    expect(app.autoFillPlace, isTrue);
    await unmount(tester);
  });

  testWidgets('高德 API 标签在一行显示，不换行', (tester) async {
    await mount(tester);
    final label = find.text('高德 API');
    expect(label, findsOneWidget);
    // 单个 Text 渲染高度应接近一行：换行会让高度接近两倍。
    final size = tester.getSize(label);
    expect(size.height, lessThan(24), reason: '标签不该折成两行');
  });

  testWidgets('清理使用记录需要输入确认文字', (tester) async {
    await mount(tester);
    await tester.tap(find.text('清理…'));
    await tester.pumpAndSettle();
    // 确认框里应有输入框和提示语。
    expect(find.text('清理使用记录？'), findsOneWidget);
    expect(find.textContaining('确认清理'), findsWidgets);
    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    // 直接点确认应当被拦下（输入为空）。
    await tester.tap(find.text('确认清理').last);
    await tester.pump();
    expect(find.textContaining('请完整输入'), findsOneWidget);
    // 输错也会被拦下。
    await tester.enterText(field, '清理');
    await tester.tap(find.text('确认清理').last);
    await tester.pump();
    expect(find.text('清理使用记录？'), findsOneWidget, reason: '输入不对不能开始清理');
    // 输对后对话框关闭。
    await tester.enterText(field, '确认清理');
    await tester.tap(find.text('确认清理').last);
    await tester.pumpAndSettle();
    expect(find.text('清理使用记录？'), findsNothing);
    await unmount(tester);
  });
}
