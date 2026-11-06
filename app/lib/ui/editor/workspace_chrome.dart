import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../workspace_settings.dart';
import '../../window_controls.dart';
import '../app_icons.dart';
import '../smooth_scroll.dart';
import '../photo_thumb.dart';
import 'prototype_controls.dart';

class WorkspaceHeader extends StatelessWidget {
  final WorkspaceSettings settings;
  final bool editing;
  final VoidCallback onBrowse;
  final VoidCallback? onEdit;
  final Future<bool> Function() beforeClose;
  final String? documentName;
  const WorkspaceHeader(
      {super.key,
      required this.settings,
      required this.editing,
      required this.onBrowse,
      required this.onEdit,
      required this.beforeClose,
      this.documentName});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        Widget dragArea(Widget child) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => DesktopWindow.action('drag'),
            onDoubleTap: () => DesktopWindow.action('maximize'),
            child: child);
        Widget windowButton(IconData icon, String label, String command) =>
            Tooltip(
                message: label,
                child: SizedBox(
                    width: 42,
                    height: 54,
                    child: IconButton(
                        style: IconButton.styleFrom(
                            shape: const RoundedRectangleBorder()),
                        onPressed: () async {
                          if (command == 'close' && !await beforeClose())
                            return;
                          await DesktopWindow.action(command);
                        },
                        icon: Icon(icon, size: 17))));
        return Container(
            height: 54,
            decoration: BoxDecoration(color: scheme.surface, boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .38),
                  blurRadius: 20,
                  offset: const Offset(0, 6))
            ]),
            child: Row(children: [
              dragArea(const WorkspaceBrand()),
              const SizedBox(width: 24),
              EditorModeSwitch(
                  editing: editing, onBrowse: onBrowse, onEdit: onEdit),
              if (documentName != null) ...[
                const SizedBox(width: 20),
                ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(documentName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)))
              ],
              Expanded(child: dragArea(const SizedBox.expand())),
              Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(9)),
                  child: Row(children: [
                    for (final side in [false, true])
                      Tooltip(
                          message: side ? '侧栏纵向铺满' : '底栏横向铺满',
                          child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                  color: settings.sideFirst == side
                                      ? scheme.surfaceContainerHighest
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6)),
                              child: IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    settings.sideFirst = side;
                                    settings.changed();
                                  },
                                  icon: AppIcon(
                                      side
                                          ? WorkspaceIcon.sideLayout
                                          : WorkspaceIcon.bottomLayout,
                                      size: 20))))
                  ])),
              const SizedBox(width: 8),
              Tooltip(
                  message: '切换明暗外观',
                  child: IconButton(
                      onPressed: () {
                        settings.dark = !settings.dark;
                        settings.changed();
                      },
                      icon: AppIcon(
                          settings.dark
                              ? WorkspaceIcon.moon
                              : WorkspaceIcon.sun,
                          size: 20))),
              const SizedBox(width: 8),
              if (Platform.isWindows) ...[
                windowButton(Icons.remove, '最小化', 'minimize'),
                ValueListenableBuilder<bool>(
                    valueListenable: DesktopWindow.maximized,
                    builder: (context, maximized, _) => windowButton(
                        maximized ? Icons.filter_none : Icons.crop_square,
                        '最大化 / 还原',
                        'maximize')),
                windowButton(Icons.close, '关闭', 'close')
              ]
            ]));
      });
}

class WorkspaceFilmstrip extends StatefulWidget {
  final List<File> files;
  final Set<String> selected, edited;
  final int current;
  final SmoothScrollController controller;
  final bool enabled;
  final void Function(int, bool, bool) onSelect;
  final VoidCallback onSelectAll, onClear;
  final String notice;
  final int relinkCount;
  final VoidCallback? onRelink;

  /// Pairs the app already matched on its own. Shown as a quiet confirmation
  /// so the user learns what happened, without a dialog interrupting them.
  final int autoRelinkCount;
  final VoidCallback? onShowAutoRelink;
  const WorkspaceFilmstrip(
      {super.key,
      this.notice = '',
      this.relinkCount = 0,
      this.onRelink,
      this.autoRelinkCount = 0,
      this.onShowAutoRelink,
      required this.files,
      required this.selected,
      required this.current,
      required this.controller,
      required this.onSelect,
      required this.onSelectAll,
      required this.onClear,
      this.edited = const {},
      this.enabled = true});
  @override
  State<WorkspaceFilmstrip> createState() => _WorkspaceFilmstripState();
}

class _WorkspaceFilmstripState extends State<WorkspaceFilmstrip> {
  double? cachedHeight;
  Widget? cachedList;
  @override
  void didUpdateWidget(covariant WorkspaceFilmstrip old) {
    super.didUpdateWidget(old);
    cachedList = null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget neutral(String label, VoidCallback? action) => TextButton(
        style: TextButton.styleFrom(
            backgroundColor: scheme.surfaceContainerHighest,
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
        onPressed: action,
        child: Text(label, style: const TextStyle(fontSize: 12)));
    return Column(children: [
      LayoutBuilder(
          builder: (context, box) => SizedBox(
              height: widget.notice.isNotEmpty && box.maxWidth <= 800 ? 56 : 36,
              child: Stack(children: [
                Positioned.fill(
                    top: widget.notice.isNotEmpty && box.maxWidth <= 800
                        ? 20
                        : 0,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(children: [
                          Text('${widget.files.length} 张照片',
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 12),
                          Text('已选 ${widget.selected.length} 张',
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 12),
                          neutral(
                              '全选',
                              widget.enabled && widget.files.isNotEmpty
                                  ? widget.onSelectAll
                                  : null),
                          const SizedBox(width: 8),
                          neutral(
                              '取消选择', widget.enabled ? widget.onClear : null),
                          // Only when something actually waits for the user:
                          // a button that is always there trains people to
                          // ignore it.
                          if (widget.onRelink != null && widget.relinkCount > 0) ...[
                            const SizedBox(width: 8),
                            TextButton.icon(
                                style: TextButton.styleFrom(
                                    backgroundColor:
                                        scheme.primary.withValues(alpha: .16),
                                    foregroundColor: scheme.primary,
                                    minimumSize: const Size(0, 28),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(6))),
                                onPressed: widget.enabled
                                    ? widget.onRelink
                                    : null,
                                icon: const Icon(Icons.link, size: 14),
                                label: Text('重新关联 ${widget.relinkCount} 张',
                                    style: const TextStyle(fontSize: 12)))
                          ],
                          if (widget.autoRelinkCount > 0 &&
                              widget.onShowAutoRelink != null) ...[
                            const SizedBox(width: 8),
                            TextButton.icon(
                                style: TextButton.styleFrom(
                                    backgroundColor:
                                        scheme.surfaceContainerHighest,
                                    foregroundColor: scheme.onSurface,
                                    minimumSize: const Size(0, 28),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(6))),
                                onPressed: widget.enabled
                                    ? widget.onShowAutoRelink
                                    : null,
                                icon: Icon(Icons.check_circle_outline,
                                    size: 14,
                                    color: EditorTypography.dimOn(context)),
                                label: Text(
                                    '已自动关联 ${widget.autoRelinkCount} 张',
                                    style: const TextStyle(fontSize: 12)))
                          ],
                          const Spacer(),
                          if (box.maxWidth > 600)
                            Text('Ctrl 增减 · Shift 连选',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).hintColor))
                        ]))),
                if (widget.notice.isNotEmpty)
                  Positioned(
                      top: 0,
                      height: box.maxWidth <= 800 ? 20 : 36,
                      left: box.maxWidth <= 800 ? 14 : 380,
                      right: box.maxWidth <= 800 ? 14 : 380,
                      child: Center(
                          child: Text('• ${widget.notice}',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: scheme.primary))))
              ]))),
      Expanded(child: LayoutBuilder(builder: (context, box) {
        if (cachedHeight == box.maxHeight && cachedList != null)
          return cachedList!;
        cachedHeight = box.maxHeight;
        final extent = (box.maxHeight * 1.15).clamp(110.0, 270.0);
        return cachedList = ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: Scrollbar(
                controller: widget.controller,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                thickness: 8,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SmoothScroll(
                    controller: widget.controller,
                    axis: Axis.horizontal,
                    child: ListView.builder(
                        controller: widget.controller,
                        scrollDirection: Axis.horizontal,
                        itemExtent: extent,
                        padding: const EdgeInsets.fromLTRB(10, 3, 10, 18),
                        itemCount: widget.files.length,
                        itemBuilder: (context, i) {
                          final file = widget.files[i];
                          return Tooltip(
                              message: file.path,
                              child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: InkWell(
                                      onTap: !widget.enabled
                                          ? null
                                          : () {
                                              FocusScope.of(context)
                                                  .requestFocus(
                                                      Focus.of(context));
                                              widget.onSelect(
                                                  i,
                                                  HardwareKeyboard.instance
                                                          .isControlPressed ||
                                                      HardwareKeyboard.instance
                                                          .isMetaPressed,
                                                  HardwareKeyboard
                                                      .instance.isShiftPressed);
                                            },
                                      child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              color: widget.selected
                                                      .contains(file.path)
                                                  ? scheme.primary
                                                      .withValues(alpha: .10)
                                                  : null,
                                              border: Border.all(
                                                  width: 1.5,
                                                  color: widget.current == i
                                                      ? scheme.primary
                                                      : widget.selected
                                                              .contains(
                                                                  file.path)
                                                          ? scheme.primary
                                                              .withValues(
                                                                  alpha: .45)
                                                          : Colors
                                                              .transparent)),
                                          child: Column(children: [
                                            Expanded(
                                                child: Center(
                                                    child: Stack(children: [
                                              PhotoThumb(file),
                                              if (widget.edited
                                                  .contains(file.path))
                                                Positioned(
                                                    left: 6,
                                                    top: 6,
                                                    child: Tooltip(
                                                        message: '已编辑',
                                                        child: Container(
                                                            width: 8,
                                                            height: 8,
                                                            decoration: BoxDecoration(
                                                                shape: BoxShape
                                                                    .circle,
                                                                color: scheme
                                                                    .primary,
                                                                border: Border.all(
                                                                    color: const Color(
                                                                        0x55000000),
                                                                    width: .6),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                      color: scheme
                                                                          .primary
                                                                          .withValues(
                                                                              alpha:
                                                                                  .65),
                                                                      blurRadius:
                                                                          6,
                                                                      spreadRadius:
                                                                          1)
                                                                ]))))
                                            ]))),
                                            const SizedBox(height: 5),
                                            Row(children: [
                                              Expanded(
                                                  child: Text(
                                                      file.uri.pathSegments
                                                          .last,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 12))),
                                            ])
                                          ])))));
                        }))));
      }))
    ]);
  }
}
