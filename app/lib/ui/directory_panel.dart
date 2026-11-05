import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../directory_browser.dart';
import 'app_icons.dart';
import 'smooth_scroll.dart';

class DirectoryPanel extends StatefulWidget {
  final String? currentPath;
  final Set<String>? selectedPaths;
  final ValueChanged<Set<String>>? onSelectMany;
  static final _focusNodes = <FocusNode>{};
  static bool get keyboardActive => _focusNodes.any((n) => n.hasFocus);
  final bool includeChildren, enabled, scanning;
  final int count;
  final ValueChanged<String> onSelect;
  final ValueChanged<bool> onRecursive;
  final VoidCallback onChooseDirectory;
  const DirectoryPanel(
      {super.key,
      required this.currentPath,
      this.selectedPaths,
      this.onSelectMany,
      required this.includeChildren,
      required this.enabled,
      required this.scanning,
      required this.count,
      required this.onSelect,
      required this.onRecursive,
      required this.onChooseDirectory});
  @override
  State<DirectoryPanel> createState() => _DirectoryPanelState();
}

class _DirectoryPanelState extends State<DirectoryPanel> {
  final focus = FocusNode();
  String? anchor;
  List<String> visible = [];
  final directoryScroll = SmoothScrollController();
  List<String> roots = [];
  final expanded = <String>{};
  final children = <String, List<String>>{};
  final loading = <String>{};
  final errors = <String, String>{};
  String? rootError;
  @override
  void initState() {
    super.initState();
    DirectoryPanel._focusNodes.add(focus);
    try {
      roots = diskRoots();
    } catch (e) {
      rootError = '$e';
    }
    reveal();
  }

  @override
  void dispose() {
    DirectoryPanel._focusNodes.remove(focus);
    focus.dispose();
    directoryScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DirectoryPanel old) {
    super.didUpdateWidget(old);
    if (widget.currentPath != old.currentPath) reveal();
  }

  void reveal() {
    final path = widget.currentPath;
    if (path == null) return;
    var parent = Directory(path).parent;
    while (true) {
      expanded.add(parent.path);
      load(parent.path);
      final next = parent.parent;
      if (next.path == parent.path) break;
      parent = next;
    }
  }

  Future<void> load(String path) async {
    if (loading.contains(path) || children.containsKey(path)) return;
    loading.add(path);
    errors.remove(path);
    try {
      children[path] = await childDirectories(path);
    } catch (e) {
      errors[path] = '无法读取目录';
    } finally {
      loading.remove(path);
      if (mounted) setState(() {});
    }
  }

  Widget row(String path, int depth, bool root) {
    final active = widget.selectedPaths
            ?.any((p) => p.toLowerCase() == path.toLowerCase()) ??
        (widget.currentPath?.toLowerCase() == path.toLowerCase());
    final open = expanded.contains(path);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        child: Material(
            color: active
                ? scheme.primary.withValues(alpha: .12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
                height: 33,
                child: Padding(
                    padding:
                        EdgeInsets.only(left: (depth * 10.0).clamp(0.0, 48.0)),
                    child: Row(children: [
                      SizedBox(
                          width: 23,
                          child: IconButton(
                              padding: EdgeInsets.zero,
                              tooltip: open ? '收起目录' : '展开目录',
                              iconSize: 16,
                              onPressed: () {
                                setState(() {
                                  if (open) {
                                    expanded.remove(path);
                                  } else {
                                    expanded.add(path);
                                    load(path);
                                  }
                                });
                              },
                              icon: Icon(open
                                  ? Icons.keyboard_arrow_down
                                  : Icons.chevron_right))),
                      Expanded(
                          child: Tooltip(
                              message: path,
                              child: InkWell(
                                  onTap: widget.enabled
                                      ? () {
                                          focus.requestFocus();
                                          if (widget.onSelectMany == null) {
                                            widget.onSelect(path);
                                            return;
                                          }
                                          final selected = {
                                                ...?widget.selectedPaths
                                              },
                                              ctrl = HardwareKeyboard.instance
                                                      .isControlPressed ||
                                                  HardwareKeyboard
                                                      .instance.isMetaPressed;
                                          if (HardwareKeyboard
                                                  .instance.isShiftPressed &&
                                              anchor != null &&
                                              visible.contains(anchor)) {
                                            final a = visible.indexOf(anchor!),
                                                b = visible.indexOf(path);
                                            if (!ctrl) selected.clear();
                                            selected.addAll(visible.sublist(
                                                a < b ? a : b,
                                                (a > b ? a : b) + 1));
                                          } else if (ctrl) {
                                            if (!selected.add(path))
                                              selected.remove(path);
                                            anchor = path;
                                          } else {
                                            selected
                                              ..clear()
                                              ..add(path);
                                            anchor = path;
                                          }
                                          widget.onSelectMany!(selected);
                                        }
                                      : null,
                                  child: Row(children: [
                                    AppIcon(
                                        root
                                            ? WorkspaceIcon.drive
                                            : open
                                                ? WorkspaceIcon.folderOpen
                                                : WorkspaceIcon.folder,
                                        size: 21,
                                        color: active ? scheme.primary : null),
                                    const SizedBox(width: 7),
                                    Expanded(
                                        child: Text(
                                            root ? path : directoryName(path),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: active
                                                    ? scheme.primary
                                                    : null)))
                                  ])))),
                    ])))));
  }

  @override
  Widget build(BuildContext context) {
    final entries = <(String, int, bool)>[];
    void add(List<String> paths, int depth) {
      for (final path in paths) {
        entries.add((path, depth, depth == 0));
        if (expanded.contains(path)) add(children[path] ?? [], depth + 1);
      }
    }

    add(roots, 0);
    visible = entries.map((e) => e.$1).toList();
    return Focus(
        focusNode: focus,
        onKeyEvent: (_, event) {
          if (widget.enabled &&
              widget.onSelectMany != null &&
              event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.keyD &&
              (HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed)) {
            widget.onSelectMany!({});
            anchor = null;
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
              child: Row(children: [
                const Expanded(
                    child: Text('照片来源', style: TextStyle(fontSize: 13))),
                Tooltip(
                    message: '显示当前目录和所有子目录中的照片',
                    child: InkWell(
                        onTap: widget.enabled
                            ? () => widget.onRecursive(!widget.includeChildren)
                            : null,
                        child: Row(children: [
                          SizedBox(
                              width: 30,
                              height: 24,
                              child: FittedBox(
                                  child: Switch(
                                      value: widget.includeChildren,
                                      onChanged: widget.enabled
                                          ? widget.onRecursive
                                          : null))),
                          const SizedBox(width: 4),
                          const Text('含子目录', style: TextStyle(fontSize: 12))
                        ]))),
              ])),
          if (rootError != null)
            Padding(
                padding: const EdgeInsets.all(12),
                child: Text('磁盘读取失败：$rootError')),
          Expanded(
              child: SmoothScroll(
                  controller: directoryScroll,
                  child: Scrollbar(
                      controller: directoryScroll,
                      child: ListView.builder(
                          controller: directoryScroll,
                          itemCount: entries.length,
                          itemBuilder: (ctx, i) {
                            final (path, depth, root) = entries[i];
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  row(path, depth, root),
                                  if (expanded.contains(path) &&
                                      loading.contains(path))
                                    const Padding(
                                        padding: EdgeInsets.only(left: 28),
                                        child: Text('正在读取…',
                                            style: TextStyle(fontSize: 12))),
                                  if (expanded.contains(path) &&
                                      errors.containsKey(path))
                                    TextButton(
                                        onPressed: () => load(path),
                                        child: Text('${errors[path]}，点击重试',
                                            style:
                                                const TextStyle(fontSize: 12))),
                                ]);
                          })))),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前位置',
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).hintColor)),
                    const SizedBox(height: 7),
                    SelectableText(
                        (widget.selectedPaths?.length ?? 0) > 1
                            ? '已选 ${widget.selectedPaths!.length} 个目录\n' +
                                widget.selectedPaths!
                                    .map(directoryName)
                                    .join('、')
                            : widget.currentPath ?? '请选择左侧目录',
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 7),
                    Text(
                        '${widget.includeChildren ? "含子目录" : "仅当前目录"} · ${widget.count} 张${widget.scanning ? " · 扫描中" : ""}',
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).hintColor)),
                    const SizedBox(height: 9),
                    TextButton.icon(
                        onPressed:
                            widget.enabled ? widget.onChooseDirectory : null,
                        icon: const AppIcon(WorkspaceIcon.folderAdd, size: 18),
                        label: const Text('定位文件夹',
                            style: TextStyle(fontSize: 13))),
                  ])),
        ]));
  }
}
