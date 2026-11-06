import 'dart:async';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import '../../directory_browser.dart';
import '../../photo_state.dart';
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
import '../../export/color_management.dart';
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
import '../heif_store_buttons.dart';
import '../folder_select.dart';
import '../builtin_folder_select.dart';
import '../preset_thumbnail.dart';
import '../photo_info_form.dart';
import '../photo_thumb.dart';
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
  final Future<void> Function(String path, String value)? onSavePlace;
  final Future<void> Function(String path, String key, String value)?
      onSaveField;
  final int relinkCount;
  final Future<void> Function()? onRelink;
  final int autoRelinkCount;
  final Future<void> Function()? onShowAutoRelink;
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
      this.onSavePlace,
      this.onSaveField,
      this.relinkCount = 0,
      this.onRelink,
      this.autoRelinkCount = 0,
      this.onShowAutoRelink,
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
  final folderWatch = PhotoFolderWatch();
  Timer? watchTimer;
  String? directory;
  List<String> directoryRoots = [];
  bool directoryTab = false, scanning = false;
  final appliedSnapshots = <String, StyleDocument>{};
  late final EditorController c;
  late final StyleDocument entry;
  StyleDocument? openedPreset;
  final bornNodes = <String, StyleNode>{};
  StyleDocument? _initialView;
  String? _initialViewLayout;
  late int index;
  late Set<String> selectedPhotos;
  final images = <String, ui.Image>{},
      information = <String, Map<String, String>>{};
  final layerScroll = SmoothScrollController(),
      propertyScroll = SmoothScrollController();
  late final SmoothScrollController photoScroll;
  Timer? saveTimer;
  Timer? placeTimer;
  (String, String)? placePending;
  Timer? fieldTimer;
  (String, String)? fieldPending;
  final infoFieldControllers = <String, TextEditingController>{};
  final placeOpen = <String, bool>{};
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
    resetOpenedPreset();
    HardwareKeyboard.instance.addHandler(keyboard);
    loadPhoto();
    unawaited(ensureMarks());
    if (widget.initialScanning && directory != null) {
      browseEditor(directory!, reset: false);
    } else {
      startWatching();
    }
  }

  void update(VoidCallback action) {
    if (mounted) setState(action);
  }

  /// 记下打开这套预设时的数字。整份样式被换掉时重新记；中途新加的组件记它刚出现时的数字。
  void resetOpenedPreset() {
    openedPreset = c.doc.copy();
    bornNodes.clear();
    _initialView = null;
    _initialViewLayout = null;
  }

  void adoptNewNodes() {
    final base = openedPreset;
    if (base == null) return;
    for (final n in c.doc.nodes) {
      if (base.node(n.id) == null && !bornNodes.containsKey(n.id)) {
        bornNodes[n.id] = n.copy();
      }
    }
  }

  StyleNode? initialNode(String id) {
    final base = openedPreset;
    if (base != null) {
      if (_initialView == null || _initialViewLayout != c.doc.editingLayout) {
        final view = base.copy();
        if (view.editingLayout != c.doc.editingLayout) {
          view.switchLayout(c.doc.editingLayout);
        }
        _initialView = view;
        _initialViewLayout = c.doc.editingLayout;
      }
      final found = _initialView!.node(id);
      if (found != null) return found;
    }
    return bornNodes[id];
  }

  double initialNum(
      String id, double Function(StyleNode) read, double fallback) {
    final n = initialNode(id);
    return n == null ? fallback : read(n);
  }

  void changed() {
    adoptNewNodes();
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
        final img = await decodePhotoImage(path, maxEdge: 1600);
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
        setState(() => loadError =
            e is PhotoDecodeException ? e.message : '照片加载失败：$e');
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
    final arrows = {
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown
    };
    if (e is KeyUpEvent && arrows.contains(e.logicalKey)) {
      final still =
          HardwareKeyboard.instance.logicalKeysPressed.any(arrows.contains);
      if (!still) c.end();
    }
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
    if (e is KeyUpEvent) {
      return arrows.contains(e.logicalKey) && c.selection.isNotEmpty;
    }
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
      c.end();
      shift ? c.redo() : c.undo();
      return true;
    }
    // 选中了组件时，方向键只移动组件。按住期间算同一步，松手后再按才是新的一步。
    if (c.selection.isNotEmpty && arrows.contains(key)) {
      if (c.protected) return true;
      c.begin();
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
    return false;
  }

  @override
  void dispose() {
    editorScanner.cancel();
    folderWatch.stop();
    watchTimer?.cancel();
    dragTimer?.cancel();
    saveTimer?.cancel();
    placeTimer?.cancel();
    final pending = placePending;
    placePending = null;
    if (pending != null) widget.onSavePlace?.call(pending.$1, pending.$2);
    fieldTimer?.cancel();
    final fieldPendingNow = fieldPending;
    fieldPending = null;
    if (fieldPendingNow != null) {
      final parts = fieldPendingNow.$1.split('@');
      widget.onSaveField?.call(parts.first, parts.last, fieldPendingNow.$2);
    }
    for (final controller in infoFieldControllers.values) {
      controller.dispose();
    }
    infoFieldControllers.clear();
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
          startWatching();
        },
        onError: (error) => update(() => status = '目录读取失败：$error'));
  }

  /// Watches the folder while editing. A photo deleted outside the app must
  /// leave the list; otherwise applying a style to it would fail silently.
  void startWatching() {
    final roots = directoryRoots.isEmpty
        ? [if (directory != null) directory!]
        : directoryRoots;
    if (roots.isEmpty) return;
    unawaited(folderWatch.start(roots,
        recursive: widget.settings.includeChildren, onChanged: () {
      if (!mounted || applying) return;
      watchTimer?.cancel();
      watchTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted && !applying) syncWithDisk();
      });
    }));
    // Deletions do not always raise a watcher event on Windows, so check the
    // folder on a timer as well. The check is a directory listing, and a full
    // re-read only happens when the set of files actually changed.
    watchTimer?.cancel();
    watchTimer = Timer.periodic(verifyInterval, (_) async {
      if (!mounted || applying || scanning) return;
      final roots2 = directoryRoots.isEmpty
          ? [if (directory != null) directory!]
          : directoryRoots;
      if (roots2.isEmpty) return;
      final here = <String>{};
      for (final root in roots2) {
        try {
          await for (final entity in Directory(root).list(
              recursive: widget.settings.includeChildren,
              followLinks: false)) {
            if (entity is File && photoFilePattern.hasMatch(entity.path))
              here.add(entity.path);
          }
        } catch (_) {}
      }
      if (!mounted) return;
      final mine = files.map((f) => f.path).toSet();
      if (here.length == mine.length && here.every(mine.contains)) return;
      await syncWithDisk();
    });
  }

  /// Drops photos that are gone and picks up new ones, keeping the photo
  /// being edited whenever it still exists.
  Future<void> syncWithDisk() async {
    final roots = directoryRoots.isEmpty
        ? [if (directory != null) directory!]
        : directoryRoots;
    if (roots.isEmpty) return;
    final current = scanning;
    scanning = true;
    final result = await editorScanner.collect(roots,
        recursive: widget.settings.includeChildren);
    if (!mounted) return;
    final found = result.files;
    // A cancelled scan can come back empty; never treat that as "every photo
    // was deleted" unless the photos on screen really are gone.
    if (found.isEmpty && files.isNotEmpty && files.any((f) => f.existsSync())) {
      update(() => scanning = current);
      return;
    }
    final here = found.map((f) => f.path).toSet();
    final missing = files.where((f) => !here.contains(f.path)).toList();
    final known = files.map((f) => f.path).toSet();
    final added = found.where((f) => !known.contains(f.path)).toList();
    if (missing.isEmpty && added.isEmpty) {
      update(() => scanning = current);
      return;
    }
    final editingPath = files.isEmpty ? null : files[index].path;
    update(() {
      // `files` is a late final list shared with the panels; it must be
      // refilled in place, not reassigned (that throws and silently kills the
      // refresh).
      files
        ..clear()
        ..addAll(found);
      if (missing.isNotEmpty) {
        for (final file in missing) {
          images.remove(file.path)?.dispose();
          information.remove(file.path);
          selectedPhotos.remove(file.path);
          forgetThumbnail(file.path);
        }
      }
      final next = editingPath == null
          ? 0
          : files.indexWhere((f) => f.path == editingPath);
      index = next >= 0 && files.isNotEmpty ? next : 0;
      if (index >= files.length) index = files.isEmpty ? 0 : files.length - 1;
      photoAnchor = index;
      if (missing.isNotEmpty && files.isNotEmpty &&
          files[index].path != editingPath) {
        loadTicket++;
      }
      scanning = current;
      if (missing.isNotEmpty) {
        status =
            '共 ${files.length} 张照片 · ${missing.length} 张已不在文件夹里，已从列表移除';
      } else if (added.isNotEmpty) {
        status = '共 ${files.length} 张照片 · 新增 ${added.length} 张';
      }
    });
    if (missing.any((f) => f.path == editingPath) && files.isNotEmpty)
      loadPhoto();
    if (added.isNotEmpty) await ensureMarks();
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
    // One photo selected means there is nothing to choose: apply straight to
    // it. The dialog only appears when a range decision is actually needed.
    final single = selectedPhotos.length <= 1;
    if (single) {
      await applyTo({files[index].path});
      return;
    }
    bool all = true;
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
    await applyTo(all ? {...selectedPhotos} : {files[index].path});
  }

  Future<void> applyTo(Set<String> targets) async {
    update(() => applying = true);
    try {
      await widget.apply(c.doc.copy(), targets);
      update(() {
        status = targets.length > 1
            ? '样式已应用到 ${targets.length} 张照片'
            : '样式已应用';
        for (final path in targets) {
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
