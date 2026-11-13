import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

import '../../editor/style_render.dart';
import '../../editor/preset_package.dart';
import '../../export/android_photo_io.dart';
import '../../export/export_options.dart';
import '../app_icons.dart';
import 'alpha_sheets.dart';
import 'alpha_workspace.dart';
import 'mobile_editor_page.dart';
import 'mobile_photo_info_page.dart';
import 'mobile_preset_page.dart';
import 'mobile_settings_page.dart';
import 'preset_import_confirmation.dart';

class AlphaPage extends StatefulWidget {
  const AlphaPage(
      {super.key, required this.appearance, required this.setAppearance});

  final ThemeMode appearance;
  final Future<bool> Function(ThemeMode) setAppearance;

  @override
  State<AlphaPage> createState() => _AlphaPageState();
}

class _AlphaPageState extends State<AlphaPage>
    with SingleTickerProviderStateMixin {
  final _bodyKey = GlobalKey();
  final _resumeKey = GlobalKey();
  bool _returning = false;
  late final _entrance = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300), value: 1);
  Offset? _resumeOrigin;
  double _resumeRadius = 0;

  void _enterWorkbench([Rect? source]) {
    _setRevealTarget(source);
    setState(() {
      _returning = false;
      _inWorkbench = true;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward(from: 0);
    }
  }

  void _setRevealTarget(Rect? source) {
    final body = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    _resumeOrigin = source != null && body != null
        ? body.globalToLocal(source.center)
        : null;
    _resumeRadius = source == null ? 0 : source.width / 2;
  }

  void _finishReturning() {
    if (!mounted || !_returning) return;
    setState(() {
      _returning = false;
      _inWorkbench = false;
    });
  }

  void _returnHome() {
    if (_returning) return;
    setState(() => _returning = true);
    if (MediaQuery.disableAnimationsOf(context)) {
      _finishReturning();
      return;
    }
    // Lay out the destination behind the workbench before taking its bounds.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_returning) return;
      final button =
          _resumeKey.currentContext?.findRenderObject() as RenderBox?;
      if (button == null || !button.hasSize) {
        _finishReturning();
        return;
      }
      _setRevealTarget(button.localToGlobal(Offset.zero) & button.size);
      await _entrance.reverse(from: 1).orCancel.catchError((Object error) {
        if (error is! TickerCanceled) throw error;
      });
      _finishReturning();
    });
  }

  final _workspace = AlphaWorkspace();
  ExportOptions _options = ExportOptions();
  bool _inWorkbench = false, _editing = false;
  String? _component;
  bool _removing = false, _incomingPending = true, _readingIncoming = false;

  void _previewTap(String? id) {
    if (id != null) {
      _selectComponent(id);
    } else if (_editing) {
      _back();
    } else {
      _selectComponent(null);
    }
  }

  void _removePhoto(AlphaPhoto photo) {
    _workspace.removePhoto(photo);
    if (_workspace.photos.isEmpty) setState(() => _removing = false);
    _showRemovalUndo();
  }

  void _showRemovalUndo() {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 5),
        persist: false,
        content: const Text('已从本次选图移除'),
        action: SnackBarAction(
            label: '撤销',
            onPressed: () {
              _workspace.undoRemoval();
              if (_workspace.canUndoRemoval) _showRemovalUndo();
            }),
      ));
  }

  void _incomingChanged() {
    if (!_incomingPending ||
        _readingIncoming ||
        !_workspace.libraryReady ||
        _workspace.busy ||
        !mounted) return;
    _incomingPending = false;
    _readingIncoming = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        while (mounted && !_workspace.busy) {
          final type =
              await androidPlatform.invokeMethod<String>('peekIncoming');
          if (type == null || !mounted) break;
          if (type == 'photos' && _workspace.photos.isNotEmpty) {
            final accept = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                        title: const Text('开启新会话？'),
                        content: const Text('接受这批照片会替换当前编辑会话。'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('取消')),
                          FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('开启新会话')),
                        ]));
            if (!mounted) break;
            if (accept != true) {
              await androidPlatform.invokeMethod<void>('discardIncoming');
              continue;
            }
          }
          final rows =
              await androidPlatform.invokeListMethod<Object?>('readIncoming');
          if (rows == null || !mounted) break;
          final items = rows
              .map((row) =>
                  AndroidPhoto.fromJson(Map<String, dynamic>.from(row as Map)))
              .toList();
          if (type == 'preset') {
            final file = File(items.single.path);
            try {
              if (!items.single.name.toLowerCase().endsWith('.lmp')) {
                throw const FormatException('请选择 .lmp 预设文件。');
              }
              final incoming = await readLmp(file);
              if (!mounted) break;
              if (!await confirmMobilePresetImport(context, incoming)) continue;
              if (!mounted) break;
              final count = await _workspace.importPresets(incoming);
              _message('已导入 $count 个预设');
            } finally {
              await file.delete();
            }
          } else {
            _workspace.replaceSession(items);
            setState(() {
              _editing = false;
              _removing = false;
              _inWorkbench = true;
            });
          }
        }
      } on Object catch (error) {
        _message('无法打开共享文件 · ${_detail(error)}');
      } finally {
        _readingIncoming = false;
        _incomingChanged();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  String? _selectionPreset;

  void _back() {
    if (_workspace.busy) return;
    _workspace.cancelComponentPreview();
    FocusManager.instance.primaryFocus?.unfocus();
    if (_editing) {
      setState(() => _editing = false);
    } else {
      _returnHome();
    }
  }

  void _selectComponent(String? id) {
    _workspace.cancelComponentPreview();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _component = id);
  }

  void _openEditor() {
    setState(() {
      _component ??= _workspace.style.nodes.firstOrNull?.id;
      _editing = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _workspace.addListener(_incomingChanged);
    androidPlatform.setMethodCallHandler((call) async {
      if (call.method == 'cancelExport') _workspace.cancelExport();
      if (call.method == 'incoming') {
        _incomingPending = true;
        _incomingChanged();
      }
    });
    unawaited(_workspace.initialize());
  }

  @override
  void dispose() {
    _entrance.dispose();
    androidPlatform.setMethodCallHandler(null);
    _workspace.removeListener(_incomingChanged);
    _workspace.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _pick() async {
    final album = await chooseAlphaSource(context);
    if (!mounted || album == null) return;
    try {
      final alreadyEditing = _inWorkbench && _workspace.photos.isNotEmpty;
      final countBefore = _workspace.photos.length;
      await _workspace.pick(album: album);
      if (mounted && _workspace.photos.length > countBefore) {
        if (!alreadyEditing) _enterWorkbench();
      }
    } on Object catch (error) {
      _message('导入失败 · ${_detail(error)}');
    }
  }

  Future<void> _export() async {
    final source = _workspace.preview?.decoded;
    final options = await showAlphaExport(context, _options,
        photoCount: _workspace.photos.length,
        sourceWidth: source?.sourceWidth,
        sourceHeight: source?.sourceHeight);
    if (!mounted || options == null) return;
    _options = options;
    try {
      await _showExportResult(await _workspace.exportCurrent(options));
    } on Object catch (error) {
      _message('导出失败 · ${_detail(error)}');
    }
  }

  Future<void> _retryExport() async {
    try {
      await _showExportResult(await _workspace.retryExport());
    } on Object catch (error) {
      _message('导出失败 · ${_detail(error)}');
    }
  }

  Future<void> _showExportResult(String summary) async {
    if (!mounted) return;
    if (_workspace.failedNames.isEmpty) {
      _message(summary);
      return;
    }
    final retry = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(summary),
                content: SingleChildScrollView(
                    child: Text(_workspace.failedNames.join('\n'))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('关闭')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('仅重试失败项')),
                ]));
    if (retry == true && mounted) await _retryExport();
  }

  Future<void> _showDiagnostics() async {
    final log = await _workspace.exportDiagnostics();
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('导出诊断'),
              content: SingleChildScrollView(
                  child: SelectableText(log.isEmpty ? '暂无导出错误。' : log)),
              actions: [
                if (log.isNotEmpty)
                  TextButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: log));
                        Navigator.pop(context);
                      },
                      child: const Text('复制日志')),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭')),
              ],
            ));
  }

  String _detail(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is PlatformException && error.message != null)
      return error.message!;
    return error.toString();
  }

  void _fullscreen() {
    if (_workspace.busy || _workspace.preview == null) return;
    _workspace.cancelComponentPreview();
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => _Fullscreen(_workspace),
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 140),
        reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 120),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _workspace,
        builder: (context, _) {
          final workspace = _workspace;
          final colors = Theme.of(context).colorScheme;
          final hasPhotos = _inWorkbench && workspace.photos.isNotEmpty;
          final canEdit = !workspace.busy &&
              workspace.preview != null &&
              workspace.libraryReady;
          if (_selectionPreset != workspace.presetId) {
            _selectionPreset = workspace.presetId;
            _component = null;
          }
          final selected = _component;
          final canvasColor = Theme.of(context).brightness == Brightness.dark
              ? const Color(0xff292826)
              : const Color(0xffcbc9c3);
          const actionStyle = ButtonStyle(
            padding:
                WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
          );
          return PopScope(
            canPop: !hasPhotos && !workspace.busy,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && hasPhotos) _back();
            },
            child: Scaffold(
              backgroundColor: colors.surface,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                leading: hasPhotos ? BackButton(onPressed: _back) : null,
                titleSpacing: hasPhotos ? 0 : 16,
                title: const Text('框印工坊',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                actions: [
                  if (hasPhotos) ...[
                    IconButton(
                      tooltip: '撤销',
                      onPressed: !workspace.busy && workspace.canUndo
                          ? workspace.undo
                          : null,
                      icon: const Icon(Icons.undo, size: 20),
                    ),
                    IconButton(
                      tooltip: '重做',
                      onPressed: !workspace.busy && workspace.canRedo
                          ? workspace.redo
                          : null,
                      icon: const Icon(Icons.redo, size: 20),
                    ),
                  ],
                  if (hasPhotos)
                    IconButton(
                      tooltip: '添加照片',
                      onPressed: workspace.busy ? null : _pick,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                    ),
                  PopupMenuButton<String>(
                    tooltip: '更多功能',
                    enabled: !workspace.busy,
                    onSelected: (entry) {
                      switch (entry) {
                        case 'retryExport':
                          _retryExport();
                        case 'diagnostics':
                          _showDiagnostics();
                        case 'info':
                          Navigator.of(context).push<void>(MaterialPageRoute(
                            builder: (_) => MobilePhotoInfoPage(workspace),
                          ));
                        case 'presets':
                          Navigator.of(context).push<void>(MaterialPageRoute(
                            builder: (_) => MobilePresetPage(workspace),
                          ));
                        case 'settings':
                          Navigator.of(context).push<void>(MaterialPageRoute(
                            builder: (_) => MobileSettingsPage(
                              appearance: widget.appearance,
                              setAppearance: widget.setAppearance,
                              workspace: workspace,
                            ),
                          )).then((_) => workspace.reloadPlaceSettings());
                      }
                    },
                    itemBuilder: (_) => [
                      if (workspace.canRetryExport)
                        const PopupMenuItem(
                            value: 'retryExport', child: Text('仅重试失败项')),
                      const PopupMenuItem(
                          value: 'diagnostics', child: Text('导出诊断')),
                      PopupMenuItem(
                        value: 'info',
                        enabled: hasPhotos && workspace.preview != null,
                        child: const Text('照片信息'),
                      ),
                      PopupMenuItem(
                        value: 'presets',
                        enabled: workspace.libraryReady,
                        child: const Text('预设保存与分享'),
                      ),
                      const PopupMenuItem(value: 'settings', child: Text('设置')),
                    ],
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final keyboard =
                        MediaQuery.viewInsetsOf(context).bottom > 0;
                    final panelHeight = math.max(
                        0.0,
                        math.min(constraints.maxHeight * (keyboard ? .82 : .60),
                            constraints.maxHeight - (keyboard ? 40 : 60)));
                    final showEditor = hasPhotos && _editing;
                    final home = _EmptyState(
                      busy: workspace.busy,
                      pick: _pick,
                      manage: workspace.libraryReady && !workspace.busy
                          ? () =>
                              showAlphaPresets(context, workspace, manage: true)
                          : null,
                      resume: workspace.photos.isEmpty ? null : _enterWorkbench,
                      resumeKey: _resumeKey,
                    );
                    final content = Column(
                      children: [
                        if (workspace.sessionError case final error?)
                          Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(error)),
                        if (workspace.exporting)
                          ListTile(
                              dense: true,
                              title: Text(workspace.busyMessage ?? '正在导出'),
                              trailing: TextButton(
                                  onPressed: workspace.cancelExport,
                                  child: const Text('取消导出'))),
                        if (workspace.busy)
                          Semantics(
                            label: workspace.busyMessage,
                            child: const LinearProgressIndicator(minHeight: 2),
                          ),
                        Expanded(
                          child: hasPhotos
                              ? ColoredBox(
                                  color: canvasColor,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _editing && !workspace.busy
                                        ? () => _previewTap(null)
                                        : null,
                                    child: Column(
                                      children: [
                                        _PhotoHeader(
                                          workspace: workspace,
                                          onFullscreen: _fullscreen,
                                          compact: keyboard,
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: _Canvas(
                                              workspace,
                                              selected: selected,
                                              onComponentTap: workspace.busy
                                                  ? null
                                                  : _previewTap,
                                              onDoubleTap: workspace.busy
                                                  ? null
                                                  : _fullscreen,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : home,
                        ),
                        if (hasPhotos)
                          _EditorDock(
                            expanded: showEditor,
                            editorHeight: panelHeight,
                            controls: Column(children: [
                              TapRegion(
                                onTapOutside: _removing
                                    ? (_) => setState(() => _removing = false)
                                    : null,
                                child: _PhotoStrip(
                                  workspace,
                                  removing: _removing,
                                  onLongPress: () =>
                                      setState(() => _removing = true),
                                  onRemove: _removePhoto,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 6, 10, 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: workspace.busy ||
                                                !workspace.libraryReady
                                            ? null
                                            : () => showAlphaPresets(
                                                context, workspace),
                                        style: actionStyle,
                                        child: const Text('选择预设'),
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    IconButton(
                                      tooltip: '编辑样式',
                                      onPressed: canEdit ? _openEditor : null,
                                      icon: const Icon(Icons.tune),
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: canEdit ? _export : null,
                                        style: actionStyle,
                                        child: const Text('导出照片'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ]),
                            onClose: _back,
                            editor: (update, end, cancel) => MobileEditorPanel(
                              workspace: workspace,
                              selected: selected,
                              onSelected: _previewTap,
                              onDragUpdate: update,
                              onDragEnd: end,
                              onDragCancel: cancel,
                            ),
                          ),
                      ],
                    );
                    return SizedBox.expand(
                      key: _bodyKey,
                      child: !hasPhotos
                          ? content
                          : AnimatedBuilder(
                              animation: _entrance,
                              child: RepaintBoundary(
                                child: ColoredBox(
                                    color: colors.surface, child: content),
                              ),
                              builder: (context, child) {
                                final progress = (_returning
                                        ? Curves.easeInOutCubic
                                        : Curves.easeOutCubic)
                                    .transform(_entrance.value);
                                final animating = progress < 1;
                                final origin = _resumeOrigin;
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (_returning ||
                                        (animating && origin != null))
                                      IgnorePointer(
                                          child: ExcludeSemantics(child: home)),
                                    IgnorePointer(
                                      key: const ValueKey('workbench'),
                                      ignoring: animating || _returning,
                                      child: FractionalTranslation(
                                        translation: Offset(
                                            origin == null
                                                ? .20 * (1 - progress)
                                                : 0,
                                            0),
                                        child: ClipPath(
                                          clipBehavior:
                                              animating && origin != null
                                                  ? Clip.antiAlias
                                                  : Clip.none,
                                          clipper: animating && origin != null
                                              ? _WorkbenchReveal(origin,
                                                  _resumeRadius, progress)
                                              : null,
                                          child: Opacity(
                                            opacity: _returning
                                                ? (progress * 8).clamp(0.0, 1.0)
                                                : 1,
                                            child: child,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
}

class _WorkbenchReveal extends CustomClipper<Path> {
  const _WorkbenchReveal(this.origin, this.initialRadius, this.progress);
  final Offset origin;
  final double initialRadius, progress;

  @override
  Path getClip(Size size) {
    final farthest = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((point) => (point - origin).distance).reduce(math.max);
    final radius = initialRadius + (farthest - initialRadius) * progress;
    return Path()..addOval(Rect.fromCircle(center: origin, radius: radius));
  }

  @override
  bool shouldReclip(_WorkbenchReveal oldClipper) =>
      oldClipper.progress != progress ||
      oldClipper.origin != origin ||
      oldClipper.initialRadius != initialRadius;
}

const _stripHeight = 77.0;
const _dockHeight = _stripHeight + 62;

class _EditorDock extends StatefulWidget {
  const _EditorDock(
      {required this.expanded,
      required this.editorHeight,
      required this.controls,
      required this.editor,
      required this.onClose});

  final bool expanded;
  final double editorHeight;
  final Widget controls;
  final Widget Function(GestureDragUpdateCallback, GestureDragEndCallback,
      GestureDragCancelCallback) editor;
  final VoidCallback onClose;

  @override
  State<_EditorDock> createState() => _EditorDockState();
}

class _EditorDockState extends State<_EditorDock>
    with SingleTickerProviderStateMixin {
  bool get _expanded => widget.expanded && widget.editorHeight >= 56;

  late final _progress = AnimationController(
    vsync: this,
    value: _expanded ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _EditorDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_expanded != (oldWidget.expanded && oldWidget.editorHeight >= 56)) {
      _settle();
    }
  }

  void _settle() {
    final target = _expanded ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _progress.value = target;
      return;
    }
    final distance = (target - _progress.value).abs();
    _progress.animateTo(target,
        duration: Duration(milliseconds: (280 * distance).round()),
        curve: const Cubic(.24, .72, .28, 1));
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (!_expanded) return;
    _progress.value = (_progress.value - details.delta.dy / widget.editorHeight)
        .clamp(.02, 1.0);
  }

  void _dragEnd(DragEndDetails details) {
    if (!_expanded) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 700 || (_progress.value < .7 && velocity >= -700)) {
      widget.onClose();
    } else {
      _settle();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor(_dragUpdate, _dragEnd, _settle);
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final value = _progress.value;
        return SizedBox(
          height: _dockHeight + (widget.editorHeight - _dockHeight) * value,
          child: ClipRect(
            child: _DockLayers(
              progress: value,
              editorHeight: widget.editorHeight,
              expanded: _expanded,
              controls: widget.controls,
              editor: editor,
            ),
          ),
        );
      },
    );
  }
}

class _DockLayers extends StatelessWidget {
  const _DockLayers(
      {required this.progress,
      required this.editorHeight,
      required this.expanded,
      required this.controls,
      required this.editor});

  final double progress, editorHeight;
  final bool expanded;
  final Widget controls, editor;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: _dockHeight,
            child: Offstage(
              offstage: progress == 1,
              child: IgnorePointer(
                ignoring: expanded,
                child: ExcludeSemantics(
                  excluding: expanded,
                  child: FractionalTranslation(
                    translation: Offset(0, -progress),
                    child: RepaintBoundary(child: controls),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: editorHeight,
            child: Offstage(
              offstage: progress == 0,
              child: IgnorePointer(
                ignoring: !expanded,
                child: ExcludeSemantics(
                  excluding: !expanded,
                  child: FractionalTranslation(
                    translation: Offset(0, 1 - progress),
                    child: RepaintBoundary(child: editor),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

class _ResumeButtonShape extends ShapeBorder {
  const _ResumeButtonShape(this.cutout);

  final Rect cutout;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path.combine(
        PathOperation.difference,
        Path()..addOval(rect),
        Path()..addOval(cutout.shift(rect.topLeft)),
      );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => _ResumeButtonShape(Rect.fromLTRB(
      cutout.left * t, cutout.top * t, cutout.right * t, cutout.bottom * t));

  @override
  bool operator ==(Object other) =>
      other is _ResumeButtonShape && other.cutout == cutout;

  @override
  int get hashCode => cutout.hashCode;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.busy,
      required this.pick,
      required this.resumeKey,
      this.resume,
      this.manage});

  final bool busy;
  final VoidCallback pick;
  final ValueChanged<Rect>? resume;
  final GlobalKey resumeKey;
  final VoidCallback? manage;

  Widget _circle(
    BuildContext context, {
    required double size,
    required String label,
    required WorkspaceIcon icon,
    required Color surface,
    required Color foreground,
    required VoidCallback? onTap,
    ShapeBorder shape = const CircleBorder(),
  }) =>
      SizedBox.square(
        dimension: size,
        child: Material(
          shape: shape,
          clipBehavior: Clip.antiAlias,
          elevation: 7,
          shadowColor: Colors.black.withValues(alpha: .36),
          color: surface,
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(icon, size: size * .27, color: foreground),
                const SizedBox(height: 8),
                Text(label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: foreground, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, bounds) {
      const sizeRatio = .64;
      const overlapRatio = .20;
      const gap = 4.0;
      final hasSession = resume != null;
      final available = math.max(0.0, bounds.maxWidth - 48);
      final fit =
          hasSession ? available / (1 + sizeRatio - overlapRatio) : available;
      final main = math.min((bounds.maxWidth * .47).clamp(104.0, 170.0), fit);
      final secondary = main * sizeRatio;
      final groupWidth =
          hasSession ? main + secondary - main * overlapRatio : main;
      final groupHeight = hasSession ? main + secondary * .25 : main;
      final cutout = Rect.fromCircle(
        center: Offset(main / 2 - (groupWidth - secondary),
            main / 2 - (groupHeight - secondary)),
        radius: main / 2 + gap,
      );
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: available,
            minHeight: bounds.maxHeight,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: EdgeInsets.only(
                    top: (bounds.maxHeight * .235).clamp(24, 186)),
                child: SizedBox(
                  width: groupWidth,
                  height: groupHeight,
                  child: Stack(children: [
                    if (hasSession)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Builder(
                            key: resumeKey,
                            builder: (buttonContext) => _circle(context,
                                size: secondary,
                                shape: _ResumeButtonShape(cutout),
                                label: '继续编辑',
                                icon: WorkspaceIcon.resumeEditing,
                                surface: colors.surfaceContainerHighest,
                                foreground: colors.onSurface,
                                onTap: busy
                                    ? null
                                    : () {
                                        final button = buttonContext
                                            .findRenderObject()! as RenderBox;
                                        resume!(
                                            button.localToGlobal(Offset.zero) &
                                                button.size);
                                      })),
                      ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: _circle(context,
                          size: main,
                          label: busy ? '正在导入…' : '选择照片',
                          icon: WorkspaceIcon.photoAdd,
                          surface: colors.primaryContainer,
                          foreground: colors.onPrimaryContainer,
                          onTap: busy ? null : pick),
                    ),
                  ]),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: 28,
                  bottom: (bounds.maxHeight * .225).clamp(32, 174),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 330),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: manage,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.surfaceContainerHighest,
                        foregroundColor: colors.onSurface,
                        elevation: 6,
                        shadowColor: Colors.black.withValues(alpha: .30),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Row(
                        children: [
                          AppIcon(WorkspaceIcon.presetLibrary),
                          SizedBox(width: 12),
                          Expanded(child: Text('管理预设')),
                          Icon(Icons.chevron_right, size: 19),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _PhotoHeader extends StatelessWidget {
  final AlphaWorkspace workspace;
  final VoidCallback onFullscreen;
  final bool compact;
  const _PhotoHeader(
      {required this.workspace,
      required this.onFullscreen,
      this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.brightness == Brightness.dark
        ? Colors.white
        : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${workspace.current?.source.name ?? ''} · ${workspace.style.name}',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foreground.withValues(alpha: .84),
              ),
            ),
          ),
          IconButton(
            tooltip: '全屏预览',
            color: foreground,
            constraints: compact
                ? const BoxConstraints.tightFor(width: 36, height: 32)
                : null,
            padding: compact ? EdgeInsets.zero : null,
            onPressed: workspace.preview == null || workspace.busy
                ? null
                : onFullscreen,
            icon: const Icon(Icons.open_in_full_outlined, size: 20),
          ),
        ],
      ),
    );
  }
}

class _Canvas extends StatelessWidget {
  final AlphaWorkspace workspace;
  final String? selected;
  final ValueChanged<String?>? onComponentTap;
  final VoidCallback? onDoubleTap;
  const _Canvas(this.workspace,
      {this.selected, this.onComponentTap, this.onDoubleTap});

  @override
  Widget build(BuildContext context) {
    if (workspace.preview case final photo?) {
      return Center(
        child: StylePreview(
          key: ValueKey(photo.decoded.file.path),
          photo: photo.image,
          document: workspace.currentStyle,
          fields: workspace.fields,
          photoPath: photo.decoded.file.path,
          selectedComponent: selected,
          onComponentTap: onComponentTap,
          onArtworkDoubleTap: onDoubleTap,
        ),
      );
    }
    return Center(
      child: workspace.loading
          ? const CircularProgressIndicator(strokeWidth: 2)
          : Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                workspace.previewError ?? '请选择照片',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  final AlphaWorkspace workspace;
  final bool removing;
  final VoidCallback onLongPress;
  final ValueChanged<AlphaPhoto> onRemove;
  const _PhotoStrip(this.workspace,
      {required this.removing,
      required this.onLongPress,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: _stripHeight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: workspace.photos.length,
        separatorBuilder: (_, _index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final photo = workspace.photos[index];
          final selected = workspace.index == index;
          return SizedBox(
            key: ValueKey(photo.source.path),
            width: 78,
            child: Stack(fit: StackFit.expand, children: [
              Padding(
                  padding: const EdgeInsets.only(top: 7, right: 7),
                  child: Material(
                    color: colors.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: selected ? colors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onLongPress: workspace.busy ? null : onLongPress,
                      onTap:
                          workspace.busy ? null : () => workspace.select(index),
                      child: Semantics(
                        selected: selected,
                        label: photo.source.name,
                        button: true,
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: FutureBuilder<File>(
                            future: photo.thumbnail(),
                            builder: (context, snapshot) => snapshot.hasData
                                ? Image.file(snapshot.data!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _error, _stack) =>
                                        const Icon(Icons.broken_image_outlined))
                                : Icon(snapshot.hasError
                                    ? Icons.broken_image_outlined
                                    : Icons.image_outlined),
                          ),
                        ),
                      ),
                    ),
                  )),
              if (removing)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Tooltip(
                    message: '移除照片',
                    child: Semantics(
                      button: true,
                      label: '移除照片',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: workspace.busy ? null : () => onRemove(photo),
                        child: SizedBox.square(
                          dimension: 44,
                          child: Align(
                            alignment: Alignment.topRight,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: colors.surface, width: 1),
                              ),
                              child: SizedBox.square(
                                dimension: 20,
                                child: Icon(Icons.close,
                                    size: 12, color: colors.onPrimaryContainer),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}

class _Fullscreen extends StatelessWidget {
  final AlphaWorkspace workspace;
  const _Fullscreen(this.workspace);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: workspace,
        builder: (context, _) => Scaffold(
          backgroundColor: const Color(0xff111110),
          appBar: AppBar(
            title: Text(
              workspace.current?.source.name ?? '全屏预览',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: InteractiveViewer(
                    key: ValueKey(workspace.index),
                    minScale: 1,
                    maxScale: 6,
                    child: _Canvas(workspace,
                        onDoubleTap: () => Navigator.of(context).pop()),
                  ),
                ),
                if (workspace.photos.length > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: '上一张',
                        onPressed: workspace.index > 0
                            ? () => workspace.select(workspace.index - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                          '${workspace.index + 1} / ${workspace.photos.length}'),
                      IconButton(
                        tooltip: '下一张',
                        onPressed: workspace.index + 1 < workspace.photos.length
                            ? () => workspace.select(workspace.index + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
}
