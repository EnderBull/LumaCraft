import '../window_controls.dart';
import '../usage_data.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../photo_state.dart';
import '../workspace_settings.dart';
import '../settings/app_settings.dart';
import 'amap_key_tutorial.dart';
import 'place_picker.dart';
import 'editor/prototype_controls.dart';
import 'photo_thumb.dart';
import 'workspace_dialog.dart';

/// The app's own settings window: appearance, map credentials, about.
Future<void> showSettings(
        {required BuildContext context,
        required WorkspaceSettings workspace,
        required AppSettings app}) =>
    showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => SettingsDialog(workspace: workspace, app: app));

class SettingsDialog extends StatefulWidget {
  final WorkspaceSettings workspace;
  final AppSettings app;
  const SettingsDialog(
      {super.key, required this.workspace, required this.app});
  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  static const panelWidth = 760.0;
  static const panelHeight = 640.0;

  int tab = 0;
  String? notice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
        backgroundColor: scheme.surface,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
                width: panelWidth,
                height: panelHeight,
                child: DefaultTextStyle(
                    style: dialogBodyStyle.copyWith(color: scheme.onSurface),
                    child: Column(children: [
                      _header(),
                      Expanded(
                          child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.fromLTRB(28, 4, 28, 20),
                              child: _tabBody())),
                      if (notice != null) _notice(),
                      _footer()
                    ])))));
  }

  Widget _header() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.fromLTRB(28, 22, 20, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('设置',
                style: dialogTitleStyle.copyWith(
                    fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.2)),
            const Spacer(),
            SizedBox(
                width: 30,
                height: 30,
                child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded,
                        size: 18,
                        color: scheme.onSurface.withValues(alpha: .62))))
          ]),
          const SizedBox(height: 12),
          PrototypeTabs(
              labels: const ['通用', '高德 API', '关于'],
              selected: tab,
              onSelect: (i) => setState(() => tab = i))
        ]));
  }

  Widget _tabBody() => switch (tab) {
        0 => _GeneralPage(
            workspace: widget.workspace,
            app: widget.app,
            onNotice: (text) => setState(() => notice = text)),
        1 => _AmapPage(
            app: widget.app,
            onNotice: (text) => setState(() => notice = text)),
        _ => const _AboutPage()
      };

  Widget _notice() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, size: 14, color: scheme.primary),
          const SizedBox(width: 7),
          Expanded(
              child: Text(notice!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: EditorTypography.hint(context)
                      .copyWith(fontSize: 11.5, color: scheme.primary)))
        ]));
  }

  Widget _footer() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
        padding: const EdgeInsets.fromLTRB(28, 14, 28, 18),
        decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(14)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(
                      alpha: scheme.brightness == Brightness.dark ? .26 : .07),
                  blurRadius: 18,
                  offset: const Offset(0, -4))
            ]),
        child: Row(children: [
          const Spacer(),
          WorkspaceActionButton(
              label: '关闭', onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 10),
          SizedBox(
              height: 40,
              child: FilledButton(
                  style: FilledButton.styleFrom(
                      textStyle: dialogActionStyle,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6))),
                  onPressed: () async {
                    await widget.app.flush();
                    await widget.workspace.save();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('保存')))
        ]));
  }
}

// ---------------------------------------------------------------- 通用

class _GeneralPage extends StatelessWidget {
  final WorkspaceSettings workspace;
  final AppSettings app;
  final ValueChanged<String> onNotice;
  const _GeneralPage(
      {required this.workspace, required this.app, required this.onNotice});

  @override
  Widget build(BuildContext context) => Column(children: [
        _section('外观', [
          ListenableBuilder(
              listenable: workspace,
              builder: (context, _) => _Row(
                  title: '深色模式',
                  detail: '浅色适合白天，深色适合夜间整理照片',
                  trailing: Switch(
                      value: workspace.dark,
                      onChanged: (v) {
                        workspace.dark = v;
                        workspace.changed();
                      })))
        ]),
        const SizedBox(height: 18),
        _section('数据与文件', [
          _Row(
              title: '打开预设文件夹',
              detail: '查看和管理你自己保存的预设',
              trailing: _SmallButton(
                  label: '打开',
                  onPressed: () async {
                    final dir = PhotoStore.defaultFile().parent;
                    if (!dir.existsSync()) await dir.create(recursive: true);
                    await Process.run(
                        Platform.isMacOS ? 'open' : 'explorer.exe',
                        [dir.absolute.path]);
                  })),
          _Row(
              title: '重新加载缩略图',
              detail: '释放内存中缓存的缩略图，不会删除照片或预设',
              trailing: _SmallButton(
                  label: '重新加载',
                  onPressed: () {
                    clearThumbnails();
                    onNotice('已释放缩略图缓存，滚动时会重新生成');
                  })),
          _Row(
              title: '清理使用记录',
              detail: '删除你保存的预设、照片记录、布局和导出设置，无法撤销',
              trailing: _SmallButton(
                  label: '清理…',
                  danger: true,
                  onPressed: () => _confirmClear(context)))
        ])
      ]);

  Future<void> _confirmClear(BuildContext context) async {
    final dir = PhotoStore.defaultFile().parent;
    final targets = UsageData.files;
    // Typing the words is the confirmation: this deletes saved presets and
    // photo records, and there is no undo.
    const expected = '确认清理';
    final input = TextEditingController();
    String? error;
    final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => WorkspaceDialog(
                    title: const Text('清理使用记录？'),
                    content: SizedBox(
                        width: 470,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          const Text('将删除这些文件：'),
                          const SizedBox(height: 10),
                          for (final name in targets)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('· $name',
                                    style: EditorTypography.hint(ctx)
                                        .copyWith(fontSize: 12))),
                          const SizedBox(height: 12),
                          Text('内置预设和你的照片不会被删除。此操作无法撤销。',
                              style: EditorTypography.hint(ctx)
                                  .copyWith(fontSize: 12)),
                          const SizedBox(height: 16),
                          Text('请输入「$expected」四个字以确认：',
                              style: EditorTypography.label(ctx)),
                          const SizedBox(height: 8),
                          TextField(
                              controller: input,
                              autofocus: true,
                              style: dialogBodyStyle.copyWith(fontSize: 13),
                              decoration: InputDecoration(
                                  isDense: true,
                                  hintText: expected,
                                  errorText: error,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10))),
                          const SizedBox(height: 4),
                          Text('清理后软件会自动关闭并重新打开。',
                              style: EditorTypography.hint(ctx)
                                  .copyWith(fontSize: 11.5))
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () {
                            if (input.text.trim() != expected) {
                              set(() => error = '请完整输入「$expected」');
                              return;
                            }
                            Navigator.pop(ctx, true);
                          },
                          child: const Text('确认清理'))
                    ])));
    WidgetsBinding.instance.addPostFrameCallback((_) => input.dispose());
    if (go != true) return;
    if (UsageData.exportsRunning > 0) {
      onNotice('正在导出照片，请等导出结束后再清理');
      return;
    }
    // Same flow from browse and edit mode: stop writes, wait for the ones in
    // flight, delete, then close so the next start loads the defaults.
    while (true) {
      final result = await UsageData.clearAll(dir);
      if (result.failed.isEmpty) break;
      if (!context.mounted) {
        UsageData.unfreeze();
        return;
      }
      final retry = await showDialog<bool>(
          context: context,
          builder: (ctx) => WorkspaceDialog(
                  title: const Text('有文件没能清理'),
                  content: SizedBox(
                      width: 470,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('这些文件删除失败，可能被其它程序占用：'),
                            const SizedBox(height: 10),
                            for (final item in result.failed)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text('· $item',
                                      style: EditorTypography.hint(ctx)
                                          .copyWith(fontSize: 12))),
                            const SizedBox(height: 10),
                            Text('在清理完成前软件不会再保存任何数据。',
                                style: EditorTypography.hint(ctx)
                                    .copyWith(fontSize: 12))
                          ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('放弃清理')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('重试'))
                  ]));
      if (retry != true) {
        UsageData.unfreeze();
        onNotice('已放弃清理，部分文件可能已被删除');
        return;
      }
    }
    onNotice('清理完成，软件即将重新打开');
    await Future<void>.delayed(const Duration(milliseconds: 800));
    try {
      // Start the new copy first; if that fails the window stays open so the
      // user is never left with nothing.
      await restartApp();
    } catch (e) {
      onNotice('清理完成，但软件没能自动重新打开，请手动关闭后重新打开（$e）');
    }
  }
}

/// Opens a fresh copy of the app and closes this window. Replaceable in tests,
/// which must not launch real processes. `SystemNavigator.pop` does nothing
/// on Windows, so the native window close is used.
Future<void> Function() restartApp = () async {
  await Process.start(Platform.resolvedExecutable, const [],
      mode: ProcessStartMode.detached);
  await DesktopWindow.action('close');
};
// ---------------------------------------------------------------- 高德

class _AmapPage extends StatefulWidget {
  final AppSettings app;
  final ValueChanged<String> onNotice;
  const _AmapPage({required this.app, required this.onNotice});
  @override
  State<_AmapPage> createState() => _AmapPageState();
}

class _AmapPageState extends State<_AmapPage> {
  late final TextEditingController keyController =
      TextEditingController(text: widget.app.amapKey);
  late final TextEditingController secretController =
      TextEditingController(text: widget.app.amapSecret);
  bool showKey = false, showSecret = false;
  bool tutorialOpen = false;
  bool testing = false;
  String? testResult;
  bool testOk = false;

  @override
  void dispose() {
    keyController.dispose();
    secretController.dispose();
    super.dispose();
  }

  void _persist() {
    widget.app.amapKey = keyController.text.trim();
    widget.app.amapSecret = secretController.text.trim();
    widget.app.changed();
  }

  Future<void> _test() async {
    _persist();
    if (widget.app.amapKey.trim().isEmpty) {
      setState(() {
        testOk = false;
        testResult = '请先填入 Key';
      });
      return;
    }
    // The check opens a visible window: the map script needs a laid-out page
    // to run, and a visible page also means a failure is seen rather than
    // guessed at. Results are reported inside that window.
    setState(() {
      testResult = null;
      testOk = false;
    });
    await showMapPage(context,
        app: widget.app, kind: MapPageKind.connectionTest);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Text('这里填的是你自己的高德密钥。软件不附带密钥，需要你到高德开放平台免费申请。',
          style: EditorTypography.hint(context)
              .copyWith(fontSize: 12, height: 1.7)),
      const SizedBox(height: 16),
      _Field(
          label: '高德地图 Key',
          controller: keyController,
          obscure: !showKey,
          onToggle: () => setState(() => showKey = !showKey),
          hint: '32 位字符，在控制台的 Key 列表里',
          onChanged: (_) => _persist()),
      const SizedBox(height: 14),
      _Field(
          label: '安全密钥',
          controller: secretController,
          obscure: !showSecret,
          onToggle: () => setState(() => showSecret = !showSecret),
          hint: '和 Key 在同一个页面，申请时一起生成',
          onChanged: (_) => _persist()),
      const SizedBox(height: 16),
      Row(children: [
        SizedBox(
            height: 38,
            child: FilledButton(
                style: FilledButton.styleFrom(
                    textStyle: dialogActionStyle,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6))),
                onPressed: testing ? null : _test,
                child: Text(testing ? '正在连接…' : '测试连接'))),
        const SizedBox(width: 6),
        TextButton(
            onPressed: () => setState(() => tutorialOpen = !tutorialOpen),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('获取教程', style: const TextStyle(fontSize: 12.5)),
              const SizedBox(width: 4),
              Icon(tutorialOpen ? Icons.expand_less : Icons.expand_more,
                  size: 16)
            ]))
      ]),
      if (testResult != null) ...[
        const SizedBox(height: 10),
        Row(children: [
          Icon(testOk ? Icons.check_circle_outline : Icons.error_outline,
              size: 15,
              color: testOk ? const Color(0xff7fae74) : scheme.error),
          const SizedBox(width: 7),
          Expanded(
              child: Text(testResult!,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: testOk ? const Color(0xff7fae74) : scheme.error)))
        ])
      ],
      if (tutorialOpen) ...[const SizedBox(height: 16), const AmapKeyTutorial()],
      const SizedBox(height: 20),
      _section('地点自动填写', [
        ListenableBuilder(
            listenable: widget.app,
            builder: (context, _) => _Row(
                title: '有坐标时自动填地点',
                detail: '照片带 GPS 时，自动换成地名。只有当前预设用到了地点组件才查询，避免浪费调用次数',
                trailing: Switch(
                    value: widget.app.autoFillPlace,
                    onChanged: (v) {
                      widget.app.autoFillPlace = v;
                      widget.app.changed();
                    })))
      ])
    ]);
  }
}

// ---------------------------------------------------------------- 关于

class _AboutPage extends StatefulWidget {
  const _AboutPage();
  @override
  State<_AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<_AboutPage> {
  bool shortcutsOpen = false;
  late final Future<String> version = _readVersion();

  static Future<String> _readVersion() async {
    try {
      // Read from the executable's own version resource, so a copied or
      // zipped build still shows the right number.
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) return info.version;
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      const SizedBox(height: 8),
      ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset('assets/branding/lumacraft-icon-1024.png',
              width: 64, height: 64, filterQuality: FilterQuality.high)),
      const SizedBox(height: 14),
      Text('框印工坊',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: .3,
              color: scheme.onSurface)),
      const SizedBox(height: 4),
      Text('LumaCraft',
          style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.4,
              color: scheme.onSurface
                  .withValues(alpha: EditorTypography.dimOpacity))),
      const SizedBox(height: 10),
      FutureBuilder<String>(
          future: version,
          builder: (context, snap) => Text(
              snap.hasData && snap.data!.isNotEmpty ? '版本 ${snap.data} Beta' : '版本未知',
              style: EditorTypography.hint(context).copyWith(fontSize: 12))),
      const SizedBox(height: 18),
      _section('关于本软件', [
        const _Row(
            title: '免费 · 离线',
            detail: '照片只在本机处理，不上传；导出时默认移除 GPS 定位信息'),
        _Row(
            title: 'GitHub 仓库',
            detail: '源代码与更新记录',
            trailing: _SmallButton(
                label: '打开',
                onPressed: () => launchUrl(
                    Uri.parse('https://github.com/EnderBull/LumaCraft'),
                    mode: LaunchMode.externalApplication)))
      ]),
      const SizedBox(height: 18),
      _section('快捷键', [
        InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => setState(() => shortcutsOpen = !shortcutsOpen),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child:
                    Row(children: [
                  Text('查看全部快捷键',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface)),
                  const Spacer(),
                  Icon(shortcutsOpen ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: scheme.onSurface.withValues(alpha: .5))
                ]))),
        if (shortcutsOpen) ...[const SizedBox(height: 10), _shortcutList()]
      ])
    ]);
  }

  Widget _shortcutList() {
    final scheme = Theme.of(context).colorScheme;
    Widget group(String title, List<(String, String)> items) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .4,
                  color: scheme.primary)),
          const SizedBox(height: 7),
          for (final entry in items)
            Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(children: [
                  SizedBox(
                      width: 132,
                      child: Text(entry.$1,
                          style: TextStyle(
                              fontFamily: 'Consolas',
                              fontFamilyFallback: const ['Courier New'],
                              fontSize: 11.5,
                              color: scheme.onSurface.withValues(alpha: .9)))),
                  Expanded(
                      child: Text(entry.$2,
                          style: EditorTypography.hint(context)
                              .copyWith(fontSize: 11.5)))
                ]))
        ]));
    return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: .035),
            borderRadius: BorderRadius.circular(9)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          group('浏览模式', const [
            ('← →', '上一张 / 下一张'),
            ('Ctrl + A', '全选照片'),
            ('Ctrl + D', '取消选择'),
            ('空格 + 拖动', '平移画布'),
            ('Alt + 滚轮', '缩放画布'),
          ]),
          group('编辑模式 · 组件', const [
            ('← → ↑ ↓', '移动选中组件'),
            ('Shift + 方向键', '快速移动，每次 10 像素'),
            ('Ctrl + Z', '撤销'),
            ('Ctrl + Shift + Z', '重做'),
            ('Ctrl + A', '全选组件'),
            ('Ctrl + D', '取消选择'),
            ('Ctrl + J', '复制选中组件'),
            ('Ctrl + G', '编组'),
            ('Ctrl + Shift + G', '取消编组'),
            ('Delete', '删除选中组件'),
            ('Esc', '取消操作 / 结束输入'),
            ('Enter', '完成输入'),
            ('Ctrl + Enter', '换行'),
          ]),
          group('编辑模式 · 照片', const [
            ('← →', '切换上一张 / 下一张照片'),
            ('Shift + 方向键', '连选照片'),
            ('Ctrl + 点击', '增减单张'),
          ]),
          group('数值输入框', const [
            ('双击', '恢复默认值'),
            ('左右拖动', '连续调节数值'),
            ('Shift + 拖动', '10 倍步进'),
            ('Alt + 拖动', '0.1 倍微调'),
          ])
        ]));
  }
}

/// Reads the version from pubspec next to the executable's project.
class FilePlatform {
  static File readVersionFile() {
    var dir = File(Platform.resolvedExecutable).parent;
    while (dir.parent.path != dir.path) {
      final candidate = File('${dir.path}/pubspec.yaml');
      if (candidate.existsSync()) return candidate;
      dir = dir.parent;
    }
    return File('${File(Platform.resolvedExecutable).parent.path}/pubspec.yaml');
  }
}

// ---------------------------------------------------------------- 小组件

Widget _section(String title, List<Widget> rows) {
  return Builder(builder: (context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .3,
                  color: scheme.onSurface.withValues(alpha: .75)))),
      Container(
          decoration: BoxDecoration(
              color: scheme.onSurface.withValues(
                  alpha: scheme.brightness == Brightness.dark ? .045 : .035),
              borderRadius: BorderRadius.circular(9)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                    height: 1,
                    color: scheme.onSurface.withValues(alpha: .055)),
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: rows[i])
            ]
          ]))
    ]);
  });
}

class _Row extends StatelessWidget {
  final String title, detail;
  final Widget? trailing;
  const _Row({required this.title, required this.detail, this.trailing});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface)),
            const SizedBox(height: 3),
            Text(detail,
                style: EditorTypography.hint(context)
                    .copyWith(fontSize: 11.5, height: 1.5))
          ])),
      if (trailing != null) ...[const SizedBox(width: 14), trailing!]
    ]);
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool danger;
  const _SmallButton(
      {required this.label, this.onPressed, this.danger = false});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
        height: 32,
        child: TextButton(
            style: TextButton.styleFrom(
                foregroundColor: danger ? scheme.error : scheme.onSurface,
                backgroundColor: scheme.surface,
                textStyle: dialogActionStyle.copyWith(fontSize: 12),
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(
                        color: scheme.onSurface.withValues(alpha: .09)))),
            onPressed: onPressed,
            child: Text(label)));
  }
}

class _Field extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final ValueChanged<String>? onChanged;
  const _Field(
      {required this.label,
      required this.hint,
      required this.controller,
      required this.obscure,
      required this.onToggle,
      this.onChanged});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.only(bottom: 7, left: 2),
          child: Text(label, style: EditorTypography.label(context))),
      Container(
          height: 40,
          decoration: BoxDecoration(
              color: Theme.of(context).inputDecorationTheme.fillColor,
              borderRadius: BorderRadius.circular(6)),
          child: Row(children: [
            Expanded(
                child: TextField(
                    controller: controller,
                    obscureText: obscure,
                    onChanged: onChanged,
                    style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontFamilyFallback: ['Courier New', 'monospace'],
                        fontSize: 12.5,
                        letterSpacing: .3),
                    decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: TextStyle(
                            fontFamily: 'Microsoft YaHei UI',
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: .32)),
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12)))),
            IconButton(
                padding: EdgeInsets.zero,
                tooltip: obscure ? '显示' : '隐藏',
                onPressed: onToggle,
                icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 17,
                    color: scheme.onSurface.withValues(alpha: .45)))
          ]))
    ]);
  }
}
