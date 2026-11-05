import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'render.dart';
import 'editor/style_document.dart';
import 'editor/preset_store.dart';
import 'editor/style_render.dart';
import 'ui/editor/editor_page.dart';
import 'ui/editor/prototype_controls.dart';
import 'ui/editor/workspace_chrome.dart';
import 'ui/editor/mode_transition.dart';
import 'photo_state.dart';
import 'directory_browser.dart';
import 'workspace_settings.dart';
import 'window_controls.dart';
import 'export/export_options.dart';
import 'export/export_naming.dart';
import 'export/export_preferences.dart';
import 'export/export_task.dart';
import 'export/color_management.dart';
import 'ui/export/export_dialog.dart';
import 'ui/export/export_conflict_dialog.dart';
import 'ui/workspace_dialog.dart';
import 'ui/app_theme.dart';
import 'ui/workspace_layout.dart';
import 'ui/directory_panel.dart';
import 'ui/smooth_scroll.dart';
import 'ui/preset_panel.dart';
import 'ui/browse_viewport.dart';

final workspaceSettings = WorkspaceSettings(
    File('${PhotoStore.defaultFile().parent.path}/workspace.json'));
void main() => runApp(const LumaCraftApp());

class LumaCraftApp extends StatelessWidget {
  const LumaCraftApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: workspaceSettings,
      builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '框印工坊 · LumaCraft',
          theme: workspaceTheme(workspaceSettings.dark),
          home: const Workshop()));
}

class Workshop extends StatefulWidget {
  const Workshop({super.key});
  @override
  State<Workshop> createState() => _WorkshopState();
}

class _WorkshopState extends State<Workshop> {
  List<File> files = [];
  final selection = PhotoSelection();
  int get index => selection.current;
  bool png = false, busy = false, cancel = false, ready = false;
  Set<String> get selected => selection.paths;
  final store = PhotoStore(PhotoStore.defaultFile());
  final presetStore = PresetStore(
      File('${PhotoStore.defaultFile().parent.path}/editor-presets.json'));
  final metadata = <String, Future<Map<String, String>>>{};
  List<File> failed = [];
  String? outputDirectory;
  String exportScope = 'selected';
  ExportOptions exportOptions = ExportOptions();
  List<NamingPart> exportTemplate = defaultNamingTemplate();
  final exportPreferences = ExportPreferences(
      File('${PhotoStore.defaultFile().parent.path}/export-settings.json'));
  List<ExportJob> failedExportJobs = [];
  ExportOptions? failedExportOptions;
  bool exportPanelOpen = false;

  final scanner = PhotoScanner();
  final filmstripScroll = SmoothScrollController();
  final inspectorScroll = SmoothScrollController();
  final informationScroll = SmoothScrollController();
  String? currentDirectory;
  Set<String> selectedDirectories = {};
  final browseViewport = GlobalKey<BrowseViewportState>();
  bool scanning = false, maximized = false;
  bool openingEditor = false;
  bool showInfo = false;
  Completer<void>? scanFinished;
  String? lastScanError;
  int completed = 0, total = 0;
  bool get film => files.isNotEmpty && store.state(files[index].path).film;
  List<File> get targets =>
      files.where((file) => selected.contains(file.path)).toList();
  List<File> get exportFiles => switch (exportScope) {
        'selected' => files.where((f) => selected.contains(f.path)).toList(),
        'edited' => files.where((f) => store.state(f.path).edited).toList(),
        _ => files.isEmpty ? [] : [files[index]],
      };
  Future<Map<String, String>> capture(File file) {
    if (!metadata.containsKey(file.path)) {
      if (metadata.length >= 32) metadata.remove(metadata.keys.first);
      metadata[file.path] = compute(readCapture, file.path);
    }
    return metadata[file.path]!;
  }

  @override
  void initState() {
    super.initState();
    initialize();
    if (Platform.isWindows)
      DesktopWindow.channel.setMethodCallHandler((call) async {
        if (call.method == 'maximized' && mounted)
          setState(() {
            maximized = call.arguments == true;
            DesktopWindow.maximized.value = maximized;
          });
      });
  }

  Future<void> initialize() async {
    try {
      await store.load();
      try {
        await presetStore.load();
      } catch (e) {
        status = '用户预设读取失败：$e';
      }
      try {
        await workspaceSettings.load();
      } catch (e) {
        status = '布局设置读取失败：$e';
      }
      if (!mounted) return;
      workspaceSettings.changed();
      setState(() => ready = true);
      final previous = workspaceSettings.lastDirectory;
      if (previous != null && await Directory(previous).exists() && mounted)
        browseDirectory(previous);
    } catch (e) {
      if (mounted) setState(() => status = '照片记录读取失败，请保留记录文件并反馈：$e');
    }
  }

  Future<void> browseDirectory(String path) => browseDirectories({path});
  Future<void> browseDirectories(Set<String> paths) async {
    if (busy || !ready) return;
    scanner.cancel();
    if (scanFinished?.isCompleted == false) scanFinished!.complete();
    final finished = Completer<void>();
    scanFinished = finished;
    setState(() {
      selectedDirectories = {for (final p in paths) Directory(p).absolute.path};
      currentDirectory = selectedDirectories.firstOrNull;
      workspaceSettings.lastDirectory = currentDirectory;
      generation++;
      current = null;
      for (final image in previews.values) {
        image.dispose();
      }
      previews.clear();
      metadata.clear();
      files = [];
      selection.reset([]);
      failed = [];
      scanning = selectedDirectories.isNotEmpty;
      lastScanError = null;
      previewError = null;
      status = selectedDirectories.isEmpty ? '未选择目录' : '正在读取目录…';
    });
    workspaceSettings.changed();
    if (selectedDirectories.isEmpty) {
      finished.complete();
      return;
    }
    scanner.startMany(selectedDirectories,
        recursive: workspaceSettings.includeChildren,
        onBatch: receivePhotos, onError: (message) {
      lastScanError = message;
    }, onDone: (skipped) {
      if (mounted)
        setState(() {
          scanning = false;
          status =
              '共 ${files.length} 张照片${skipped == 0 ? "" : " · 跳过 $skipped 个无法读取的目录"}';
        });
      if (!finished.isCompleted) finished.complete();
    });
    await finished.future;
  }

  void receivePhotos(List<File> batch) {
    if (!mounted) return;
    setState(() {
      final oldPath = files.isEmpty ? null : files[index].path;
      final oldAnchor = files.isEmpty ? null : files[selection.anchor].path;
      files = mergePhotos(files, batch);
      if (oldPath == null) {
        selection.reset(files.map((file) => file.path).toList());
      } else {
        selection.current = files.indexWhere((file) => file.path == oldPath);
        selection.anchor = files.indexWhere((file) => file.path == oldAnchor);
      }
      status = '已发现 ${files.length} 张照片 · 正在扫描';
      // Inserting other files must not invalidate the current photo's decoder.
      if (oldPath == null) refresh();
    });
  }

  void resumeDirectoryScan(String path) {
    scanner.cancel();
    final finished = Completer<void>();
    scanFinished = finished;
    setState(() => scanning = true);
    scanner.startMany(
        selectedDirectories.isEmpty ? [path] : selectedDirectories,
        recursive: workspaceSettings.includeChildren,
        onBatch: (batch) {
          final known = files.map((f) => f.path).toSet();
          final additions = batch.where((f) => known.add(f.path)).toList();
          if (additions.isNotEmpty) receivePhotos(additions);
        },
        onError: (error) => lastScanError = error,
        onDone: (skipped) {
          if (mounted)
            setState(() {
              scanning = false;
              status = '共 ${files.length} 张照片';
            });
          if (!finished.isCompleted) finished.complete();
        });
  }

  void setRecursive(bool value) {
    workspaceSettings.includeChildren = value;
    workspaceSettings.changed();
    if (selectedDirectories.isNotEmpty)
      browseDirectories({...selectedDirectories});
  }

  Future<bool> persist() async {
    try {
      await store.save();
      return true;
    } catch (e) {
      if (mounted) setState(() => status = '本地记录保存失败：$e');
      return false;
    }
  }

  void selectPhoto(int clicked, {bool control = false, bool shift = false}) {
    setState(() {
      selection.click(files.map((file) => file.path).toList(), clicked,
          control: control, shift: shift);
      refresh();
    });
  }

  Future<void> applyPhotoStyle(StyleDocument style, Set<String> paths,
      {bool? filmValue, String? sourceId}) async {
    final previous = {
      for (final path in paths)
        path: PhotoState.fromJson(store.state(path).toJson())
    };
    for (final path in paths) {
      final state = store.state(path);
      state.style = style.copy();
      state.edited = true;
      if (filmValue != null) state.film = filmValue;
      if (sourceId != null) state.styleSource = sourceId;
    }
    if (!await persist()) {
      for (final e in previous.entries) {
        store.photos[e.key] = e.value;
      }
      if (mounted) setState(() {});
      throw StateError('样式保存失败，已恢复原状态');
    }
    if (mounted) setState(() => status = '已应用到 ${paths.length} 张照片');
  }

  Future<void> openBuiltinEditor(PresetEntry entry) async {
    if (!presetStore.authoring || busy || openingEditor) return;
    openingEditor = true;
    try {
      final fields = files.isEmpty
          ? <String, String>{}
          : store
              .state(files[index].path)
              .effective(await capture(files[index]));
      if (!mounted) return;
      await Navigator.of(context).push(WorkspaceModeRoute(
          reduceMotion: MediaQuery.disableAnimationsOf(context),
          builder: (_) => PresetEditor(
              files: List.of(files),
              current: files.isEmpty ? 0 : index,
              selected: {...selected},
              initial: entry.style.copy(),
              initialBuiltinId: entry.id,
              sourceKey: 'builtin-edit:${entry.id}',
              settings: workspaceSettings,
              presets: presetStore,
              metadata: (file) async =>
                  store.state(file.path).effective(await capture(file)),
              apply: (doc, paths) => applyPhotoStyle(doc, paths),
              initialPhoto: current,
              initialFields: fields,
              initialDirectory: currentDirectory,
              initialDirectories: selectedDirectories.toList())));
    } finally {
      openingEditor = false;
    }
  }

  Future<void> openEditor({bool blank = false}) async {
    if (files.isEmpty || busy || openingEditor) return;
    openingEditor = true;
    try {
      final source = files[index];
      final fields = store.state(source.path).effective(await capture(source));
      if (!mounted || files.isEmpty || files[index].path != source.path) return;
      final editorSourceKey = blank
          ? 'blank:${newObjectId()}'
          : store.state(source.path).editorSourceKey(source.path);
      final wasScanning = scanning;
      scanner.cancel();
      if (scanFinished?.isCompleted == false) scanFinished!.complete();
      scanning = false;
      await Navigator.of(context).push(WorkspaceModeRoute(
          reduceMotion: MediaQuery.disableAnimationsOf(context),
          builder: (_) => Stack(children: [
                PresetEditor(
                    files: List<File>.of(files),
                    current: index,
                    selected: {...selected},
                    edited: {
                      for (final f in files)
                        if (store.state(f.path).edited) f.path
                    },
                    sourceKey: editorSourceKey,
                    initial: blank
                        ? StyleDocument(name: '空白样式')
                        : (store.state(files[index].path).style?.copy() ??
                            presetStore.defaultStyle()),
                    settings: workspaceSettings,
                    presets: presetStore,
                    metadata: (file) async =>
                        store.state(file.path).effective(await capture(file)),
                    initialPhoto: current,
                    initialDirectory: currentDirectory,
                    initialDirectories: selectedDirectories.toList(),
                    initialScanning: wasScanning,
                    initialFields: fields,
                    initialPhotoScrollOffset:
                        filmstripScroll.hasClients ? filmstripScroll.offset : 0,
                    onReturn: (state) async {
                      if (!mounted) return;
                      final returnedPhoto = state.photo?.clone();
                      setState(() {
                        files = List.of(state.files);
                        currentDirectory = state.directory;
                        selectedDirectories = state.directories.isNotEmpty
                            ? state.directories.toSet()
                            : {if (state.directory != null) state.directory!};
                        selection.current = files.isEmpty
                            ? 0
                            : state.current.clamp(0, files.length - 1);
                        selection.anchor = files.isEmpty
                            ? 0
                            : state.anchor.clamp(0, files.length - 1);
                        selected
                          ..clear()
                          ..addAll(state.selected);
                        if (returnedPhoto != null && files.isNotEmpty) {
                          final path = files[index].path;
                          previews.remove(path)?.dispose();
                          previews[path] = returnedPhoto;
                        }
                        refresh();
                      });
                      await WidgetsBinding.instance.endOfFrame;
                      if (mounted && filmstripScroll.hasClients) {
                        filmstripScroll.jumpTo(state.scrollOffset.clamp(
                            0, filmstripScroll.position.maxScrollExtent));
                      }
                      if (mounted &&
                          state.scanning &&
                          state.directory != null) {
                        resumeDirectoryScan(state.directory!);
                      }
                    },
                    apply: applyPhotoStyle),
                if (Platform.isWindows) Positioned.fill(child: windowEdges())
              ])));
      if (mounted &&
          workspaceSettings.lastDirectory != null &&
          workspaceSettings.lastDirectory != currentDirectory) {
        await browseDirectory(workspaceSettings.lastDirectory!);
      }
      if (mounted) setState(() {});
    } finally {
      openingEditor = false;
    }
  }

  Future<void> editInfo() async {
    final batch = List<File>.of(targets);
    if (batch.isEmpty) return;
    setState(() => busy = true);
    final originals = <String, Map<String, String>>{};
    try {
      for (final file in batch) {
        originals[file.path] = await capture(file);
      }
      if (!mounted) return;
      final effective = batch
          .map(
              (file) => store.state(file.path).effective(originals[file.path]!))
          .toList();
      final summaries = {
        for (final key in infoFields.keys) key: InfoSummary(effective, key)
      };
      final initial =
          summaries.map((key, value) => MapEntry(key, value.initial));
      final controllers = {
        for (final key in infoFields.keys)
          key: TextEditingController(text: initial[key])
      };
      bool overwrite = false;
      String? error;
      final infoScroll = ScrollController();
      final updates = await showDialog<Map<String, String>>(
          context: context,
          builder: (ctx) => StatefulBuilder(
              builder: (ctx, update) => AlertDialog(
                      title: Text('补填 ${batch.length} 张照片'),
                      content: SizedBox(
                          width: 480,
                          height: (MediaQuery.sizeOf(ctx).height - 240)
                              .clamp(180.0, 620.0),
                          child: Scrollbar(
                              controller: infoScroll,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                  controller: infoScroll,
                                  padding: const EdgeInsets.only(right: 16),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Text(
                                            '显示已有信息。只保存改动的字段，留空跳过，默认仅补缺。'),
                                        const SizedBox(height: 20),
                                        ...infoFields.entries.map((e) {
                                          final summary = summaries[e.key]!;
                                          return Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 18),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    Text(e.value,
                                                        style: const TextStyle(
                                                            fontSize: 13)),
                                                    const SizedBox(height: 6),
                                                    TextField(
                                                        key: ValueKey(
                                                            'info-${e.key}'),
                                                        controller:
                                                            controllers[e.key],
                                                        style: const TextStyle(
                                                            fontSize: 14),
                                                        decoration:
                                                            InputDecoration(
                                                          contentPadding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      14,
                                                                  vertical: 12),
                                                          hintText:
                                                              summary.hint,
                                                        )),
                                                    const SizedBox(height: 6),
                                                    Text(summary.description,
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: Theme.of(ctx)
                                                                .hintColor)),
                                                    if (summary.values.length >
                                                        1)
                                                      ExpansionTile(
                                                          title: const Text(
                                                              '查看已有的不同值'),
                                                          children: summary
                                                              .values.entries
                                                              .map((value) => ListTile(
                                                                  dense: true,
                                                                  title: SelectableText(
                                                                      value
                                                                          .key),
                                                                  trailing: Text(
                                                                      '${value.value} 张')))
                                                              .toList()),
                                                  ]));
                                        }),
                                        CheckboxListTile(
                                            value: overwrite,
                                            onChanged: (v) =>
                                                update(() => overwrite = v!),
                                            title: const Text('主动覆盖已有内容')),
                                        if (error != null)
                                          Text(error!,
                                              style: const TextStyle(
                                                  color: Colors.red)),
                                      ])))),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('取消')),
                        FilledButton(
                            onPressed: () {
                              final values = controllers
                                  .map((k, v) => MapEntry(k, v.text.trim()));
                              values.removeWhere((key, value) =>
                                  value == initial[key] || value.isEmpty);
                              for (final e in values.entries) {
                                final problem = validateInfo(e.key, e.value);
                                if (problem != null) {
                                  update(() =>
                                      error = '${infoFields[e.key]}：$problem');
                                  return;
                                }
                              }
                              Navigator.pop(ctx, values);
                            },
                            child: const Text('保存')),
                      ])));
      if (updates != null) {
        for (final file in batch) {
          store
              .state(file.path)
              .supplement(originals[file.path]!, updates, overwrite);
        }
        final saved = await persist();
        if (mounted && saved)
          setState(() => status = '已保存 ${batch.length} 张照片的补充信息');
      }
      // 对话框退出动画结束后再释放编辑控制器。
      await Future<void>.delayed(const Duration(milliseconds: 250));
      infoScroll.dispose();
      for (final controller in controllers.values) {
        controller.dispose();
      }
    } catch (e) {
      if (mounted) setState(() => status = '读取拍摄信息失败：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget information() {
    if (files.isEmpty)
      return const Padding(
          padding: EdgeInsets.all(16), child: Text('选择照片后查看拍摄信息'));
    final file = files[index], scheme = Theme.of(context).colorScheme;
    return FutureBuilder<Map<String, String>>(
        key: ValueKey(file.path),
        future: capture(file),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Text('信息读取失败：${snapshot.error}');
          if (!snapshot.hasData)
            return const Padding(
                padding: EdgeInsets.all(12), child: Text('正在读取拍摄信息…'));
          final state = store.state(file.path),
              values = state.effective(snapshot.data!);
          String formatted(String key) {
            final text = values[key]?.trim() ?? '';
            if (text.isEmpty) return '缺失 · 可补填';
            final number = double.tryParse(text);
            final compact = number != null && number == number.roundToDouble()
                ? number.toInt().toString()
                : text;
            return switch (key) {
              'focal' => '$compact mm',
              'aperture' => 'f/$compact',
              'shutter' => '$text s',
              'time' => text.replaceFirstMapped(
                  RegExp(r'^(\d{4}):(\d{2}):(\d{2})'),
                  (m) => '${m[1]}-${m[2]}-${m[3]}'),
              _ => text
            };
          }

          Widget card(String key, String label, {bool emphasis = false}) {
            final missing = (values[key] ?? '').trim().isEmpty;
            return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Theme.of(context).inputDecorationTheme.fillColor,
                    borderRadius: BorderRadius.circular(7)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Text(label, style: EditorTypography.label(context)),
                        const Spacer(),
                        if (state.fields.containsKey(key))
                          Text('已补填',
                              style: TextStyle(
                                  fontSize: 11, color: scheme.primary))
                      ]),
                      const SizedBox(height: 7),
                      SelectableText(formatted(key),
                          style: TextStyle(
                              fontSize: emphasis && !missing ? 16 : 14,
                              fontWeight:
                                  missing ? FontWeight.w400 : FontWeight.w500,
                              color:
                                  missing ? scheme.primary : scheme.onSurface,
                              height: 1.6))
                    ]));
          }

          Widget heading(String title, String icon) => Padding(
              padding: const EdgeInsets.only(top: 22, bottom: 10),
              child: Row(children: [
                PrototypeIcon(icon, size: 17),
                const SizedBox(width: 8),
                Text(title, style: EditorTypography.title(context))
              ]));
          Widget pair(Widget left, Widget right) =>
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: left),
                const SizedBox(width: 10),
                Expanded(child: right)
              ]);
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('当前照片', style: EditorTypography.label(context)),
                const SizedBox(height: 5),
                Text(file.uri.pathSegments.last,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text('拍摄参数与已补填信息', style: EditorTypography.hint(context)),
                heading('设备', 'camera'),
                card('camera', '相机型号'),
                const SizedBox(height: 10),
                card('lens', '镜头型号'),
                heading('曝光参数', 'params'),
                pair(card('focal', '焦距', emphasis: true),
                    card('aperture', '光圈', emphasis: true)),
                const SizedBox(height: 10),
                pair(card('shutter', '快门', emphasis: true),
                    card('iso', 'ISO', emphasis: true)),
                heading('时间与地点', 'time'),
                card('time', '拍摄时间'),
                const SizedBox(height: 10),
                card('place', '地点'),
                const SizedBox(height: 18),
                TextButton.icon(
                    style: TextButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHighest,
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6))),
                    onPressed: busy || targets.isEmpty ? null : editInfo,
                    icon: const PrototypeIcon('author', size: 16),
                    label: Text('查看 / 补填选中 ${selected.length} 张信息',
                        style: const TextStyle(fontSize: 12)))
              ]);
        });
  }

  String status = '从左侧目录树选择照片目录';
  final previews = <String, ui.Image>{};
  ui.Image? current;
  String? previewError;
  int generation = 0;
  bool loading = false;

  void refresh() {
    generation++;
    current = files.isEmpty ? null : previews[files[index].path];
    previewError = null;
    if (!loading && current == null && files.isNotEmpty) loadLatest();
  }

  Future<void> loadLatest() async {
    loading = true;
    while (mounted && files.isNotEmpty && current == null) {
      final ticket = generation;
      final path = files[index].path;
      try {
        final buffer = await ui.ImmutableBuffer.fromFilePath(path);
        final codec = await ui.instantiateImageCodecWithSize(buffer,
            getTargetSize: (w, h) {
          final scale = math.min(1.0, 1200 / math.max(w, h));
          return ui.TargetImageSize(
              width: math.max(1, (w * scale).round()),
              height: math.max(1, (h * scale).round()));
        });
        late ui.Image image;
        try {
          image = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
        if (!mounted || ticket != generation) {
          image.dispose();
          continue;
        }
        if (previews.length >= 6)
          previews.remove(previews.keys.first)?.dispose();
        previews[path] = image;
        setState(() => current = image);
      } catch (e) {
        if (mounted && ticket == generation) {
          setState(() => previewError = '预览失败：$e');
          break;
        }
      }
    }
    loading = false;
  }

  @override
  void dispose() {
    scanner.cancel();
    filmstripScroll.dispose();
    inspectorScroll.dispose();
    informationScroll.dispose();
    if (scanFinished?.isCompleted == false) scanFinished!.complete();
    if (Platform.isWindows) DesktopWindow.channel.setMethodCallHandler(null);
    for (final image in previews.values) {
      image.dispose();
    }
    super.dispose();
  }

  Widget photoPreview() {
    final photo = current;
    if (photo == null)
      return Center(
          child: Text(previewError ?? (files.isEmpty ? '请选择照片目录' : '正在生成预览…')));
    // 没有设置样式的照片显示内置预设“画廊签名”，与导出、编辑页的默认样式一致。
    final style =
        store.state(files[index].path).style ?? presetStore.defaultStyle();
    final file = files[index];
    return FutureBuilder<Map<String, String>>(
        future: capture(file),
        builder: (context, snapshot) => StylePreview(
            photoPath: file.path,
            photo: photo,
            workspaceCanvas: true,
            document: style,
            fields: store.state(file.path).effective(snapshot.data ?? {})));
  }

  Future<void> open() async {
    final path = await getDirectoryPath();
    if (path != null && mounted) await browseDirectory(path);
  }

  Future<void> exportDialog() async {
    if (files.isEmpty || busy || exportPanelOpen) return;
    exportPanelOpen = true;
    try {
      final saved = await exportPreferences.load();
      if (!mounted) return;
      final options = saved.$1, template = saved.$2;
      final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => ExportDialog(
              options: options,
              template: template,
              selectedCount: selected.length,
              editedCount:
                  files.where((f) => store.state(f.path).edited).length,
              chooseDirectory: () => getDirectoryPath(
                  initialDirectory:
                      options.directory.isEmpty ? null : options.directory),
              onCancel: () => Navigator.pop(ctx, false),
              onExport: () {
                final error = options.validate();
                if (error != null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error)));
                  return;
                }
                Navigator.pop(ctx, true);
              }));
      if (proceed != true || !mounted) return;
      exportOptions = options.copy();
      exportTemplate = [
        for (final part in template)
          part.variable
              ? NamingPart.variable(part.value)
              : NamingPart.text(part.value)
      ];
      exportScope = options.scope;
      await exportPreferences.save(options, exportTemplate);
      if (mounted) await export();
    } catch (error) {
      if (mounted) setState(() => status = '导出设置失败：$error');
    } finally {
      exportPanelOpen = false;
    }
  }

  Future<void> openExportDirectory() async {
    final directory = outputDirectory;
    if (directory == null || !await Directory(directory).exists()) return;
    if (Platform.isWindows)
      await Process.run('explorer.exe', [Directory(directory).absolute.path]);
  }

  Future<void> export({bool retry = false}) async {
    if (busy) return;
    final options =
        (retry ? failedExportOptions ?? exportOptions : exportOptions).copy();
    final batch = List<File>.of(retry ? failed : exportFiles);
    if (batch.isEmpty) return;
    final errors = <String>[], missing = <String>[];
    final jobs = <ExportJob>[];
    var done = 0, wasCancelled = false;
    setState(() {
      busy = true;
      cancel = false;
      total = batch.length;
      completed = 0;
    });
    try {
      final error = options.validate();
      if (error != null) throw FormatException(error);
      if (!await Directory(options.directory).exists())
        throw const FileSystemException('输出目录不存在，请重新选择');
      outputDirectory = options.directory;
      if (retry) {
        jobs.addAll(failedExportJobs);
      } else {
        for (var i = 0; i < batch.length; i++) {
          if (cancel) break;
          final file = batch[i], state = store.state(file.path);
          Map<String, String> info;
          try {
            info = state.effective(await capture(file));
          } catch (_) {
            info = Map.of(state.fields);
          }
          final name = resolveExportName(
              exportTemplate, file.uri.pathSegments.last, info, i + 1);
          final absent = infoFields.keys
              .where((k) => k != 'place' && (info[k] ?? '').isEmpty)
              .toList();
          if (absent.isNotEmpty || name.missing.isNotEmpty) {
            missing.add('${file.uri.pathSegments.last}：${({
              ...absent.map((k) => infoFields[k]!),
              ...name.missing.map((k) => '命名变量{$k}')
            }).join('、')}');
          }
          jobs.add(ExportJob(
              file,
              (state.style ?? presetStore.defaultStyle()).copy(),
              state.film,
              Map.of(info),
              name.stem,
              '${options.directory}/${name.stem}.${options.format}'));
        }
      }
      if (cancel || !mounted) {
        wasCancelled = true;
        return;
      }
      if (missing.isNotEmpty) {
        final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => WorkspaceDialog(
                    title: Text('${missing.length} 张照片缺少信息'),
                    content: SizedBox(
                        width: 560,
                        height: 200,
                        child: SingleChildScrollView(
                            child: Text(
                                '${missing.join('\n')}\n\n缺失的画布组件不输出；缺失命名变量使用“未填写”。'))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('返回补填')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('继续导出'))
                    ]));
        if (proceed != true) {
          wasCancelled = true;
          return;
        }
      }
      // Protect source paths, including symbolic links. Publishing via rename also avoids modifying hard-linked source pixels.
      final protectedPaths = <String>{};
      for (final source in files) {
        protectedPaths.add(exportPathKey(source.path));
        try {
          protectedPaths
              .add(exportPathKey(await source.resolveSymbolicLinks()));
        } catch (_) {}
      }
      final duplicates = <String>{}, seen = <String>{}, collisions = <String>{};
      for (final job in jobs) {
        final key = exportPathKey(job.target);
        if (!seen.add(key)) duplicates.add(key);
        final target = File(job.target);
        job.replacedStat = null;
        if (await target.exists()) {
          job.replacedStat = await target.stat();
          collisions.add(target.uri.pathSegments.last);
        }
        if (duplicates.contains(key))
          collisions.add(target.uri.pathSegments.last);
      }
      var choice = ExportConflictChoice.keepAll;
      if (collisions.isNotEmpty && mounted) {
        choice = await showDialog<ExportConflictChoice>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => ExportConflictDialog(
                    filenames: collisions.toList(),
                    canReplace: duplicates.isEmpty,
                    onChoose: (value) => Navigator.pop(ctx, value))) ??
            ExportConflictChoice.cancel;
        if (choice == ExportConflictChoice.cancel) {
          wasCancelled = true;
          return;
        }
      }
      if (cancel || !mounted) {
        wasCancelled = true;
        return;
      }
      final reserved = <String>{...protectedPaths};
      for (final job in jobs) {
        if (choice == ExportConflictChoice.keepAll) {
          job.target = await unusedExportPath(
              options.directory, job.stem, options.format, reserved);
          job.replacedStat = null;
        } else {
          final path = File(job.target);
          String? real;
          if (await path.exists()) {
            try {
              real = await path.resolveSymbolicLinks();
            } catch (_) {}
          }
          if (protectedPaths.contains(exportPathKey(job.target)) ||
              real != null && protectedPaths.contains(exportPathKey(real))) {
            throw const FileSystemException('输出目标是原照片，已停止替换；请更换命名或选择全部保留');
          }
        }
      }
      failed = [];
      failedExportJobs = [];
      failedExportOptions = options.copy();
      for (final job in jobs) {
        if (cancel) {
          wasCancelled = true;
          break;
        }
        setState(() => status = '正在导出 ${completed + 1}/$total');
        try {
          final managed = await decodeSrgbPhoto(job.source.path);
          if (cancel) {
            wasCancelled = true;
            break;
          }
          late List<int> data;
          if (job.style == null) {
            data = await compute(renderLegacyExport, (
              managed.rgba,
              managed.width,
              managed.height,
              job.film,
              job.source.path,
              job.fields,
              options,
              managed.profile
            ));
          } else {
            final photo = await managed.image();
            try {
              data = await renderStyledPhoto(job.source.path, job.style!,
                  job.fields, options.format == 'png',
                  options: options,
                  managedPhoto: photo,
                  srgbProfile: managed.profile);
            } finally {
              photo.dispose();
            }
          }
          if (cancel) {
            wasCancelled = true;
            break;
          }
          await publishExport(job, data,
              replace: choice == ExportConflictChoice.replace);
          done++;
        } catch (error) {
          failed.add(job.source);
          failedExportJobs.add(job);
          errors.add('${job.source.uri.pathSegments.last}：$error');
        }
        if (mounted) setState(() => completed++);
      }
      if (errors.isNotEmpty && mounted) {
        await showDialog<void>(
            context: context,
            builder: (ctx) => WorkspaceDialog(
                    title: Text('失败 ${failed.length} 张'),
                    content: SizedBox(
                        width: 560,
                        height: 200,
                        child: SingleChildScrollView(
                            child: SelectableText(errors.join('\n')))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('关闭'))
                    ]));
      }
    } catch (error) {
      errors.add('$error');
    } finally {
      if (mounted)
        setState(() {
          busy = false;
          status =
              '${wasCancelled || cancel ? '已取消' : '本次结束'}，成功 $done 张，失败 ${errors.isNotEmpty && failed.isEmpty ? errors.length : failed.length} 张${errors.isNotEmpty && failed.isEmpty ? '：${errors.first}' : ''}';
        });
    }
  }

  Widget neutralButton(String text, VoidCallback? action) => TextButton(
      style: TextButton.styleFrom(
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest),
      onPressed: action,
      child: Text(text, style: const TextStyle(fontSize: 13)));

  Widget header() => WorkspaceHeader(
      settings: workspaceSettings,
      editing: false,
      onBrowse: () {},
      onEdit: busy || files.isEmpty ? null : openEditor,
      beforeClose: () async {
        await workspaceSettings.save();
        return persist();
      });

  Widget stage() => Column(children: [
        SizedBox(
            height: 42,
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          files.isEmpty
                              ? '请选择照片'
                              : files[index].uri.pathSegments.last,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: .60)))),
                  if (files.isNotEmpty)
                    Text(
                        store.state(files[index].path).style?.name ??
                            (film ? '胶片档案' : '画廊签名'),
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).hintColor)),
                ]))),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 8, 30, 18),
                child: BrowseViewport(
                    key: browseViewport,
                    child: Center(child: photoPreview())))),
        SizedBox(
            height: 33,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(
                  onPressed: () => browseViewport.currentState?.reset(),
                  child: Text('适合窗口',
                      style: TextStyle(
                          fontSize: 12, color: Theme.of(context).hintColor))),
              Text('Alt 滚轮 · 空格拖动',
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).hintColor)),
            ])),
      ]);

  Widget filmstrip() => WorkspaceFilmstrip(
      notice: '修改将应用到选中 ${selected.length} 张',
      files: files,
      selected: selected,
      current: index,
      controller: filmstripScroll,
      enabled: !busy,
      edited: {
        for (final f in files)
          if (store.state(f.path).edited) f.path
      },
      onSelect: (i, control, shift) =>
          selectPhoto(i, control: control, shift: shift),
      onSelectAll: () =>
          setState(() => selected.addAll(files.map((f) => f.path))),
      onClear: () => setState(() => selected.clear()));

  Widget inspector() {
    final scheme = Theme.of(context).colorScheme;
    String? activePreset;
    if (files.isNotEmpty) {
      final currentStyle = store.state(files[index].path).style;
      if (currentStyle != null) {
        final signature = jsonEncode(currentStyle.toJson());
        for (final p in presetStore.presets) {
          if (jsonEncode(p.style.toJson()) == signature) {
            activePreset = 'user:${p.id}';
            break;
          }
        }
      }
      activePreset ??= currentStyle == null
          ? (film ? 'film' : 'gallery')
          : currentStyle.name == '画廊签名'
              ? 'gallery'
              : currentStyle.name == '胶片档案'
                  ? 'film'
                  : null;
    }

    return LayoutBuilder(
        builder: (context, box) => Column(children: [
              PrototypeTabs(
                  labels: const ['预设', '信息'],
                  selected: showInfo ? 1 : 0,
                  expand: true,
                  onSelect: (i) => setState(() => showInfo = i == 1)),
              Expanded(
                  child: showInfo
                      ? SmoothScroll(
                          controller: informationScroll,
                          child: Scrollbar(
                              controller: informationScroll,
                              child: SingleChildScrollView(
                                  key: const PageStorageKey(
                                      'browse-information'),
                                  controller: informationScroll,
                                  padding:
                                      const EdgeInsets.fromLTRB(18, 18, 18, 22),
                                  child: information())))
                      : FutureBuilder<Map<String, String>>(
                          future: files.isEmpty ? null : capture(files[index]),
                          builder: (context, snapshot) => PresetPanel(
                              store: presetStore,
                              onEditBuiltin: presetStore.authoring
                                  ? openBuiltinEditor
                                  : null,
                              settings: workspaceSettings,
                              photo: current,
                              photoPath:
                                  files.isEmpty ? null : files[index].path,
                              activeId: activePreset,
                              fields: files.isEmpty
                                  ? const {}
                                  : store
                                      .state(files[index].path)
                                      .effective(snapshot.data ?? {}),
                              enabled: !busy,
                              canApply: ready && targets.isNotEmpty,
                              onNew: files.isEmpty
                                  ? null
                                  : () => openEditor(blank: true),
                              onApply: (entry) => applyPhotoStyle(entry.style,
                                  targets.map((f) => f.path).toSet(),
                                  sourceId: entry.id,
                                  filmValue: entry.id == 'film'
                                      ? true
                                      : entry.id == 'gallery'
                                          ? false
                                          : null)))),
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: scheme.surface, boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: .12),
                        blurRadius: 12,
                        offset: const Offset(0, -4))
                  ]),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (busy) ...[
                          if (total > 0)
                            LinearProgressIndicator(value: completed / total),
                          TextButton(
                              onPressed: () => setState(() {
                                    cancel = true;
                                    status = '正在取消，完成当前处理后停止';
                                  }),
                              child: const Text('取消导出')),
                        ] else
                          FilledButton(
                              onPressed:
                                  files.isEmpty || !ready ? null : exportDialog,
                              child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('导出照片'),
                                    Text('${selected.length} 张 →')
                                  ])),
                        if (outputDirectory != null)
                          TextButton(
                              onPressed: openExportDirectory,
                              child: const Text('打开输出目录')),
                        if (failed.isNotEmpty)
                          TextButton(
                              onPressed:
                                  busy ? null : () => export(retry: true),
                              child: Text('重试失败 ${failed.length} 张')),
                        const SizedBox(height: 7),
                        Text('生成新文件 · 默认移除 GPS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).hintColor)),
                      ])),
            ]));
  }

  Widget windowEdges() {
    Widget edge(String name, MouseCursor cursor,
            {double? left,
            double? right,
            double? top,
            double? bottom,
            double? width,
            double? height}) =>
        Positioned(
            left: left,
            right: right,
            top: top,
            bottom: bottom,
            width: width,
            height: height,
            child: MouseRegion(
                cursor: cursor,
                child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) =>
                        DesktopWindow.action('resize', name))));
    return Stack(children: [
      edge('left', SystemMouseCursors.resizeLeftRight,
          left: 0, top: 6, bottom: 6, width: 5),
      edge('right', SystemMouseCursors.resizeLeftRight,
          right: 0, top: 6, bottom: 6, width: 5),
      edge('top', SystemMouseCursors.resizeUpDown,
          top: 0, left: 6, right: 6, height: 5),
      edge('bottom', SystemMouseCursors.resizeUpDown,
          bottom: 0, left: 6, right: 6, height: 5),
      edge('topLeft', SystemMouseCursors.resizeUpLeftDownRight,
          top: 0, left: 0, width: 7, height: 7),
      edge('topRight', SystemMouseCursors.resizeUpRightDownLeft,
          top: 0, right: 0, width: 7, height: 7),
      edge('bottomLeft', SystemMouseCursors.resizeUpRightDownLeft,
          bottom: 0, left: 0, width: 7, height: 7),
      edge('bottomRight', SystemMouseCursors.resizeUpLeftDownRight,
          bottom: 0, right: 0, width: 7, height: 7),
    ]);
  }

  @override
  Widget build(BuildContext context) => Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent ||
            PresetPanel.keyboardActive ||
            DirectoryPanel.keyboardActive ||
            busy ||
            files.isEmpty ||
            FocusManager.instance.primaryFocus?.context
                    ?.findAncestorWidgetOfExactType<EditableText>() !=
                null) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.keyD &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          setState(() => selected.clear());
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.keyA &&
            HardwareKeyboard.instance.isControlPressed) {
          setState(() => selected.addAll(files.map((file) => file.path)));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowRight) {
          final next = (index +
                  (event.logicalKey == LogicalKeyboardKey.arrowRight ? 1 : -1))
              .clamp(0, files.length - 1);
          selectPhoto(next,
              control: HardwareKeyboard.instance.isControlPressed,
              shift: HardwareKeyboard.instance.isShiftPressed);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(body: LayoutBuilder(builder: (ctx, size) {
        final width = math.max(1000.0, size.maxWidth),
            height = math.max(640.0, size.maxHeight);
        return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                    child: SizedBox(
                        height: height,
                        child: Stack(children: [
                          Column(children: [
                            Expanded(
                                child: Padding(
                                    padding: const EdgeInsets.only(top: 54),
                                    child: WorkspaceLayout(
                                        settings: workspaceSettings,
                                        library: DirectoryPanel(
                                            currentPath: currentDirectory,
                                            selectedPaths: selectedDirectories,
                                            onSelectMany: browseDirectories,
                                            includeChildren: workspaceSettings
                                                .includeChildren,
                                            enabled: ready && !busy,
                                            scanning: scanning,
                                            count: files.length,
                                            onSelect: browseDirectory,
                                            onRecursive: setRecursive,
                                            onChooseDirectory: open),
                                        stage: stage(),
                                        inspector: inspector(),
                                        filmstrip: filmstrip()))),
                            SizedBox(
                                height: 28,
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14),
                                    child: Row(children: [
                                      Text('● 本地工作台',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  Theme.of(context).hintColor)),
                                      const SizedBox(width: 18),
                                      Expanded(
                                          child: Tooltip(
                                              message: lastScanError ??
                                                  workspaceSettings.saveError ??
                                                  status,
                                              child: Text(
                                                  workspaceSettings.saveError ??
                                                      status,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context)
                                                          .hintColor)))),
                                    ]))),
                          ]),
                          Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: ListenableBuilder(
                                  listenable: workspaceSettings,
                                  builder: (context, _) => header())),
                          if (Platform.isWindows)
                            Positioned.fill(child: windowEdges()),
                        ])))));
      })));
}
