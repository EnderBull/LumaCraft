import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../editor/builtin_library.dart';
import '../editor/preset_store.dart';
import '../editor/style_document.dart';
import 'editor/prototype_controls.dart';
import 'preset_thumbnail.dart';
import 'workspace_dialog.dart';
import 'builtin_folder_select.dart';

/// A production tool, omitted from release navigation unless AUTHORING is enabled.
class BuiltinManager extends StatefulWidget {
  final PresetStore store;
  final Widget Function(PresetEntry) preview;
  const BuiltinManager({super.key, required this.store, required this.preview});
  @override
  State<BuiltinManager> createState() => _BuiltinManagerState();
}

class _BuiltinManagerState extends State<BuiltinManager> {
  final scroll = ScrollController();
  String group = 'all', selected = '', message = '';
  bool busy = false;
  PresetStore get store => widget.store;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = '';
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => message = '操作失败：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<(String, String)?> form(String title, String name, String folder,
      {bool groupOnly = false}) async {
    final input = TextEditingController(text: name);
    String? error;
    final result = await showDialog<(String, String)>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => WorkspaceDialog(
                    title: Text(title),
                    content: SizedBox(
                        width: 360,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              WorkspaceTextField(
                                  label: groupOnly ? '分组名称' : '预设名称',
                                  controller: input,
                                  error: error,
                                  maxLength: groupOnly ? 100 : 200,
                                  autofocus: true),
                              if (!groupOnly) ...[
                                const SizedBox(height: 16),
                                Text('所属分组',
                                    style: EditorTypography.label(ctx)),
                                const SizedBox(height: 8),
                                BuiltinFolderSelect(
                                    store: store,
                                    value: folder,
                                    onChanged: (v) => set(() => folder = v))
                              ]
                            ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () {
                            if (input.text.trim().isEmpty) {
                              set(() => error = '请输入名称');
                              return;
                            }
                            Navigator.pop(ctx, (input.text.trim(), folder));
                          },
                          child: const Text('确定'))
                    ])));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      input.dispose();
    });
    return result;
  }

  Future<void> newGroup() async {
    final value = await form('新建内置分组', '', '', groupOnly: true);
    if (value == null) return;
    final id = 'g-${newObjectId()}';
    await store.writeBuiltinLibrary(BuiltinLibrary(
        [...store.builtinLibrary.folders, BuiltinFolder(id, value.$1)],
        store.builtinLibrary.entries));
    group = id;
  }

  Future<void> renameGroup() async {
    final f =
        store.builtinLibrary.folders.where((f) => f.id == group).firstOrNull;
    if (f == null) return;
    final value = await form('重命名内置分组', f.name, '', groupOnly: true);
    if (value == null) return;
    await store.writeBuiltinLibrary(BuiltinLibrary([
      for (final g in store.builtinLibrary.folders)
        g.id == f.id ? BuiltinFolder(g.id, value.$1) : g
    ], store.builtinLibrary.entries));
  }

  Future<void> create() async {
    final folder =
        group == 'all' ? store.builtinLibrary.folders.first.id : group;
    final value = await form('新建内置预设', '新的内置预设', folder);
    if (value == null) return;
    final id = 'p-${newObjectId()}';
    await store.saveBuiltin(id, StyleDocument(name: value.$1), value.$2);
    selected = id;
  }

  Future<void> rename(BuiltinEntry p) async {
    final value = await form('调整内置预设', p.style.name, p.folder);
    if (value == null) return;
    await store.saveBuiltin(p.id, p.style.copy()..name = value.$1, value.$2);
  }

  Future<bool> confirm(String title, String text) async =>
      await showDialog<bool>(
          context: context,
          builder: (ctx) => WorkspaceDialog(
                  title: Text(title),
                  content: SizedBox(width: 430, child: Text(text)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('确定'))
                  ])) ==
      true;
  Future<void> restore(BuiltinEntry p) async {
    if (await confirm(
        '恢复默认', '将“${p.style.name}”恢复为此版本的默认样式，本机对此预设的维护修改将被替换。'))
      await store.restoreBuiltin(p.id);
  }

  Future<void> restoreAll() async {
    if (await confirm('全部恢复默认',
        '将整个内置库恢复为此版本的默认状态：所有内置预设的维护修改都会被替换，你在本机新建的内置预设和分组会被删除。此操作不可撤销。')) {
      await store.restoreAllBuiltins();
      group = 'all';
      selected = store.builtinLibrary.entries.first.id;
      if (mounted) setState(() => message = '已全部恢复默认。');
    }
  }

  Future<void> exportLibrary() async {
    final location = await getSaveLocation(
        suggestedName: 'lumacraft-builtins.json',
        acceptedTypeGroups: [
          const XTypeGroup(label: '内置预设库', extensions: ['json'])
        ]);
    if (location == null) return;
    final path = location.path;
    if (File(path).absolute.path.toLowerCase() ==
        store.builtinWorkingFile.absolute.path.toLowerCase())
      throw StateError('请选择工作库之外的导出位置');
    await File(path).writeAsString(store.builtinLibrary.encode(), flush: true);
    if (mounted) setState(() => message = '内置库已导出，可用于下一次封包。');
  }

  Future<void> importLibrary() async {
    final file = await openFile(acceptedTypeGroups: [
      const XTypeGroup(label: '内置预设库', extensions: ['json'])
    ]);
    if (file == null) return;
    if (await File(file.path).length() > 64 * 1024 * 1024)
      throw const FormatException('内置库超过64MB');
    final incoming = BuiltinLibrary.decode(await file.readAsString());
    if (!mounted ||
        !await confirm('载入内置预设库',
            '包含${incoming.entries.length}个预设、${incoming.folders.length}个分组。载入将替换本机的内置工作库，用户预设不受影响。'))
      return;
    await store.writeBuiltinLibrary(incoming);
    selected = '';
    group = 'all';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final items = store.builtinLibrary.entries
            .where((e) => group == 'all' || e.folder == group)
            .toList();
        final current = store.builtinLibrary.entries
            .where((e) => e.id == selected)
            .firstOrNull;
        final neutral = TextButton.styleFrom(
            backgroundColor: scheme.surfaceContainerHighest,
            foregroundColor: scheme.onSurface,
            minimumSize: const Size(0, 38),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)));
        return Dialog(
            clipBehavior: Clip.antiAlias,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: DefaultTextStyle(
                style: dialogBodyStyle.copyWith(color: scheme.onSurface),
                child: SizedBox(
                    width: 760,
                    height: (MediaQuery.sizeOf(context).height - 80)
                        .clamp(360, 700),
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                const PrototypeIcon('manageFolders', size: 26),
                                const SizedBox(width: 12),
                                const Expanded(
                                    child: Text('内置预设维护',
                                        style: dialogTitleStyle)),
                                IconButton(
                                    tooltip: '关闭',
                                    onPressed: busy
                                        ? null
                                        : () => Navigator.pop(context),
                                    icon: const PrototypeIcon('close',
                                        ui: true, size: 20))
                              ]),
                              const SizedBox(height: 6),
                              Text('制作版 · 保存到本机工作库，确认后导出用于发行封包。',
                                  style: EditorTypography.hint(context)),
                              const SizedBox(height: 20),
                              Row(children: [
                                Expanded(
                                    child: BuiltinFolderSelect(
                                        store: store,
                                        value: group,
                                        includeAll: true,
                                        onChanged: (v) => setState(() {
                                              group = v;
                                              selected = '';
                                            }))),
                                const SizedBox(width: 8),
                                TextButton(
                                    style: neutral,
                                    onPressed:
                                        busy ? null : () => run(newGroup),
                                    child: const Text('新建分组')),
                                const SizedBox(width: 8),
                                TextButton(
                                    style: neutral,
                                    onPressed: busy || group == 'all'
                                        ? null
                                        : () => run(renameGroup),
                                    child: const Text('重命名分组'))
                              ]),
                              const SizedBox(height: 14),
                              Expanded(
                                  child: items.isEmpty
                                      ? Center(
                                          child: Text('此分组还没有预设，可从空白样式开始创建。',
                                              style: EditorTypography.hint(
                                                  context)))
                                      : Scrollbar(
                                          controller: scroll,
                                          thumbVisibility: true,
                                          child: GridView.builder(
                                              controller: scroll,
                                              gridDelegate:
                                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                                      crossAxisCount: 3,
                                                      mainAxisExtent: 174,
                                                      crossAxisSpacing: 12,
                                                      mainAxisSpacing: 12),
                                              itemCount: items.length,
                                              itemBuilder: (ctx, i) {
                                                final p = items[i];
                                                return InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            7),
                                                    onTap: busy
                                                        ? null
                                                        : () => setState(() =>
                                                            selected = p.id),
                                                    onDoubleTap: busy
                                                        ? null
                                                        : () => Navigator.pop(
                                                            context, p.id),
                                                    child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(7),
                                                        decoration: BoxDecoration(
                                                            color: scheme
                                                                .surfaceContainerHighest
                                                                .withValues(
                                                                    alpha: .45),
                                                            borderRadius:
                                                                BorderRadius.circular(7),
                                                            border: Border.all(color: selected == p.id ? scheme.primary : Colors.transparent, width: 1.5)),
                                                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                                          Expanded(
                                                              child: PresetThumbnail(
                                                                  style:
                                                                      p.style,
                                                                  child: widget.preview(PresetEntry(
                                                                      p.id,
                                                                      p.style,
                                                                      builtIn:
                                                                          true)))),
                                                          const SizedBox(
                                                              height: 8),
                                                          Text(p.style.name,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style:
                                                                  dialogActionStyle),
                                                          const SizedBox(
                                                              height: 3),
                                                          Text(
                                                              store
                                                                  .builtinLibrary
                                                                  .folders
                                                                  .firstWhere((f) =>
                                                                      f.id ==
                                                                      p.folder)
                                                                  .name,
                                                              style: EditorTypography
                                                                  .hint(
                                                                      context))
                                                        ])));
                                              }))),
                              const SizedBox(height: 12),
                              if (message.isNotEmpty) ...[
                                Text(message,
                                    style: EditorTypography.hint(context)),
                                const SizedBox(height: 10)
                              ],
                              Row(children: [
                                TextButton(
                                    style: neutral,
                                    onPressed: busy ? null : () => run(create),
                                    child: const Text('新建预设')),
                                const SizedBox(width: 8),
                                TextButton(
                                    style: neutral,
                                    onPressed: busy || current == null
                                        ? null
                                        : () => run(() => rename(current)),
                                    child: const Text('名称与分组')),
                                const SizedBox(width: 8),
                                TextButton(
                                    style: neutral,
                                    onPressed: busy ||
                                            current == null ||
                                            !store
                                                .hasBuiltinOriginal(current.id)
                                        ? null
                                        : () => run(() => restore(current)),
                                    child: const Text('恢复默认')),
                                const Spacer(),
                                FilledButton(
                                    onPressed: busy || current == null
                                        ? null
                                        : () =>
                                            Navigator.pop(context, current.id),
                                    child: const Text('编辑样式'))
                              ]),
                              const SizedBox(height: 14),
                              Divider(
                                  color:
                                      scheme.onSurface.withValues(alpha: .08)),
                              const SizedBox(height: 10),
                              Row(children: [
                                Text(
                                    '${store.builtinLibrary.entries.length} 个内置预设',
                                    style: EditorTypography.hint(context)),
                                const Spacer(),
                                TextButton(
                                    style: neutral,
                                    onPressed:
                                        busy ? null : () => run(restoreAll),
                                    child: const Text('全部恢复默认')),
                                const SizedBox(width: 8),
                                TextButton(
                                    style: neutral,
                                    onPressed:
                                        busy ? null : () => run(importLibrary),
                                    child: const Text('载入内置库')),
                                const SizedBox(width: 8),
                                TextButton(
                                    style: neutral,
                                    onPressed:
                                        busy ? null : () => run(exportLibrary),
                                    child: const Text('导出内置库'))
                              ])
                            ])))));
      });
}
