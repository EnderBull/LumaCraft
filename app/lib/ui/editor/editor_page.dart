import 'dart:async';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import '../../directory_browser.dart';
import '../directory_panel.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../editor/style_document.dart';
import '../../editor/background_style.dart';
import '../../fonts/font_catalog.dart';
import '../../editor/editor_controller.dart';
import '../../editor/preset_store.dart';
import '../../editor/style_render.dart';
import '../../editor/photo_palette.dart';
import '../../editor/image_mark.dart';
import '../../editor/shape_style.dart';
import 'shape_picker.dart';
import 'texture_picker.dart';
import 'postmark_picker.dart';
import '../../editor/postmark.dart';
import 'component_picker.dart';
import '../../workspace_settings.dart';
import '../../window_controls.dart';
import '../workspace_layout.dart';
import '../smooth_scroll.dart';
import '../preset_panel.dart';
import '../workspace_dialog.dart';
import '../folder_select.dart';
import '../builtin_folder_select.dart';
import '../preset_thumbnail.dart';
import 'prototype_controls.dart';
import 'workspace_chrome.dart';
import 'mode_transition.dart';
import 'number_drag_input.dart';
import 'hsb_color_picker.dart';
part 'editor_panels.dart';
part 'editor_canvas.dart';
part 'palette_panel.dart';
part 'background_panel.dart';
part 'image_panel.dart';
part 'shape_panel.dart';

class PresetEditor extends StatefulWidget {
  final List<File> files;
  final int current;
  final Set<String> selected;
  final StyleDocument initial;
  final String sourceKey;
  final String? initialBuiltinId;
  final Set<String> edited;
  final WorkspaceSettings settings;
  final PresetStore presets;
  final Future<Map<String, String>> Function(File) metadata;
  final Future<void> Function(StyleDocument, Set<String>) apply;
  final ui.Image? initialPhoto;
  final Map<String, String> initialFields;
  final double initialPhotoScrollOffset;
  final Future<void> Function(EditorBrowseState)? onReturn;
  final String? initialDirectory;
  final List<String> initialDirectories;
  final bool initialScanning;
  const PresetEditor(
      {super.key,
      required this.files,
      required this.current,
      required this.selected,
      required this.initial,
      this.sourceKey = 'global',
      this.initialBuiltinId,
      this.edited = const {},
      required this.settings,
      required this.presets,
      required this.metadata,
      required this.apply,
      this.initialPhoto,
      this.initialFields = const {},
      this.initialPhotoScrollOffset = 0,
      this.onReturn,
      this.initialDirectory,
      this.initialDirectories = const [],
      this.initialScanning = false});
  @override
  State<PresetEditor> createState() => _PresetEditorState();
}

class _PresetEditorState extends State<PresetEditor> {
  String? dropRow;
  String? builtinTarget;
  String? layerRenameId;
  (String?, int, bool, bool, int)? dropLocation;
  final layerViewport = GlobalKey();
  Offset? dragGlobal;
  Timer? dragTimer;
  late final List<File> files;
  final editorScanner = PhotoScanner();
  String? directory;
  List<String> directoryRoots = [];
  bool directoryTab = false, scanning = false;
  final appliedSnapshots = <String, StyleDocument>{};
  late final EditorController c;
  late final StyleDocument entry;
  late int index;
  late Set<String> selectedPhotos;
  final images = <String, ui.Image>{},
      information = <String, Map<String, String>>{};
  final layerScroll = SmoothScrollController(),
      propertyScroll = SmoothScrollController();
  late final SmoothScrollController photoScroll;
  Timer? saveTimer;
  String status = '草稿仅在应用后影响照片';
  int panel = 0, photoAnchor = 0;
  bool saving = false, dialogOpen = false, space = false, applying = false;
  bool colorPicking = false;
  bool marksLoading = false;
  bool backgroundSecond = false;
  String? marksError;
  bool leaving = false;
  int loadTicket = 0;
  String? loadError;
  String? paletteError;
  final paletteLoading = <String>{};
  ui.Image? emptyPhoto;
  ui.Image? get photo => files.isEmpty ? emptyPhoto : images[files[index].path];
  Map<String, String> get fields =>
      files.isEmpty ? {} : information[files[index].path] ?? {};
  String previewMode = 'original';
  double get ratio => previewMode == 'landscape'
      ? 1.5
      : previewMode == 'portrait'
          ? 2 / 3
          : previewMode == 'square'
              ? 1
              : photo == null
                  ? 1.5
                  : photo!.width / photo!.height;
  String? inlineId;
  final inlineInput = TextEditingController();
  final inlineFocus = FocusNode();
  bool resizingNode = false;
  double resizeDistance = 1;
  ShapeGrip? shapeGrip;
  bool shapeRotating = false;
  double shapeAngleStart = 0, shapeRotationStart = 0;
  StyleScene? scene;
  Offset origin = Offset.zero;
  double canvasScale = 1, zoom = 1;
  Offset pan = Offset.zero;
  Offset? down;
  Map<String, StyleNode>? originals;
  Rect? movingBounds, marquee;
  bool handDrag = false, moved = false;
  Offset panStart = Offset.zero;
  List<(bool, double)> guides = [];
  bool get ctrl =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;
  bool get shift => HardwareKeyboard.instance.isShiftPressed;
  @override
  void initState() {
    super.initState();
    files = List<File>.of(widget.files);
    directory = widget.initialDirectory ??
        (files.isEmpty ? null : files.first.parent.path);
    directoryRoots = widget.initialDirectories.isNotEmpty
        ? List.of(widget.initialDirectories)
        : [if (directory != null) directory!];
    index = widget.current;
    photoAnchor = index;
    selectedPhotos = {...widget.selected};
    photoScroll = SmoothScrollController(
        initialScrollOffset: widget.initialPhotoScrollOffset);
    if (files.isNotEmpty && widget.initialPhoto != null) {
      images[files[index].path] = widget.initialPhoto!.clone();
      information[files[index].path] = {...widget.initialFields};
    }
    builtinTarget = widget.initialBuiltinId;
    entry = widget.initial.copy();
    c = EditorController(
        widget.presets.draftFor(widget.sourceKey)?.copy() ?? entry.copy())
      ..addListener(changed);
    c.doc.switchLayout(StyleDocument.orientation(ratio));
    HardwareKeyboard.instance.addHandler(keyboard);
    loadPhoto();
    unawaited(ensureMarks());
    if (widget.initialScanning && directory != null)
      browseEditor(directory!, reset: false);
  }

  void update(VoidCallback action) {
    if (mounted) setState(action);
  }

  void changed() {
    if (!mounted) return;
    setState(() {});
    unawaited(ensureMarks());
    if (colorPicking) {
      saveTimer?.cancel();
      return;
    }
    if (c.doc.nodes.any((n) => n.type == 'palette') &&
        files.isNotEmpty &&
        paletteFromFields(fields).length != 6 &&
        paletteError == null) {
      unawaited(ensurePhotoPalette());
    }
    saveTimer?.cancel();
    saveTimer = Timer(const Duration(milliseconds: 450), () => saveDraft());
  }

  Future<void> ensureMarks() async {
    final marks = c.doc.nodes
        .where((n) => n.type == 'image')
        .map((n) => n.image)
        .toList();
    pinImageMarks(c, marks);
    if (marksLoading) return;
    if (marks.every((m) => imageMarkReady(m.data))) {
      marksError = null;
      return;
    }
    final keys = marks.map((m) => m.data).toSet();
    marksLoading = true;
    try {
      await prepareImageMarks(marks);
      if (mounted) marksError = null;
    } catch (e) {
      if (mounted) {
        marksError = '图片标识加载失败，请替换素材：$e';
        status = marksError!;
      }
    } finally {
      marksLoading = false;
      if (mounted) {
        final current = c.doc.nodes
            .where((n) => n.type == 'image')
            .map((n) => n.image)
            .toList();
        if (current
            .any((m) => !keys.contains(m.data) && !imageMarkReady(m.data))) {
          unawaited(ensureMarks());
        }
        setState(() {});
      }
    }
  }

  Future<bool> saveDraft() async {
    try {
      await widget.presets.save(draft: c.doc, sourceKey: widget.sourceKey);
      if (mounted && status.startsWith('草稿')) setState(() => status = '草稿已保存');
      return true;
    } catch (e) {
      if (mounted) setState(() => status = '草稿保存失败：$e');
      return false;
    }
  }

  Future<void> loadPhoto() async {
    if (files.isEmpty) {
      if (emptyPhoto != null) return;
      final record = ui.PictureRecorder(), canvas = Canvas(record);
      canvas.drawRect(
          const Rect.fromLTWH(0, 0, 900, 600),
          Paint()
            ..shader = ui.Gradient.linear(Offset.zero, const Offset(900, 600),
                [const Color(0xff7599a6), const Color(0xffc7d0c8)]));
      final mountain = Path()
        ..moveTo(0, 470)
        ..lineTo(260, 210)
        ..lineTo(445, 410)
        ..lineTo(640, 285)
        ..lineTo(900, 500)
        ..lineTo(900, 600)
        ..lineTo(0, 600)
        ..close();
      canvas.drawPath(mountain, Paint()..color = const Color(0xff5a7375));
      final picture = record.endRecording(),
          sample = await picture.toImage(900, 600);
      picture.dispose();
      if (!mounted) {
        sample.dispose();
        return;
      }
      if (emptyPhoto == null) {
        setState(() => emptyPhoto = sample);
      } else {
        sample.dispose();
      }
      return;
    }
    final sourceFile = files[index];
    final ticket = ++loadTicket, path = sourceFile.path;
    update(() {
      loadError = null;
      paletteError = null;
    });
    try {
      if (!images.containsKey(path)) {
        final buffer = await ui.ImmutableBuffer.fromFilePath(path);
        final codec = await ui.instantiateImageCodecWithSize(buffer,
            getTargetSize: (w, h) {
          final scale = math.min(1.0, 1600 / math.max(w, h));
          return ui.TargetImageSize(
              width: (w * scale).round(), height: (h * scale).round());
        });
        late ui.Image img;
        try {
          img = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
        if (!mounted) {
          img.dispose();
          return;
        }
        if (images.containsKey(path)) {
          img.dispose();
        } else {
          images[path] = img;
        }
      }
      information[path] = {
        ...?information[path],
        ...await widget.metadata(sourceFile)
      };
      if (!mounted) return;
      if (ticket == loadTicket && c.doc.nodes.any((n) => n.type == 'palette')) {
        await ensurePhotoPalette();
      }
      if (ticket == loadTicket)
        setState(() {
          c.doc.switchLayout(StyleDocument.orientation(ratio));
        });
      while (images.length > 5) {
        final key = images.keys
            .firstWhere((k) => k != (files.isEmpty ? '' : files[index].path));
        images.remove(key)?.dispose();
      }
    } catch (e) {
      if (mounted && ticket == loadTicket)
        setState(() => loadError = '照片加载失败：$e');
    }
  }

  Future<bool> ensurePhotoPalette() async {
    if (files.isEmpty) return false;
    final path = files[index].path;
    if (paletteFromFields(information[path] ?? {}).length == 6) return true;
    if (!paletteLoading.add(path)) return false;
    update(() => paletteError = null);
    try {
      final colors = await photoPaletteForFile(path);
      if (!mounted) return false;
      information[path] = {
        ...?information[path],
        photoPaletteField: colors.join(',')
      };
      setState(() {});
      return files.isNotEmpty && files[index].path == path;
    } catch (e) {
      if (mounted && files.isNotEmpty && files[index].path == path)
        update(() => paletteError = '照片提色失败，请重试');
      return false;
    } finally {
      paletteLoading.remove(path);
    }
  }

  Future<void> pickPhoto(int next,
      {bool range = false, bool toggle = false}) async {
    update(() {
      if (range) {
        final a = math.min(photoAnchor, next), b = math.max(photoAnchor, next);
        if (!toggle) selectedPhotos.clear();
        selectedPhotos.addAll(files.sublist(a, b + 1).map((f) => f.path));
      } else if (toggle) {
        final path = files[next].path;
        selectedPhotos.contains(path)
            ? selectedPhotos.remove(path)
            : selectedPhotos.add(path);
        photoAnchor = next;
      } else {
        selectedPhotos = {files[next].path};
        photoAnchor = next;
      }
      index = next;
    });
    await loadPhoto();
  }

  bool keyboard(KeyEvent e) {
    if (!mounted ||
        dialogOpen ||
        PresetPanel.keyboardActive ||
        ModalRoute.of(context)?.isCurrent != true) return false;
    final focus = FocusManager.instance.primaryFocus?.context;
    final typing =
        focus?.findAncestorWidgetOfExactType<EditableText>() != null ||
            focus?.widget is EditableText;
    if (typing) return false;
    if (e.logicalKey == LogicalKeyboardKey.space) {
      update(() => space = e is! KeyUpEvent);
      return true;
    }
    if (e is KeyUpEvent) return false;
    final key = e.logicalKey;
    final photos = focus?.findAncestorWidgetOfExactType<_PhotoFocus>() != null;
    if (ctrl && key == LogicalKeyboardKey.keyD) {
      update(() => photos ? selectedPhotos.clear() : c.select(null));
      return true;
    }
    if (ctrl && key == LogicalKeyboardKey.keyA) {
      if (photos) {
        update(() => selectedPhotos = files.map((f) => f.path).toSet());
      } else {
        c.selection
          ..clear()
          ..addAll(c.doc.order);
        c.update();
      }
      return true;
    }
    if (ctrl && key == LogicalKeyboardKey.keyZ) {
      shift ? c.redo() : c.undo();
      return true;
    }
    if (photos) {
      if (files.isEmpty) return false;
      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight) {
        pickPhoto(
            (index + (key == LogicalKeyboardKey.arrowLeft ? -1 : 1))
                .clamp(0, files.length - 1),
            range: shift,
            toggle: ctrl);
        return true;
      }
      return false;
    }
    if (ctrl && key == LogicalKeyboardKey.keyJ) {
      c.duplicate();
      return true;
    }
    if (ctrl && key == LogicalKeyboardKey.keyG) {
      shift ? c.ungroup() : c.group();
      return true;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      c.remove();
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (down != null) {
        if (handDrag) pan = panStart;
        handDrag = false;
        resizingNode = false;
        shapeGrip = null;
        shapeRotating = false;
        c.end(cancel: true);
        update(() {
          down = null;
          originals = null;
          marquee = null;
          guides = [];
        });
      } else {
        c.select(null);
      }
      return true;
    }
    if (c.selection.isNotEmpty &&
        !c.protected &&
        [
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowRight,
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.arrowDown
        ].contains(key)) {
      final step = (shift ? 10 : 1) / canvasScale;
      final originals = {for (final n in c.selectedNodes) n.id: n.copy()};
      c.edit(() => c.moveNodes(
          originals,
          Offset(
              key == LogicalKeyboardKey.arrowLeft
                  ? -step
                  : key == LogicalKeyboardKey.arrowRight
                      ? step
                      : 0,
              key == LogicalKeyboardKey.arrowUp
                  ? -step
                  : key == LogicalKeyboardKey.arrowDown
                      ? step
                      : 0),
          ratio));
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    editorScanner.cancel();
    dragTimer?.cancel();
    saveTimer?.cancel();
    inlineInput.dispose();
    inlineFocus.dispose();
    HardwareKeyboard.instance.removeHandler(keyboard);
    scene?.dispose();
    releaseImageMarks(c);
    c.removeListener(changed);
    c.dispose();
    for (final image in images.values) {
      image.dispose();
    }
    emptyPhoto?.dispose();
    layerScroll.dispose();
    propertyScroll.dispose();
    photoScroll.dispose();
    super.dispose();
  }

  void browseEditor(String path, {bool reset = true}) {
    finishInline();
    editorScanner.cancel();
    loadTicket++;
    update(() {
      directory = path;
      if (reset) directoryRoots = [path];
      if (reset) {
        files.clear();
        index = 0;
        photoAnchor = 0;
        selectedPhotos.clear();
      }
      scanning = true;
    });
    widget.settings.lastDirectory = path;
    widget.settings.changed();
    editorScanner.startMany(directoryRoots.isEmpty ? [path] : directoryRoots,
        recursive: widget.settings.includeChildren,
        onBatch: (batch) {
          if (!mounted) return;
          final old = files.isEmpty ? null : files[index].path;
          update(() {
            final known = files.map((f) => f.path).toSet();
            final anchorPath = files.isEmpty
                ? null
                : files[photoAnchor.clamp(0, files.length - 1)].path;
            files.addAll(batch.where((f) => known.add(f.path)));
            files.sort(
                (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
            index = old == null ? 0 : files.indexWhere((f) => f.path == old);
            photoAnchor = anchorPath == null
                ? 0
                : files.indexWhere((f) => f.path == anchorPath);
            if (old == null) selectedPhotos.add(files.first.path);
          });
          if (old == null) loadPhoto();
        },
        onDone: (skipped) {
          update(() {
            scanning = false;
            status = files.isEmpty ? '此目录没有照片' : '已找到 ${files.length} 张照片';
          });
        },
        onError: (error) => update(() => status = '目录读取失败：$error'));
  }

  Widget directoryContents() => DirectoryPanel(
      currentPath: directory,
      includeChildren: widget.settings.includeChildren,
      enabled: !applying,
      scanning: scanning,
      count: files.length,
      onSelect: browseEditor,
      onRecursive: (v) {
        widget.settings.includeChildren = v;
        widget.settings.changed();
        if (directory != null) browseEditor(directory!);
      },
      onChooseDirectory: () async {
        final path = await getDirectoryPath();
        if (path != null && mounted) browseEditor(path);
      });
  Future<T?> modal<T>(Widget Function(BuildContext) builder) async {
    dialogOpen = true;
    space = false;
    try {
      return await showDialog<T>(context: context, builder: builder);
    } finally {
      dialogOpen = false;
    }
  }

  Future<void> leave() async {
    if (leaving) return;
    leaving = true;
    finishInline();
    if (!await saveDraft()) {
      leaving = false;
      return;
    }
    if (!mounted) return;
    if (widget.onReturn != null) {
      await widget.onReturn!(EditorBrowseState(
          files: List.of(files),
          current: index,
          anchor: photoAnchor,
          selected: Set.of(selectedPhotos),
          scrollOffset: photoScroll.hasClients ? photoScroll.offset : 0,
          directory: directory,
          directories: List.of(directoryRoots),
          scanning: scanning,
          photo: photo));
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> textEdit(String id) async {
    finishInline();
    c.end();
    final n = c.doc.node(id);
    if (n == null) return;
    c.select(id);
    update(() => panel = 2);
    if (c.doc.locked(id) || n.type != 'text') return;
    update(() {
      inlineId = id;
      inlineInput.text = n.text;
      inlineInput.selection =
          TextSelection(baseOffset: 0, extentOffset: n.text.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) inlineFocus.requestFocus();
    });
  }

  void finishInline({bool cancel = false}) {
    final id = inlineId;
    if (id == null) return;
    inlineId = null;
    if (!cancel) {
      final n = c.doc.node(id);
      if (n != null) c.edit(() => n.text = inlineInput.text);
    }
    if (mounted) setState(() {});
  }

  Future<void> savePreset({bool asUser = false}) async {
    if (dialogOpen) return;
    if (!asUser && builtinTarget != null && widget.presets.authoring) {
      await saveBuiltinPreset();
      return;
    }
    finishInline();
    c.end();
    String? target;
    String saveFolder = (widget.presets.libraryFolder == 'all' ||
            widget.presets.libraryFolder.startsWith('builtin:'))
        ? ''
        : widget.presets.libraryFolder;
    String name = c.doc.name;
    String suitability = c.doc.suitability;
    String? error;
    final input = TextEditingController(text: name);
    final presetScroll = ScrollController();
    final result = await modal<bool>((ctx) => StatefulBuilder(
        builder: (ctx, set) => WorkspaceDialog(
                title: const Text('保存预设'),
                content: SizedBox(
                    width: 590,
                    child: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          const Text('选择新建，或选择一个用户预设覆盖保存'),
                          const SizedBox(height: 14),
                          SizedBox(
                              height:
                                  (((widget.presets.presets.length + 4) ~/ 4)
                                              .clamp(1, 2)) *
                                          140 +
                                      10,
                              child: Scrollbar(
                                  controller: presetScroll,
                                  thumbVisibility: true,
                                  child: GridView(
                                      controller: presetScroll,
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 4,
                                              mainAxisExtent: 140,
                                              crossAxisSpacing: 10,
                                              mainAxisSpacing: 10),
                                      children: [
                                        presetSaveCard(
                                            '新建预设',
                                            null,
                                            target == null,
                                            () => set(() {
                                                  target = null;
                                                  input.text = name;
                                                })),
                                        for (final p in widget.presets.presets)
                                          presetSaveCard(
                                              p.style.name,
                                              p.style,
                                              target == p.id,
                                              () => set(() {
                                                    if (target == null)
                                                      name = input.text;
                                                    target = p.id;
                                                    input.text = p.style.name;
                                                    saveFolder = p.folder;
                                                  }))
                                      ]))),
                          const SizedBox(height: 18),
                          WorkspaceTextField(
                              label: '预设名称',
                              controller: input,
                              error: error,
                              maxLength: 200),
                          const SizedBox(height: 16),
                          Text('构图标记', style: EditorTypography.label(ctx)),
                          const SizedBox(height: 8),
                          PrototypeSelect(
                              value: suitability,
                              options: StyleDocument.suitabilityNames,
                              onChanged: (v) => set(() => suitability = v)),
                          const SizedBox(height: 16),
                          Text('所属分组', style: EditorTypography.label(ctx)),
                          const SizedBox(height: 8),
                          FolderSelect(
                              store: widget.presets,
                              value: saveFolder,
                              onChanged: (v) => set(() => saveFolder = v))
                        ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () async {
                        final name = input.text.trim();
                        if (name.isEmpty) {
                          set(() => error = '请输入名称');
                          return;
                        }
                        if (widget.presets.presets.any(
                            (p) => p.style.name == name && p.id != target)) {
                          set(() => error = '名称已存在，请选择该预设覆盖或更换名称');
                          return;
                        }
                        final style = c.doc.copy()
                          ..name = name
                          ..suitability = suitability;
                        final next = [...widget.presets.presets];
                        final i = next.indexWhere((p) => p.id == target);
                        if (i < 0) {
                          next.add(UserPreset(newObjectId(), style,
                              folder: saveFolder));
                        } else {
                          next[i] =
                              UserPreset(target!, style, folder: saveFolder);
                        }
                        try {
                          await widget.presets.save(
                              presets: next,
                              draft: c.doc,
                              sourceKey: widget.sourceKey);
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) set(() => error = '保存失败：$e');
                        }
                      },
                      child: Text(target == null ? '新建保存' : '覆盖保存'))
                ])));
    if (result == true) update(() => status = '预设已保存');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      presetScroll.dispose();
      input.dispose();
    });
  }

  Future<void> saveBuiltinPreset() async {
    final id = builtinTarget;
    final existing = widget.presets.builtinLibrary.entries
        .where((p) => p.id == id)
        .firstOrNull;
    if (existing == null) return;
    finishInline();
    c.end();
    final input = TextEditingController(text: c.doc.name);
    var folder = existing.folder, suitability = c.doc.suitability;
    String? error;
    bool busy = false;
    final result = await modal<String>((ctx) => StatefulBuilder(
        builder: (ctx, set) => WorkspaceDialog(
                title: const Text('保存内置预设'),
                content: SizedBox(
                    width: 390,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('正在维护内置预设，修改将保存到制作版工作库。',
                              style: EditorTypography.hint(ctx)),
                          const SizedBox(height: 18),
                          WorkspaceTextField(
                              label: '预设名称',
                              controller: input,
                              error: error,
                              maxLength: 200),
                          const SizedBox(height: 16),
                          Text('所属分组', style: EditorTypography.label(ctx)),
                          const SizedBox(height: 8),
                          BuiltinFolderSelect(
                              store: widget.presets,
                              value: folder,
                              onChanged: (v) => set(() => folder = v)),
                          const SizedBox(height: 16),
                          Text('构图标记', style: EditorTypography.label(ctx)),
                          const SizedBox(height: 8),
                          PrototypeSelect(
                              value: suitability,
                              options: StyleDocument.suitabilityNames,
                              onChanged: (v) => set(() => suitability = v))
                        ])),
                actions: [
                  TextButton(
                      onPressed: busy ? null : () => Navigator.pop(ctx, 'user'),
                      child: const Text('另存用户预设')),
                  TextButton(
                      onPressed: busy ? null : () => Navigator.pop(ctx),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (input.text.trim().isEmpty) {
                                set(() => error = '请输入名称');
                                return;
                              }
                              set(() => busy = true);
                              try {
                                final doc = c.doc.copy()
                                  ..name = input.text.trim()
                                  ..suitability = suitability;
                                await widget.presets
                                    .saveBuiltin(id!, doc, folder);
                                if (ctx.mounted) Navigator.pop(ctx, 'saved');
                              } catch (e) {
                                if (ctx.mounted)
                                  set(() {
                                    busy = false;
                                    error = '保存失败：$e';
                                  });
                              }
                            },
                      child: Text(busy ? '正在保存…' : '保存内置'))
                ])));
    if (result == 'saved') update(() => status = '内置预设已更新，可在维护面板导出封包');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      input.dispose();
    });
    if (result == 'user') await savePreset(asUser: true);
  }

  Future<void> applyStyle() async {
    if (dialogOpen || files.isEmpty) return;
    finishInline();
    c.end();
    bool all = selectedPhotos.length > 1;
    final yes = await modal<bool>((ctx) => StatefulBuilder(
        builder: (ctx, set) => WorkspaceDialog(
                title: const Text('应用样式'),
                content: SizedBox(
                    width: 400,
                    child: RadioGroup<bool>(
                        groupValue: all,
                        onChanged: (v) => set(() => all = v!),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const RadioListTile<bool>(
                              value: false, title: Text('仅当前照片')),
                          RadioListTile<bool>(
                              value: true,
                              enabled: selectedPhotos.isNotEmpty,
                              title: Text('选中照片 · ${selectedPhotos.length} 张'))
                        ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('确认应用'))
                ])));
    if (yes != true) return;
    update(() => applying = true);
    try {
      await widget.apply(
          c.doc.copy(), all ? {...selectedPhotos} : {files[index].path});
      update(() {
        status = '样式已应用';
        for (final path in all ? selectedPhotos : {files[index].path}) {
          appliedSnapshots[path] = c.doc.copy();
        }
      });
    } catch (e) {
      update(() => status = '应用失败：$e');
    } finally {
      update(() => applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(children: [
      editorHeader(),
      Expanded(
          child: WorkspaceLayout(
              settings: widget.settings,
              library: ModeSidebar(
                  child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: layersPanel())),
              stage: canvasPanel(),
              inspector: ModeSidebar(
                  right: true,
                  child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: inspectorPanel())),
              filmstrip: photosPanel())),
      SizedBox(
          height: 28,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                const Text('● 本地草稿', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 20),
                Expanded(
                    child: Text(status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)))
              ])))
    ]));
  }

  Widget editorHeader() => WorkspaceHeader(
      settings: widget.settings,
      editing: true,
      onBrowse: leave,
      onEdit: () {},
      beforeClose: () async {
        finishInline();
        await widget.settings.save();
        return saveDraft();
      });
}

class _PhotoFocus extends StatelessWidget {
  final Widget child;
  const _PhotoFocus({required this.child});
  @override
  Widget build(BuildContext context) => Focus(child: child);
}
