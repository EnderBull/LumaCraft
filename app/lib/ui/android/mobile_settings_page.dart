import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_icons.dart';
import 'alpha_sheets.dart';
import 'alpha_workspace.dart';
import 'mobile_photo_info_page.dart';

class MobileSettingsPage extends StatefulWidget {
  const MobileSettingsPage({
    super.key,
    required this.appearance,
    required this.setAppearance,
    required this.workspace,
  });

  final ThemeMode appearance;
  final Future<bool> Function(ThemeMode) setAppearance;
  final AlphaWorkspace workspace;

  @override
  State<MobileSettingsPage> createState() => _MobileSettingsPageState();
}

class _MobileSettingsPageState extends State<MobileSettingsPage> {
  late ThemeMode _appearance = widget.appearance;
  late final _version = PackageInfo.fromPlatform();
  bool _savingAppearance = false;

  void _notice(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setAppearance(ThemeMode mode) async {
    if (_savingAppearance || _appearance == mode) return;
    setState(() => _savingAppearance = true);
    final saved = await widget.setAppearance(mode);
    if (!mounted) return;
    setState(() {
      _savingAppearance = false;
      if (saved) _appearance = mode;
    });
    if (!saved) _notice('外观设置保存失败，请重试。');
  }

  Widget _heading(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _section(List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );

  Widget _general() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading('外观'),
          _section([
            const ListTile(
                leading: AppIcon(WorkspaceIcon.moon),
                title: Text('显示模式'),
                subtitle: Text('选择浅色、深色或跟随系统')),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
                  ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
                ],
                selected: {_appearance},
                onSelectionChanged: _savingAppearance
                    ? null
                    : (selected) => _setAppearance(selected.single),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          _heading('数据与文件'),
          _section([
            ListenableBuilder(
              listenable: widget.workspace,
              builder: (context, _) => ListTile(
                leading: const AppIcon(WorkspaceIcon.presetLibrary),
                title: const Text('管理预设'),
                subtitle: const Text('整理预设、导入或导出预设文件'),
                trailing: const Icon(Icons.chevron_right),
                enabled:
                    widget.workspace.libraryReady && !widget.workspace.busy,
                onTap: () =>
                    showAlphaPresets(context, widget.workspace, manage: true),
              ),
            ),
            ListTile(
              leading: const AppIcon(WorkspaceIcon.photoAdd),
              title: const Text('重新加载缩略图'),
              subtitle: const Text('释放内存中的缩略图缓存'),
              onTap: () {
                PaintingBinding.instance.imageCache.clear();
                _notice('已释放缩略图缓存');
              },
            ),
          ]),
        ],
      );

  Widget _about() => Column(children: [
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset('assets/branding/lumacraft-icon-1024.png',
              width: 72, height: 72, cacheWidth: 216),
        ),
        const SizedBox(height: 12),
        Text('框印工坊', style: Theme.of(context).textTheme.titleLarge),
        const Text('LumaCraft'),
        const SizedBox(height: 8),
        FutureBuilder<PackageInfo>(
          future: _version,
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text('版本未知');
            final version = snapshot.data?.version;
            return version == null
                ? const SizedBox.shrink()
                : Text('版本 ' + version);
          },
        ),
        const SizedBox(height: 22),
        _section([
          const ListTile(
              title: Text('免费 · 本地处理'),
              subtitle: Text('照片在设备上处理，导出默认移除 GPS 定位信息。')),
          ListTile(
            title: const Text('GitHub 仓库'),
            subtitle: const Text('源代码与更新记录'),
            trailing: const Icon(Icons.open_in_new, size: 19),
            onTap: () async {
              final opened = await launchUrl(
                Uri.parse('https://github.com/EnderBull/LumaCraft'),
                mode: LaunchMode.externalApplication,
              );
              if (!opened && mounted) _notice('无法打开 GitHub 仓库。');
            },
          ),
        ]),
      ]);

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
              title: const Text('设置'),
              bottom: const TabBar(tabs: [
                Tab(text: '通用'),
                Tab(text: '高德 API'),
                Tab(text: '关于'),
              ])),
          body: SafeArea(
            child: TabBarView(children: [
              for (final panel in [
                _general(),
                const MobileAmapSettingsPane(),
                _about()
              ])
                ListView(padding: const EdgeInsets.all(16), children: [panel]),
            ]),
          ),
        ),
      );
}
