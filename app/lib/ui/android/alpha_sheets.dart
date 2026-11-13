import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../editor/preset_store.dart';
import '../../editor/style_document.dart';
import '../../editor/image_mark.dart';
import '../../editor/photo_palette.dart';
import '../../editor/style_render.dart';
import '../../editor/texture_render.dart';
import '../../export/export_options.dart';
import '../app_icons.dart';
import '../preset_thumbnail.dart';
import 'alpha_workspace.dart';
import 'mobile_fields.dart';
import 'mobile_preset_page.dart';
import 'preset_demo_preview.dart';

Future<bool?> chooseAlphaSource(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetTitle('选择照片'),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '需要自动填写拍摄地点时，请使用「从文件选择」。开启该功能后，系统会按需请求读取照片里的拍摄位置。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('从相册选择'),
                onTap: () => Navigator.pop(context, true),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('从文件选择'),
                onTap: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      ),
    );

Future<void> showAlphaPresets(
  BuildContext context,
  AlphaWorkspace workspace, {
  bool manage = false,
}) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .86,
        child: _PresetSheet(workspace, manage: manage),
      ),
    );

class _SheetTitle extends StatelessWidget {
  final String text;
  const _SheetTitle(this.text, {this.action});
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (action != null) action!,
          IconButton(
            tooltip: '关闭',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      );
}

class _PresetSheet extends StatefulWidget {
  final AlphaWorkspace workspace;
  final bool manage;
  const _PresetSheet(this.workspace, {required this.manage});

  @override
  State<_PresetSheet> createState() => _PresetSheetState();
}

class _PresetSheetState extends State<_PresetSheet> {
  String _query = '';
  String? _folder;
  bool _favorites = false;
  final _groups = MenuController();
  final _thumbnails = <(StyleDocument, AlphaPreview), Future<ui.Image?>>{};
  Future<void> _thumbnailQueue = Future.value();
  final _demoThumbnails = <(String, StyleDocument), Future<Uint8List?>>{};

  Widget _demoThumbnail(PresetEntry entry) {
    final placeholder = ColoredBox(color: Color(entry.style.background));
    if (entry.builtIn) {
      return Image.asset(
        '$builtinDemoDirectory/${entry.id}.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.low,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }
    final cache = widget.workspace.presetDemoCache;
    if (cache == null) return placeholder;
    return FutureBuilder<Uint8List?>(
      future: _demoThumbnails.putIfAbsent(
        (entry.id, entry.style),
        () => cache.read(entry),
      ),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return bytes == null
            ? placeholder
            : Image.memory(
                bytes,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.low,
                errorBuilder: (context, error, stackTrace) => placeholder,
              );
      },
    );
  }

  Completer<void>? _scrollEnd;
  Animation<double>? _sheetAnimation;
  bool _showGrid = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _sheetAnimation)) return;
    _sheetAnimation?.removeStatusListener(_onSheetStatus);
    _sheetAnimation = animation;
    _showGrid =
        animation == null || animation.status == AnimationStatus.completed;
    if (!_showGrid) animation?.addStatusListener(_onSheetStatus);
  }

  void _onSheetStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _sheetAnimation?.removeStatusListener(_onSheetStatus);
    setState(() => _showGrid = true);
  }

  bool _onGridScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) {
      _scrollEnd ??= Completer<void>();
    } else if (notification is ScrollEndNotification) {
      _scrollEnd?.complete();
      _scrollEnd = null;
    }
    return false;
  }

  Future<ui.Image?> _thumbnail(StyleDocument style, AlphaPreview preview) =>
      _thumbnails.putIfAbsent((style, preview), () {
        final future = _thumbnailQueue.then((_) async {
          if (!mounted) return null;
          await SchedulerBinding.instance.endOfFrame;
          while (_scrollEnd != null) {
            await _scrollEnd!.future;
          }
          if (!mounted) return null;
          return _renderThumbnail(style, preview);
        });
        _thumbnailQueue = future.then<void>((_) {});
        return future;
      });

  Future<ui.Image?> _renderThumbnail(
      StyleDocument style, AlphaPreview preview) async {
    ui.Image? photo;
    StyleScene? scene;
    ui.Picture? picture;
    final lease = Object();
    try {
      final original = preview.image.clone();
      photo = original;
      final marks = style.nodes
          .where((node) => node.type == 'image')
          .map((node) => node.image)
          .toList();
      pinImageMarks(lease, marks);
      final fields = {...preview.fields};
      if (style.nodes.any((node) => node.type == 'palette') &&
          paletteFromFields(fields).length != 6) {
        fields[photoPaletteField] =
            (await photoPaletteForFile(preview.decoded.file.path)).join(',');
      }
      await prepareImageMarks(marks);
      await ensureTexture(style.fill.texture);
      if (!mounted) return null;
      scene = StyleScene(style, original, fields);
      final size = scene.geometry.size;
      final scale = math.min(300 / size.width, 220 / size.height);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(scale);
      scene.paint(canvas);
      picture = recorder.endRecording();
      return await picture.toImage(math.max(1, (size.width * scale).round()),
          math.max(1, (size.height * scale).round()));
    } on Object {
      return null;
    } finally {
      picture?.dispose();
      scene?.dispose();
      photo?.dispose();
      releaseImageMarks(lease);
    }
  }

  @override
  void dispose() {
    _sheetAnimation?.removeStatusListener(_onSheetStatus);
    _scrollEnd?.complete();
    _scrollEnd = null;
    for (final thumbnail in _thumbnails.values) {
      unawaited(thumbnail.then((image) => image?.dispose()));
    }
    super.dispose();
  }

  Widget _groupPicker(AlphaWorkspace workspace) {
    final options = {
      '': '全部分组',
      'ungrouped': '未分组',
      for (final folder in workspace.folders) folder.id: folder.name
    };
    final current = _folder ?? '';
    return LayoutBuilder(
        builder: (context, bounds) => MenuAnchor(
              controller: _groups,
              menuChildren: [
                SizedBox(
                  width: bounds.maxWidth,
                  height: math.min(280.0, options.length * 48.0),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    children: [
                      for (final option in options.entries)
                        ListTile(
                          title: Text(option.value,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          selected: current == option.key,
                          trailing: current == option.key
                              ? const Icon(Icons.check, size: 18)
                              : null,
                          onTap: () {
                            _groups.close();
                            setState(() => _folder =
                                option.key.isEmpty ? null : option.key);
                          },
                        ),
                    ],
                  ),
                ),
              ],
              builder: (context, controller, _) => InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                child: InputDecorator(
                  decoration: mobileInputDecoration(context),
                  child: Row(children: [
                    Expanded(
                        child: Text(options[current] ?? '全部分组',
                            overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.arrow_drop_down),
                  ]),
                ),
              ),
            ));
  }

  String _folderId(PresetEntry entry) => entry.builtIn || entry.folder.isEmpty
      ? entry.folder
      : 'user:${entry.folder}';

  void _openPreset(PresetEntry entry) {
    if (widget.manage) {
      showMobilePresetActions(context, widget.workspace, entry);
    } else {
      widget.workspace.choosePreset(entry);
      Navigator.pop(context);
    }
  }

  Future<void> _favorite(String id) async {
    try {
      await widget.workspace.toggleFavorite(id);
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('收藏未能保存，请稍后重试。')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = widget.workspace;
    return ListenableBuilder(
      listenable: workspace,
      builder: (context, _) {
        final entries = workspace.presets
            .where((entry) =>
                (_folder == null ||
                    (_folder == 'ungrouped'
                        ? !entry.builtIn && entry.folder.isEmpty
                        : _folderId(entry) == _folder)) &&
                (!_favorites || workspace.isFavorite(entry.id)) &&
                entry.style.name.toLowerCase().contains(_query))
            .toList();
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                _SheetTitle(
                  widget.manage ? '管理预设' : '预设',
                  action: TextButton.icon(
                    icon: const AppIcon(WorkspaceIcon.presetImport, size: 18),
                    label: const Text('导入预设'),
                    onPressed: () => showMobilePresetImport(context, workspace),
                  ),
                ),
                TextField(
                  onChanged: (text) =>
                      setState(() => _query = text.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜索预设',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _groupPicker(workspace),
                    ),
                    const SizedBox(width: 10),
                    FilterChip(
                      avatar: const Icon(Icons.star_outline),
                      label: const Text('收藏'),
                      selected: _favorites,
                      onSelected: (value) => setState(() => _favorites = value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: entries.isEmpty
                      ? Center(
                          child: Text(workspace.libraryError ?? '没有符合条件的预设'))
                      : NotificationListener<ScrollNotification>(
                          onNotification: _onGridScroll,
                          child: LayoutBuilder(
                            builder: (context, constraints) => GridView.builder(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              physics: _showGrid
                                  ? null
                                  : const NeverScrollableScrollPhysics(),
                              itemCount: _showGrid
                                  ? entries.length
                                  : math.min(entries.length, 6),
                              gridDelegate:
                                  SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent:
                                    constraints.maxWidth < 540 ? 205 : 240,
                                mainAxisExtent: 143,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                              ),
                              itemBuilder: (context, index) {
                                if (!_showGrid) {
                                  return DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: colors.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  );
                                }
                                final entry = entries[index];
                                final selected = !widget.manage &&
                                    workspace.presetId == entry.id;
                                final preview =
                                    widget.manage ? null : workspace.preview;
                                return Material(
                                  color: colors.surfaceContainerHighest,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: selected
                                          ? colors.primary
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _openPreset(entry),
                                          child: PresetThumbnail(
                                            style: entry.style,
                                            child: Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: preview == null
                                                  ? _demoThumbnail(entry)
                                                  : FutureBuilder<ui.Image?>(
                                                      future: _thumbnail(
                                                          entry.style, preview),
                                                      builder:
                                                          (context, snapshot) {
                                                        final image =
                                                            snapshot.data;
                                                        return image == null
                                                            ? ColoredBox(
                                                                color: Color(entry
                                                                    .style
                                                                    .background))
                                                            : RawImage(
                                                                image: image,
                                                                fit: BoxFit
                                                                    .contain,
                                                                filterQuality:
                                                                    FilterQuality
                                                                        .low);
                                                      },
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: InkWell(
                                              onTap: () => _openPreset(entry),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 12),
                                                child: Text(
                                                  entry.style.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme.bodyMedium,
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip:
                                                workspace.isFavorite(entry.id)
                                                    ? '取消收藏'
                                                    : '收藏',
                                            onPressed: () =>
                                                _favorite(entry.id),
                                            icon: Icon(
                                              workspace.isFavorite(entry.id)
                                                  ? Icons.star
                                                  : Icons.star_outline,
                                              size: 20,
                                              color:
                                                  workspace.isFavorite(entry.id)
                                                      ? colors.primary
                                                      : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<ExportOptions?> showAlphaExport(
  BuildContext context,
  ExportOptions previous, {
  int photoCount = 1,
  int? sourceWidth,
  int? sourceHeight,
}) =>
    showModalBottomSheet<ExportOptions>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _ExportSheet(previous, sourceWidth, sourceHeight, photoCount),
    );

class _ExportSheet extends StatefulWidget {
  final ExportOptions previous;
  final int? sourceWidth, sourceHeight;
  final int photoCount;
  const _ExportSheet(
      this.previous, this.sourceWidth, this.sourceHeight, this.photoCount);

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  late final _options = widget.previous.copy();
  bool _validSize = true;
  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (mounted && _validSize) {
      if (_options.replaceAndroidExports) {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('替换同名旧成片？'),
                  content: const Text('本应用已导出的同名旧成片可能被替换。'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('返回')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('确认替换')),
                  ],
                ));
        if (!mounted || confirmed != true) return;
      }
      if (widget.photoCount == 1) _options.scope = 'current';
      Navigator.pop(context, _options);
    }
  }

  double? get _sourceEdge {
    final width = widget.sourceWidth, height = widget.sourceHeight;
    if (width == null || height == null) return null;
    return (_options.sizeEdge == 'short'
            ? (width < height ? width : height)
            : (width > height ? width : height))
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetTitle('导出照片'),
              if (widget.photoCount > 1) ...[
                SegmentedButton<String>(
                  segments: [
                    const ButtonSegment(value: 'current', label: Text('当前照片')),
                    ButtonSegment(
                        value: 'all',
                        label: Text('全部 · ${widget.photoCount} 张')),
                  ],
                  selected: {_options.scope == 'all' ? 'all' : 'current'},
                  onSelectionChanged: (selection) =>
                      setState(() => _options.scope = selection.single),
                ),
                const SizedBox(height: 12),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('替换同名旧成片'),
                subtitle: const Text('默认添加编号，保留全部'),
                value: _options.replaceAndroidExports,
                onChanged: (value) =>
                    setState(() => _options.replaceAndroidExports = value),
              ),
              Text('文件格式', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'jpg', label: Text('JPG')),
                  ButtonSegment(value: 'png', label: Text('PNG')),
                ],
                selected: {_options.format},
                onSelectionChanged: (value) =>
                    setState(() => _options.format = value.single),
              ),
              const SizedBox(height: 16),
              Text('成片尺寸', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<String>(
                      initialValue: _options.sizeEdge,
                      onChanged: (value) =>
                          setState(() => _options.sizeEdge = value!),
                      items: const [
                        DropdownMenuItem(value: 'long', child: Text('长边')),
                        DropdownMenuItem(value: 'short', child: Text('短边')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MobileNumberField(
                      label: '像素 px',
                      value: _options.edgePixels?.toDouble(),
                      scrubBase: _sourceEdge,
                      hint: '原尺寸',
                      min: 1,
                      max: exportMaxEdge.toDouble(),
                      step: 10,
                      integer: true,
                      onValidityChanged: (valid) => _validSize = valid,
                      onChanged: (value) =>
                          setState(() => _options.edgePixels = value?.toInt()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _options.format == 'jpg'
                    ? 'JPG 画质 · ${_options.quality}'
                    : 'JPG 画质',
                style: theme.textTheme.titleSmall,
              ),
              Slider(
                min: 1,
                max: 100,
                divisions: 99,
                value: _options.quality.toDouble(),
                onChanged: _options.format == 'jpg'
                    ? (value) =>
                        setState(() => _options.quality = value.round())
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('保留拍摄参数'),
                value: _options.retainCaptureInfo,
                onChanged: (value) =>
                    setState(() => _options.retainCaptureInfo = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('保留 GPS'),
                subtitle: const Text('将精确位置写入导出的照片'),
                value: _options.retainGps,
                onChanged: (value) =>
                    setState(() => _options.retainGps = value),
              ),
              const SizedBox(height: 12),
              Text(
                '如果锁屏后导出进度停住，可以解锁并回到应用继续，或保持亮屏直到导出完成。'
                '也可以在手机系统设置中检查是否限制了 LumaCraft 的后台运行。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.download_outlined),
                label: const Text('保存到相册'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
