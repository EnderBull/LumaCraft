import 'package:flutter/material.dart';
import '../editor/preset_store.dart';
import 'editor/prototype_controls.dart';
import 'workspace_dialog.dart';
import 'folder_select.dart';
import 'preset_thumbnail.dart';

class FolderManager extends StatefulWidget {
  final PresetStore store;
  final Widget Function(PresetEntry) preview;
  final Future<void> Function(PresetFolder) onRename, onDelete;
  final Future<void> Function(List<PresetEntry>) onExport;
  const FolderManager(
      {super.key,
      required this.store,
      required this.preview,
      required this.onRename,
      required this.onDelete,
      required this.onExport});
  @override
  State<FolderManager> createState() => _FolderManagerState();
}

class _FolderManagerState extends State<FolderManager> {
  final overviewScroll = ScrollController(), detailScroll = ScrollController();
  String? folderId;
  bool busy = false;
  List<PresetEntry> members(String id) =>
      widget.store.entries.where((e) => !e.builtIn && e.folder == id).toList();
  Future<void> action(Future<void> Function() callback) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await callback();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    overviewScroll.dispose();
    detailScroll.dispose();
    super.dispose();
  }

  Widget thumbnail(PresetEntry e) => Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
          color: Theme.of(context).inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(6)),
      child: PresetThumbnail(style: e.style, child: widget.preview(e)));
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final s = Theme.of(context).colorScheme;
        final folder =
            widget.store.folders.where((f) => f.id == folderId).firstOrNull;
        final items = folder == null ? <PresetEntry>[] : members(folder.id);
        return Dialog(
            clipBehavior: Clip.antiAlias,
            backgroundColor: s.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: DefaultTextStyle(
                style: dialogBodyStyle.copyWith(color: s.onSurface),
                child: SizedBox(
                    width: 760,
                    height: (MediaQuery.sizeOf(context).height - 100)
                        .clamp(300, 650),
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                if (folder != null) ...[
                                  IconButton(
                                      tooltip: '返回分组列表',
                                      onPressed: busy
                                          ? null
                                          : () =>
                                              setState(() => folderId = null),
                                      icon: const Icon(Icons.arrow_back_rounded,
                                          size: 21)),
                                  const SizedBox(width: 6)
                                ],
                                const PrototypeIcon('manageFolders', size: 25),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(folder?.name ?? '管理分组',
                                          style: dialogTitleStyle),
                                      const SizedBox(height: 4),
                                      Text(
                                          folder == null
                                              ? '${widget.store.folders.length} 个分组 · ${widget.store.presets.length} 个用户预设'
                                              : '${items.length} 个预设',
                                          style: EditorTypography.hint(context))
                                    ])),
                                IconButton(
                                    tooltip: '关闭分组管理',
                                    onPressed: () => Navigator.pop(context),
                                    icon: const PrototypeIcon('close',
                                        ui: true, size: 20))
                              ]),
                              const SizedBox(height: 20),
                              if (folder == null)
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                        onPressed: busy
                                            ? null
                                            : () => action(() async {
                                                  await createPresetFolder(
                                                      context, widget.store);
                                                }),
                                        icon: const PrototypeIcon('plus',
                                            ui: true, size: 17),
                                        label: const Text('新建分组'))),
                              if (folder == null) const SizedBox(height: 12),
                              Expanded(
                                  child: folder == null
                                      ? widget.store.folders.isEmpty
                                          ? const Center(
                                              child:
                                                  Text('还没有分组，点击“新建分组”开始整理预设。'))
                                          : Scrollbar(
                                              controller: overviewScroll,
                                              thumbVisibility: true,
                                              child: GridView.builder(
                                                  controller: overviewScroll,
                                                  gridDelegate:
                                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                                          crossAxisCount: 2,
                                                          mainAxisExtent: 196,
                                                          crossAxisSpacing: 16,
                                                          mainAxisSpacing: 16),
                                                  itemCount: widget
                                                      .store.folders.length,
                                                  itemBuilder: (ctx, i) {
                                                    final f = widget
                                                            .store.folders[i],
                                                        all = members(f.id);
                                                    return Material(
                                                        color: s
                                                            .surfaceContainerHighest
                                                            .withValues(
                                                                alpha: .55),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(9),
                                                        child: InkWell(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                    9),
                                                            onTap: busy
                                                                ? null
                                                                : () => setState(
                                                                    () => folderId =
                                                                        f.id),
                                                            child: Padding(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                        14),
                                                                child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .stretch,
                                                                    children: [
                                                                      Row(
                                                                          children: [
                                                                            const PrototypeIcon('group',
                                                                                size: 20),
                                                                            const SizedBox(width: 8),
                                                                            Expanded(child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: dialogBodyStyle.copyWith(fontWeight: FontWeight.w600))),
                                                                            Text('${all.length}',
                                                                                style: EditorTypography.hint(ctx))
                                                                          ]),
                                                                      const SizedBox(
                                                                          height:
                                                                              12),
                                                                      Expanded(
                                                                          child: all.isEmpty
                                                                              ? Center(child: Text('空分组', style: EditorTypography.hint(ctx)))
                                                                              : Row(children: [
                                                                                  for (final e in all.take(3)) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: thumbnail(e)))
                                                                                ])),
                                                                      const SizedBox(
                                                                          height:
                                                                              10),
                                                                      Text(all.isEmpty ? '暂无预设' : all.take(3).map((e) => e.style.name).join(' · ') + (all.length > 3 ? ' …' : ''),
                                                                          maxLines:
                                                                              1,
                                                                          overflow: TextOverflow
                                                                              .ellipsis,
                                                                          style:
                                                                              EditorTypography.hint(ctx))
                                                                    ]))));
                                                  }))
                                      : items.isEmpty
                                          ? const Center(
                                              child: Text('这个分组还没有预设。'))
                                          : Scrollbar(
                                              controller: detailScroll,
                                              thumbVisibility: true,
                                              child: GridView.builder(
                                                  controller: detailScroll,
                                                  gridDelegate:
                                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                                          crossAxisCount: 3,
                                                          mainAxisExtent: 155,
                                                          crossAxisSpacing: 14,
                                                          mainAxisSpacing: 14),
                                                  itemCount: items.length,
                                                  itemBuilder: (ctx, i) =>
                                                      Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .stretch,
                                                          children: [
                                                            Expanded(
                                                                child: thumbnail(
                                                                    items[i])),
                                                            const SizedBox(
                                                                height: 8),
                                                            Text(
                                                                items[i]
                                                                    .style
                                                                    .name,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis)
                                                          ])))),
                              if (folder != null) ...[
                                const SizedBox(height: 18),
                                Row(children: [
                                  WorkspaceActionButton(
                                    label: '重命名分组',
                                    onPressed: busy
                                        ? null
                                        : () => action(
                                            () => widget.onRename(folder)),
                                  ),
                                  const SizedBox(width: 8),
                                  WorkspaceActionButton(
                                    label: '导出分组',
                                    onPressed: busy || items.isEmpty
                                        ? null
                                        : () => action(
                                            () => widget.onExport(items)),
                                  ),
                                  const Spacer(),
                                  WorkspaceActionButton(
                                    label: '删除分组',
                                    danger: true,
                                    onPressed: busy
                                        ? null
                                        : () => action(() async {
                                              await widget.onDelete(folder);
                                              if (mounted &&
                                                  !widget.store.folders.any(
                                                      (f) => f.id == folder.id))
                                                setState(() => folderId = null);
                                            }),
                                  )
                                ])
                              ],
                            ])))));
      });
}
