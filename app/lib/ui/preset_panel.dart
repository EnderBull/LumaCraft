import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import '../editor/preset_store.dart';
import '../editor/preset_package.dart';
import '../editor/style_document.dart';
import '../editor/style_render.dart';
import '../workspace_settings.dart';
import 'smooth_scroll.dart';
import 'workspace_dialog.dart';
import 'preset_share_dialog.dart';
import 'folder_select.dart';
import 'folder_manager.dart';
import 'builtin_manager.dart';
import 'preset_thumbnail.dart';
import 'import_preset_dialog.dart';
import 'editor/prototype_controls.dart';
part 'preset_actions.dart';

class PresetPanel extends StatefulWidget {
  final PresetStore store;
  final WorkspaceSettings settings;
  final ui.Image? photo;
  final String? photoPath, activeId;
  final Map<String, String> fields;
  final Future<void> Function(PresetEntry) onApply;
  final VoidCallback? onNew;
  final Future<void> Function(PresetEntry)? onEditBuiltin;
  final bool enabled, canApply;
  final String notice;
  static final _focusNodes = <FocusNode>{};
  static bool get keyboardActive => _focusNodes.any((f) => f.hasFocus);
  const PresetPanel(
      {super.key,
      required this.store,
      required this.settings,
      required this.onApply,
      this.onNew,
      this.onEditBuiltin,
      this.photo,
      this.photoPath,
      this.activeId,
      this.fields = const {},
      this.enabled = true,
      this.canApply = true,
      this.notice = ''});
  @override
  State<PresetPanel> createState() => _PresetPanelState();
}

class _PresetPanelState extends State<PresetPanel> {
  final focus = FocusNode(), scroll = SmoothScrollController();
  final gridKey = GlobalKey();
  late final TextEditingController query;
  bool working = false;
  String message = '';
  Offset? start;
  Rect? marquee;
  Set<String> base = {}, hits = {};
  List<PresetEntry> visible = [];
  double cellWidth = 0, cellHeight = 0;
  bool alignedPreset = false;
  ui.Image? placeholder;
  final previews =
      <String, (StyleDocument, ui.Image?, Map<String, String>, Widget)>{};
  void update(VoidCallback action) {
    if (mounted) setState(action);
  }

  int previousRow = -1;
  void alignPreset() {
    if (alignedPreset ||
        !scroll.hasClients ||
        cellHeight <= 0 ||
        !scroll.position.hasViewportDimension) return;
    final id = store.selection.primary ?? widget.activeId;
    if (id == null) {
      alignedPreset = true;
      return;
    }
    final index = visible.indexWhere((e) => e.id == id);
    if (index < 0) {
      if (store.entries.isNotEmpty) alignedPreset = true;
      return;
    }
    alignedPreset = true;
    final stride = cellHeight + 12;
    final centered =
        (index ~/ 2) * stride - (scroll.position.viewportDimension - cellHeight) / 2;
    scroll.jumpTo(centered.clamp(0, scroll.position.maxScrollExtent));
  }

  void scrolled() {
    if (!scroll.hasClients || cellHeight <= 0) return;
    final row = (scroll.offset / (cellHeight + 12)).floor();
    if (row != previousRow) {
      previousRow = row;
      if (mounted) setState(() {});
    }
  }

  PresetStore get store => widget.store;
  bool get control =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;
  bool get shift => HardwareKeyboard.instance.isShiftPressed;
  bool get usable => widget.enabled && !working;
  @override
  void initState() {
    super.initState();
    query = TextEditingController(text: store.libraryQuery);
    scroll.addListener(scrolled);
    store.addListener(libraryChanged);
    widget.settings.addListener(libraryChanged);
    PresetPanel._focusNodes.add(focus);
    if (store.selection.ids.isEmpty && widget.activeId != null) {
      store.selection.ids.add(widget.activeId!);
      store.selection.primary = widget.activeId;
      store.selection.anchor = widget.activeId;
    }
    makePlaceholder();
  }

  Future<void> makePlaceholder() async {
    final r = ui.PictureRecorder(), c = Canvas(r);
    c.drawRect(
        const Rect.fromLTWH(0, 0, 240, 160),
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, const Offset(240, 160),
              [const Color(0xff6e8c96), const Color(0xffb5c3bc)]));
    final picture = r.endRecording();
    final image = await picture.toImage(240, 160);
    picture.dispose();
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() => placeholder = image);
  }

  void libraryChanged() {
    if (mounted)
      setState(() {
        if (store.libraryFolder != 'all' &&
            store.libraryFolder.isNotEmpty &&
            ![...store.folders, ...store.builtinFolders]
                .any((f) => f.id == store.libraryFolder))
          store.libraryFolder = 'all';
        final all = store.entries.map((e) => e.id).toSet();
        store.selection.ids.removeWhere((id) => !all.contains(id));
        previews.removeWhere((id, _) => !all.contains(id));
      });
  }

  @override
  void dispose() {
    store.removeListener(libraryChanged);
    widget.settings.removeListener(libraryChanged);
    PresetPanel._focusNodes.remove(focus);
    focus.dispose();
    scroll.dispose();
    query.dispose();
    placeholder?.dispose();
    super.dispose();
  }

  List<PresetEntry> get selected =>
      store.entries.where((e) => store.selection.ids.contains(e.id)).toList();
  void filterChanged(VoidCallback change) {
    setState(() {
      change();
      store.selection.clear();
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  bool applying = false;
  String? pendingApply;
  Future<void> applyEntryId(String? id) async {
    if (id == null || !widget.canApply || !usable) return;
    pendingApply = id;
    if (applying) return;
    applying = true;
    try {
      while (mounted && pendingApply != null) {
        final next = pendingApply!;
        pendingApply = null;
        final list = store.entries.where((e) => e.id == next);
        if (list.isEmpty) continue;
        try {
          await widget.onApply(list.first);
        } catch (e) {
          if (mounted) setState(() => message = '应用失败：$e');
        }
      }
    } finally {
      applying = false;
    }
  }

  void choose(PresetEntry e) {
    if (!usable) return;
    focus.requestFocus();
    final id = store.selection.choose(e.id, visible.map((e) => e.id).toList(),
        control: control, shift: shift);
    setState(() {});
    unawaited(applyEntryId(id));
  }

  Widget preview(PresetEntry e) {
    final photo = widget.photo ?? placeholder;
    if (photo == null)
      return const Center(
          child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)));
    final old = previews[e.id];
    if (old != null &&
        identical(old.$1, e.style) &&
        identical(old.$2, photo) &&
        identical(old.$3, widget.fields)) return old.$4;
    final w = RepaintBoundary(
        child: StylePreview(
            photo: photo,
            photoPath: widget.photoPath,
            document: e.style,
            fields: widget.fields));
    previews[e.id] = (e.style, photo, widget.fields, w);
    return w;
  }

  Widget smallButton(String text, VoidCallback? action) => TextButton(
      style: TextButton.styleFrom(
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          minimumSize: const Size(0, 30),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
      onPressed: action,
      child: Text(text, style: const TextStyle(fontSize: 12)));
  void beginMarquee(DragStartDetails details) {
    if (!usable || start == null) return;
    final point = start!;
    if (List.generate(visible.length, (i) => cardRect(i))
        .any((r) => r.contains(point))) {
      start = null;
      return;
    }
    base = control || shift ? {...store.selection.ids} : {};
    hits = {};
    setState(() => marquee = Rect.fromPoints(point, details.localPosition));
  }

  Rect cardRect(int i) => Rect.fromLTWH(18 + (i % 2) * (cellWidth + 12),
      6 + (i ~/ 2) * (cellHeight + 12), cellWidth, cellHeight);
  void updateMarquee(DragUpdateDetails details) {
    if (start == null || marquee == null) return;
    final r = Rect.fromPoints(start!, details.localPosition);
    setState(() {
      marquee = r;
      hits = {
        for (var i = 0; i < visible.length; i++)
          if (r.overlaps(cardRect(i))) visible[i].id
      };
      store.selection.ids
        ..clear()
        ..addAll(base)
        ..addAll(hits);
    });
  }

  void endMarquee() {
    if (marquee == null) {
      start = null;
      return;
    }
    final id =
        store.selection.marquee(hits, visible.map((e) => e.id).toList(), base);
    setState(() {
      marquee = null;
      start = null;
    });
    unawaited(applyEntryId(id));
  }

  KeyEventResult key(KeyEvent e) {
    if (!usable ||
        e is! KeyDownEvent ||
        ModalRoute.of(context)?.isCurrent != true ||
        FocusManager.instance.primaryFocus?.context?.widget is EditableText)
      return KeyEventResult.ignored;
    if (control && e.logicalKey == LogicalKeyboardKey.keyD) {
      setState(store.selection.clear);
      return KeyEventResult.handled;
    }
    if (control && e.logicalKey == LogicalKeyboardKey.keyA) {
      setState(() => store.selection.ids.addAll(visible.map((e) => e.id)));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget compositionFilter() {
    const states = ['all', 'universal', 'landscape', 'portrait'];
    const labels = {
      'all': '全部',
      'universal': '通用',
      'landscape': '横图',
      'portrait': '竖图'
    };
    final value = store.librarySuitability;
    return Tooltip(
        message:
            '构图筛选：${value == 'all' ? '全部构图' : StyleDocument.suitabilityNames[value]} · 单击切换',
        child: SizedBox(
            width: 68,
            height: 38,
            child: TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    backgroundColor:
                        Theme.of(context).inputDecorationTheme.fillColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5))),
                onPressed: () => filterChanged(() => store.librarySuitability =
                    states[(states.indexOf(value) + 1) % states.length]),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  PrototypeIcon(
                      value == 'landscape'
                          ? 'landscapeMark'
                          : value == 'portrait'
                              ? 'portraitMark'
                              : value == 'universal'
                                  ? 'compositionUniversal'
                                  : 'compositionAll',
                      size: 18),
                  const SizedBox(width: 4),
                  Text(labels[value] ?? '全部',
                      style: const TextStyle(fontSize: 12))
                ]))));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    visible = store.entries
        .where((e) =>
            e.style.name
                .toLowerCase()
                .contains(store.libraryQuery.toLowerCase()) &&
            (store.libraryFilter != '内置' || e.builtIn) &&
            (store.libraryFilter != '我的' || !e.builtIn) &&
            (store.libraryFilter != '收藏' ||
                widget.settings.favorites.contains(e.id)) &&
            (store.librarySuitability == 'all' ||
                e.style.suitability == store.librarySuitability) &&
            (store.libraryFolder == 'all' || e.folder == store.libraryFolder))
        .toList();
    return Focus(
        focusNode: focus,
        onKeyEvent: (_, e) => key(e),
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: query,
                              decoration: const InputDecoration(
                                  hintText: '搜索预设名称',
                                  prefixIcon: PrototypeIcon('search',
                                      ui: true, size: 17)),
                              onChanged: (v) =>
                                  filterChanged(() => store.libraryQuery = v))),
                      SizedBox(
                          width: 32,
                          child: IconButton(
                              tooltip: '预设管理',
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.more_horiz, size: 21),
                              onPressed: usable ? topMenu : null))
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      for (final f in ['全部', '内置', '我的', '收藏'])
                        Expanded(
                            child: TextButton(
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 30)),
                                onPressed: () => filterChanged(
                                    () => store.libraryFilter = f),
                                child: Text(f,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: store.libraryFilter == f
                                            ? scheme.primary
                                            : scheme.onSurface))))
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      compositionFilter(),
                      const SizedBox(width: 6),
                      Expanded(
                          child: FolderSelect(
                              store: store,
                              value: store.libraryFolder,
                              includeAll: true,
                              onChanged: (v) => filterChanged(
                                  () => store.libraryFolder = v))),
                      const SizedBox(width: 6),
                      SizedBox(
                          width: 34,
                          height: 38,
                          child: IconButton(
                              tooltip: '管理分组',
                              padding: EdgeInsets.zero,
                              onPressed: usable ? manageFolders : null,
                              icon: const PrototypeIcon('manageFolders',
                                  size: 22)))
                    ]),
                  ])),
          if (store.libraryFolder == 'builtin:phone')
            Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Text(
                    '版式参考，与任何手机或相机品牌无关，不提供品牌 Logo。如需使用品牌标识，请用“图片标识”自行导入，并确认你拥有使用权。',
                    style: EditorTypography.hint(context))),
          Expanded(
              child: SmoothScroll(
                  controller: scroll,
                  child: Scrollbar(
                      controller: scroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                          controller: scroll,
                          padding: EdgeInsets.zero,
                          child: LayoutBuilder(builder: (context, box) {
                            cellWidth = (box.maxWidth - 48) / 2;
                            cellHeight = cellWidth * .8 + 34;
                            final offset =
                                scroll.hasClients ? scroll.offset : 0.0;
                            final ready = scroll.hasClients &&
                                scroll.position.hasViewportDimension;
                            if (!ready || !alignedPreset)
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                if (!ready) setState(() {});
                                alignPreset();
                              });
                            final viewport = ready
                                ? scroll.position.viewportDimension
                                : 600.0;
                            final firstRow = math.max(
                                0, (offset / (cellHeight + 12)).floor() - 1);
                            final lastRow =
                                ((offset + viewport) / (cellHeight + 12))
                                        .ceil() +
                                    1;
                            return GestureDetector(
                                key: gridKey,
                                behavior: HitTestBehavior.opaque,
                                onPanDown: (d) {
                                  start = d.localPosition;
                                  focus.requestFocus();
                                },
                                onSecondaryTapUp: (d) async {
                                  if (!usable) return;
                                  final p = d.localPosition;
                                  if (List.generate(
                                          visible.length, (i) => cardRect(i))
                                      .any((r) => r.contains(p))) return;
                                  final choice = await menu(
                                      d.globalPosition, {'folder': '新建分组'});
                                  if (mounted && choice == 'folder')
                                    await newFolder();
                                },
                                onPanStart: beginMarquee,
                                onPanUpdate: updateMarquee,
                                onPanEnd: (_) => endMarquee(),
                                onPanCancel: () {
                                  if (marquee != null)
                                    setState(() {
                                      store.selection.ids
                                        ..clear()
                                        ..addAll(base);
                                      marquee = null;
                                      start = null;
                                    });
                                },
                                child: Stack(children: [
                                  SizedBox(
                                      width: box.maxWidth,
                                      height: (visible.length / 2).ceil() *
                                              (cellHeight + 12) +
                                          60,
                                      child: Stack(children: [
                                        for (var i = 0; i < visible.length; i++)
                                          if (i ~/ 2 >= firstRow &&
                                              i ~/ 2 <= lastRow)
                                            Positioned.fromRect(
                                                rect: cardRect(i),
                                                child: _PresetCard(
                                                    entry: visible[i],
                                                    selected: store
                                                        .selection.ids
                                                        .contains(
                                                            visible[i].id),
                                                    favorite: widget
                                                        .settings.favorites
                                                        .contains(
                                                            visible[i].id),
                                                    preview:
                                                        preview(visible[i]),
                                                    onTap: () =>
                                                        choose(visible[i]),
                                                    onMenu: (p) =>
                                                        cardMenu(visible[i], p),
                                                    onFavorite: usable
                                                        ? () =>
                                                            toggleFavorite(visible[i])
                                                        : null))
                                      ])),
                                  if (visible.isEmpty)
                                    const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text('没有匹配的预设')),
                                  if (marquee != null)
                                    Positioned.fromRect(
                                        rect: marquee!,
                                        child: IgnorePointer(
                                            child: Container(
                                                decoration: BoxDecoration(
                                                    color: scheme.primary
                                                        .withValues(alpha: .12),
                                                    border: Border.all(
                                                        color:
                                                            scheme.primary))))),
                                ]));
                          }))))),
          Padding(
              padding: const EdgeInsets.fromLTRB(15, 8, 15, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (message.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Text(message,
                              style: EditorTypography.hint(context))),
                    Row(children: [
                      Text('已选 ${store.selection.ids.length} 项',
                          style: EditorTypography.label(context)),
                      const Spacer(),
                      Text('Ctrl 多选 · Shift 连选',
                          style: EditorTypography.hint(context)
                              .copyWith(fontSize: 11))
                    ]),
                    const SizedBox(height: 8),
                    AnimatedSize(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 260),
                        curve: Curves.easeInOutCubic,
                        alignment: Alignment.bottomCenter,
                        child: AnimatedSwitcher(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeInOutCubic,
                            switchOutCurve: Curves.easeInOutCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                    opacity: animation,
                                    child: AnimatedBuilder(
                                        animation: animation,
                                        child: child,
                                        builder: (_,
                                                child) =>
                                            Transform.translate(
                                                offset: Offset(0,
                                                    8 * (1 - animation.value)),
                                                child: child))),
                            child: KeyedSubtree(
                                key: ValueKey(selected.isEmpty
                                    ? 'empty'
                                    : selected.length == 1 &&
                                            !selected.first.builtIn
                                        ? 'single'
                                        : 'multi'),
                                child: selected.isNotEmpty
                                    ? Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                            if (selected.length == 1 &&
                                                !selected.first.builtIn)
                                              smallButton(
                                                  '重命名',
                                                  usable
                                                      ? () =>
                                                          rename(selected.first)
                                                      : null),
                                            smallButton('复制',
                                                usable ? copySelected : null),
                                            smallButton(
                                                '移动',
                                                usable &&
                                                        selected.every(
                                                            (e) => !e.builtIn)
                                                    ? moveSelected
                                                    : null),
                                            smallButton(
                                                '导出',
                                                usable
                                                    ? () =>
                                                        exportEntries(selected)
                                                    : null),
                                            smallButton(
                                                '删除',
                                                usable &&
                                                        selected.every(
                                                            (e) => !e.builtIn)
                                                    ? deleteSelected
                                                    : null)
                                          ])
                                    : smallButton('从空白画布开始',
                                        usable ? widget.onNew : null)))),
                  ]))
        ]));
  }
}

class _PresetCard extends StatefulWidget {
  final PresetEntry entry;
  final bool selected, favorite;
  final Widget preview;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final ValueChanged<Offset> onMenu;
  const _PresetCard(
      {required this.entry,
      required this.selected,
      required this.favorite,
      required this.preview,
      required this.onTap,
      required this.onMenu,
      this.onFavorite});
  @override
  State<_PresetCard> createState() => _PresetCardState();
}

class _PresetCardState extends State<_PresetCard> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return MouseRegion(
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onSecondaryTapUp: (d) => widget.onMenu(d.globalPosition),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                      child: Stack(children: [
                    Positioned.fill(
                        child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                    width: 2,
                                    color: widget.selected
                                        ? s.primary
                                        : hover
                                            ? s.primary.withValues(alpha: .38)
                                            : Colors.transparent)),
                            child: PresetThumbnail(
                                style: widget.entry.style,
                                child: widget.preview))),
                    if (hover)
                      Positioned(
                          right: 3,
                          top: 3,
                          child: SizedBox(
                              width: 25,
                              height: 25,
                              child: IconButton(
                                  padding: EdgeInsets.zero,
                                  style: IconButton.styleFrom(
                                      backgroundColor:
                                          s.surface.withValues(alpha: .9)),
                                  tooltip: '预设操作',
                                  icon: const Icon(Icons.more_horiz, size: 18),
                                  onPressed: () {
                                    final box =
                                        context.findRenderObject() as RenderBox;
                                    widget.onMenu(box.localToGlobal(
                                        Offset(box.size.width, 20)));
                                  })))
                  ])),
                  Row(children: [
                    Expanded(
                        child: Text(widget.entry.style.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12))),
                    SizedBox(
                        width: 25,
                        height: 27,
                        child: IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: widget.favorite ? '取消收藏' : '收藏',
                            onPressed: widget.onFavorite,
                            icon: Icon(
                                widget.favorite
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 17,
                                color: widget.favorite
                                    ? s.primary
                                    : Theme.of(context).hintColor)))
                  ]),
                ])));
  }
}
