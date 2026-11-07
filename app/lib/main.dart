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
import 'photo_relink.dart';import 'directory_browser.dart';
import 'workspace_settings.dart';
import 'window_controls.dart';
import 'export/export_options.dart';
import 'export/export_naming.dart';
import 'export/export_preferences.dart';
import 'export/export_task.dart';
import 'export/export_recovery.dart';
import 'export/color_management.dart';
import 'ui/export/export_dialog.dart';
import 'ui/heif_store_buttons.dart';
import 'ui/photo_info_form.dart';
import 'ui/relink_dialog.dart';
import 'ui/export/export_conflict_dialog.dart';
import 'ui/workspace_dialog.dart';
import 'ui/app_theme.dart';
import 'ui/settings_dialog.dart';
import 'ui/place_picker.dart';
import 'settings/app_settings_singleton.dart';
import 'settings/place_lookup.dart';
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
  final folderWatch = PhotoFolderWatch();
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
      metadata[file.path] = compute(readCapture, file.path).then((info) {
        rememberCaptureTime(file.path, info);
        return info;
      });
    }
    return metadata[file.path]!;
  }

  /// Keeps the capture time in the record so a moved file can be recognised
  /// by name plus time even after it leaves this folder.
  void rememberCaptureTime(String path, Map<String, String> info) {
    final time = (info['time'] ?? '').trim();
    if (time.isEmpty) return;
    final state = store.state(path);
    if (state.captureTime == time) return;
    state.captureTime = time;
    unawaited(persist());
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
      try {
        await appSettings.load();
      } catch (e) {
        status = '软件设置读取失败：$e';
      }
      if (!mounted) return;
      workspaceSettings.changed();
      setState(() => ready = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showExportRecovery();
      });
      final previous = workspaceSettings.lastDirectory;
      if (previous != null && await Directory(previous).exists() && mounted)
        browseDirectory(previous);
    } catch (e) {
      if (mounted) setState(() => status = '照片记录读取失败，请保留记录文件并反馈：$e');
    }
  }

  Future<void> showExportRecovery() async {
    final store = ExportRecoveryStore.standard();
    // Report an unfinished batch either way: closing the window in the middle
    // of an export also leaves work undone, and the choice is the user's.
    final pending = await store.readInterrupted();
    if (pending == null || !mounted) return;
    final closed = await store.closedByUser();
    if (!mounted) return;
    // Photos that already failed once are skipped on resume, so a photo that
    // cannot be exported never puts the batch into a loop.
    final resume = pending.canResume
        ? await showDialog<bool>(
            context: context,
            // Every panel here closes when the dimmed area is clicked; closing
            // this one means "not now", which is the same as the left button.
            barrierDismissible: true,
            builder: (ctx) => WorkspaceDialog(
                    title: const Text('上次导出没有完成'),
                    content: SizedBox(
                        width: 560,
                        child: Text(exportRecoveryMessage(pending,
                            closedByUser: closed))),
                    actions: [
                      WorkspaceActionButton(
                          label: '暂不导出',
                          onPressed: () => Navigator.pop(ctx, false)),
                      WorkspaceActionButton(
                          label: '继续导出剩下的 ${pending.pending.length} 张',
                          onPressed: () => Navigator.pop(ctx, true))
                    ]))
        : null;
    if (resume == true && mounted) {
      await continueExport(pending);
      return;
    }
    await store.clear();
  }

  /// Carries on a batch left behind by a crash. The photo that was being
  /// handled when it stopped is skipped: it is the most likely cause, and
  /// retrying it would stop the batch again.
  Future<void> continueExport(ExportRecovery note) async {
    final options = note.options;
    if (options == null) return;
    final noteStore = ExportRecoveryStore.standard();
    final rest = resumableJobs(note,
        exists: (path) => File(path).existsSync());
    final jobs = <ExportJob>[];
    for (final job in rest) {
      final state = store.state(job.source);
      jobs.add(ExportJob(File(job.source), state.style?.copy(), state.film,
          Map.of(state.fields), job.stem, job.target));
    }
    await noteStore.clear();
    if (jobs.isEmpty) {
      if (mounted)
        setState(() => status = '上次中断的那张已跳过，剩下没有需要继续导出的照片');
      return;
    }
    if (!mounted) return;
    exportOptions = options.copy();
    await runExportJobs(jobs, options);
  }

  Future<void> browseDirectory(String path) => browseDirectories({path});
  Future<void> browseDirectories(Set<String> paths) async {
    if (busy || !ready) return;
    scanner.cancel();
    folderWatch.stop();
    _verifyTimer?.cancel();
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
      unawaited(relinkAfterScan());
      startFolderWatch();
    });
    await finished.future;
  }

  /// Keeps the folder list in step with the disk: a photo copied in or deleted
  /// while the app is open shows up without switching folders.
  ///
  /// The OS notification is unreliable for deletions (a move to the recycle
  /// bin can raise nothing on Windows), so a light check runs on a timer as
  /// well. The check only lists folder entries; photos are re-read only when
  /// the set of files actually changed.
  void startFolderWatch() {
    if (selectedDirectories.isEmpty) return;
    unawaited(folderWatch.start(selectedDirectories,
        recursive: workspaceSettings.includeChildren,
        onChanged: () {
          if (!mounted || busy) return;
          refreshDirectorySoon();
        }));
    _verifyTimer?.cancel();
    _verifyTimer = Timer.periodic(verifyInterval, (_) {
      if (!mounted || busy || scanning) return;
      if (selectedDirectories.isEmpty) return;
      unawaited(verifyDirectory());
    });
  }

  Timer? _verifyTimer;

  /// Compares the folder with the list on screen and refreshes only on a real
  /// difference, so the 2-second check costs almost nothing.
  Future<void> verifyDirectory() async {
    if (selectedDirectories.isEmpty) return;
    final current = files.map((f) => exportPathKey(f.path)).toSet();
    final found = <String>{};
    for (final root in selectedDirectories) {
      try {
        await for (final entity in Directory(root).list(
            recursive: workspaceSettings.includeChildren,
            followLinks: false)) {
          if (entity is File && photoFilePattern.hasMatch(entity.path))
            found.add(exportPathKey(entity.path));
        }
      } catch (_) {}
    }
    if (!mounted) return;
    if (found.length == current.length && found.every(current.contains)) return;
    await rescanCurrentDirectories();
  }

  Timer? _refreshTimer;

  /// Coalesces bursts: copying or deleting a folder fires many events.
  void refreshDirectorySoon() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || busy || selectedDirectories.isEmpty) return;
      rescanCurrentDirectories();
    });
  }

  /// Re-reads the folders on screen and makes the list match the disk, so a
  /// photo added or removed outside the app shows up immediately.
  ///
  /// Everything the user filled in lives in the record store, not in `files`,
  /// so the selection is kept when its photo still exists. If the current
  /// photo was deleted, the nearest remaining photo takes over and the status
  /// line says how many disappeared, instead of silently showing a gap.
  Future<void> rescanCurrentDirectories() async {
    if (selectedDirectories.isEmpty) return;
    final previous = files.map((f) => f.path).toList();
    final previousCurrent = files.isEmpty ? null : files[index].path;
    final previousSelected = {...selected};
    final result = await scanner.collect(selectedDirectories,
        recursive: workspaceSettings.includeChildren);
    if (!mounted) return;
    final found = result.files;
    if (found.isEmpty && result.skipped > 0) return;
    // Compare the actual set of paths, not just the count: deleting one photo
    // and adding another keeps the count the same but changes the list.
    final previousSet = previous.map(exportPathKey).toSet();
    final foundSet = found.map((f) => exportPathKey(f.path)).toSet();
    final missing = previous
        .where((path) => !foundSet.contains(exportPathKey(path)))
        .toList();
    final added =
        found.where((f) => !previousSet.contains(exportPathKey(f.path))).toList();
    if (missing.isEmpty && added.isEmpty) return;
    setState(() {
      files = found;
      final paths = files.map((f) => f.path).toSet();
      selection.reset(files.map((f) => f.path).toList());
      final kept = previousSelected.where(paths.contains).toSet();
      if (kept.isNotEmpty) {
        selection.paths
          ..clear()
          ..addAll(kept);
        final restored = files.indexWhere((f) => f.path == previousCurrent);
        selection.current = restored >= 0
            ? restored
            : files.indexWhere((f) => kept.contains(f.path));
        selection.anchor = selection.current;
      }
      if (kept.isEmpty && files.isNotEmpty) selection.current = 0;
      if (missing.isNotEmpty) {
        final deleted = missing.length;
        status =
            '共 ${files.length} 张照片 · $deleted 张已不在文件夹里，已从列表移除';
      } else {
        status = '共 ${files.length} 张照片';
      }
      current = files.isEmpty ? null : previews[files[index].path];
    });
    if (current == null && files.isNotEmpty) refresh();
  }

  /// Called once a folder scan settles. Records of photos that are no longer
  /// in the folder are matched by file name plus capture time. Only when both
  /// match is a record carried over, so a same-named photo from another shoot
  /// is never taken over silently.
  Future<void> relinkAfterScan() async {
    if (files.isEmpty || busy || selectedDirectories.isEmpty) return;
    final current = files.map((f) => f.path).toSet();
    // Fingerprints first: a renamed or swapped file must be noticed before
    // anything else, otherwise its record stays with the wrong picture.
    final fingerprints = <String, String>{};
    for (final file in List<File>.of(files)) {
      try {
        fingerprints[file.path] = photoFingerprint(file.path);
      } catch (_) {}
    }
    var changed = false;
    final followed = followContent(
        records: store.photos, fingerprintsByPath: fingerprints);
    if (applyMoves(store.photos, followed)) changed = true;
    for (final file in files) {
      final state = store.photos[file.path];
      final print = fingerprints[file.path];
      if (state == null || print == null) continue;
      if (state.fingerprint == print) continue;
      state.fingerprint = print;
      if (state.hasContent) changed = true;
    }
    if (changed) await persist();
    final records =
        pendingRecords(records: store.photos, currentPaths: current);
    final times = <String, String>{};
    final matched = <({String from, String to})>[];
    if (records.isNotEmpty) {
      // Read times without writing records here: storing them first would
      // give the moved photo a record of its own and block the relink.
      for (final file in List<File>.of(files)) {
        try {
          if (await file.length() > 64 * 1024 * 1024) continue;
          final info = await compute(readCapture, file.path);
          times[file.path] = (info['time'] ?? '').trim();
        } catch (_) {}
      }
      var moved = false;
      for (final record in records) {
        final time = await _recordTime(record.oldPath, record.captureTime);
        if (time.isEmpty) continue;
        final match = findRelinkedPath(
            record: PendingRecord(record.oldPath, record.fileName, time,
                edited: record.edited),
            timesByPath: times);
        if (match == null) continue;
        if (store.relink(record.oldPath, match)) {
          times.remove(match);
          moved = true;
          matched.add((from: record.oldPath, to: match));
        }
      }
      if (moved) {
        for (final entry in times.entries) {
          final state = store.photos[entry.key];
          if (state != null && entry.value.isNotEmpty)
            state.captureTime = entry.value;
        }
      }
    }
    final remaining = pendingRecords(
        records: store.photos, currentPaths: current, timesByPath: times);
    if (records.isNotEmpty) await persist();
    final automatic = [
      for (final move in followed) (from: move.from, to: move.to),
      ...matched
    ];
    if (!mounted) return;
    setState(() {
      pendingRelink = remaining;
      if (automatic.isNotEmpty) autoRelinked = automatic;
      status = remaining.isEmpty
          ? '共 ${files.length} 张照片'
          : '共 ${files.length} 张照片 · ${remaining.length} 张记录待重新关联';
    });
  }

  /// Explains what the app matched on its own, naming both sides so the user
  /// can check it without hunting.
  Future<void> showAutoRelink() async {
    if (autoRelinked.isEmpty || !mounted) return;
    await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => WorkspaceDialog(
                title: Text('已自动关联 ${autoRelinked.length} 张照片'),
                content: SizedBox(
                    width: 560,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                              '这些照片移动或改过名，软件按文件名和拍摄时间认了出来，'
                              '套用的预设和补填的信息都已跟着照片接回，不需要再做操作。',
                              style: dialogBodyStyle.copyWith(fontSize: 12)),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: DecoratedBox(
                                  decoration: BoxDecoration(
                                      color: Theme.of(ctx)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(6)),
                                  child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6, horizontal: 8),
                                      itemCount: autoRelinked.length,
                                      itemBuilder: (_, i) {
                                        final pair = autoRelinked[i];
                                        return Padding(
                                            padding: const EdgeInsets
                                                .symmetric(vertical: 3),
                                            child: Row(children: [
                                              Icon(Icons.check_circle_outline,
                                                  size: 13,
                                                  color: Theme.of(ctx)
                                                      .colorScheme
                                                      .primary),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                  child: Text(
                                                      '${recordFileName(pair.from)}'
                                                      '  →  '
                                                      '${recordFileName(pair.to)}',
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                      style: dialogBodyStyle
                                                          .copyWith(
                                                              fontSize: 12)))
                                            ]));
                                      })))
                        ])),
                actions: [
                  WorkspaceActionButton(
                      label: '知道了',
                      onPressed: () => Navigator.pop(ctx))
                ]));
    if (mounted) setState(() => autoRelinked = const []);
  }

  /// Runs the same matching pass again after the user picked a folder, so a
  /// manual pick can settle a whole group of moved photos at once.
  Future<void> retryRelink() async {
    if (files.isEmpty || busy) return;
    await relinkAfterScan();
  }

  /// Capture time of a pending record. Old records saved before times were
  /// stored are read from the file if it still exists.
  Future<String> _recordTime(String oldPath, String? known) async {
    if (known != null && known.isNotEmpty) return known;
    if (!await File(oldPath).exists()) return '';
    try {
      final info = await compute(readCapture, oldPath);
      return (info['time'] ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  /// Lets the user pick the pairs that automatic matching could not settle.
  Future<void> openRelink() async {
    if (files.isEmpty || busy) return;
    if (pendingRelink.isEmpty) {
      // Nothing is lost right now. Point this out instead of opening an empty
      // panel, since the button is always available.
      setState(() => status = '当前文件夹的照片都有记录，没有待关联的照片');
      return;
    }
    final available = files
        .where((f) {
          final record = store.photos[f.path];
          return record == null || !record.hasContent;
        })
        .toList();
    final done = await showRelinkDialog(context,
        pending: List.of(pendingRelink),
        available: available,
        folderLabel: selectedDirectories.isEmpty
            ? '当前文件夹'
            : selectedDirectories.map((p) => recordFileName(p)).join('、'),
        onLink: (oldPath, newPath) {
          final accepted = store.relink(oldPath, newPath);
          if (accepted) {
            try {
              store.photos[newPath]!.fingerprint = photoFingerprint(newPath);
            } catch (_) {}
          }
          return accepted;
        },
        onDone: persist);
    if (!mounted) return;
    final remaining = pendingRecords(
        records: store.photos,
        currentPaths: files.map((f) => f.path).toSet());
    setState(() {
      pendingRelink = remaining;
      status = done == 0
          ? '共 ${files.length} 张照片'
          : '已关联 $done 张 · 共 ${files.length} 张照片'
              '${remaining.isEmpty ? '' : ' · 还有 ${remaining.length} 张待关联'}';
    });
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

  Future<void> savePhotoField(String path, String key, String value) async {
    final state = store.state(path);
    final text = value.trim();
    if (text.isEmpty) {
      state.fields.remove(key);
    } else {
      state.fields[key] = text;
    }
    await store.save();
    // The record changed, so anything showing it has to be rebuilt: without
    // this the info panel kept showing the old value after a place was picked.
    if (mounted) setState(() {});
  }

  Future<void> savePhotoPlace(String path, String value) =>
      savePhotoField(path, 'place', value);

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
              onSavePlace: savePhotoPlace,
              onSaveField: savePhotoField,
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
                    onSavePlace: savePhotoPlace,
                    onSaveField: savePhotoField,
                    relinkCount: pendingRelink.length,
                    onRelink: openRelink,
                    autoRelinkCount: autoRelinked.length,
                    onShowAutoRelink: showAutoRelink,
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
                if (Platform.isWindows && !maximized)
                  Positioned.fill(child: windowEdges())
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
          final state = store.state(file.path);
          final fromFile = snapshot.data!;
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
                const SizedBox(height: 16),
                PhotoInfoForm(
                    key: ValueKey('browse-info-${file.path}'),
                    existing: fromFile,
                    manual: state.fields,
                    compact: true,
                    onPickPlace: () => pickPlaceFor(file.path),
                    onChanged: (key, value) =>
                        savePhotoField(file.path, key, value)),
                const SizedBox(height: 12),
                Text(
                    selected.length > 1
                        ? '已选 ${selected.length} 张。这里填写只作用于当前这张照片，'
                            '其他照片的信息请逐张查看。'
                        : '这里填写只作用于当前这张照片。',
                    style: EditorTypography.hint(context))
              ]);
        });
  }

  String status = '从左侧目录树选择照片目录';
  final previews = <String, ui.Image>{};
  ui.Image? current;
  String? previewError;
  List<PendingRecord> pendingRelink = const [];

  /// Pairs that were matched automatically on the last scan, kept so the bar
  /// can tell the user it happened. Cleared once they have seen it.
  List<({String from, String to})> autoRelinked = const [];
  int generation = 0;
  bool loading = false;

  void refresh() {
    generation++;
    current = files.isEmpty ? null : previews[files[index].path];
    previewError = null;
    if (!loading && current == null && files.isNotEmpty) loadLatest();
    unawaited(autoFillPlaceForCurrent());
  }

  /// Looks up the place for the photo on screen when it needs one.
  ///
  /// Runs only when the preset really shows a place, the photo carries
  /// coordinates, and nothing was typed by hand — see [PlaceLookup.fill].
  Future<void> autoFillPlaceForCurrent() async {
    final lookup = PlaceLookup(settings: appSettings);
    while (mounted && files.isNotEmpty) {
      final path = files[index].path;
      final state = store.state(path);
      final style = state.style ?? presetStore.defaultStyle();
      final info = await capture(files[index]);
      if (!mounted || files.isEmpty || files[index].path != path) return;
      final place = await lookup.fill(
          info: info,
          nodeTypes: style.nodes.map((n) => n.type),
          existing: state.fields['place'] ?? '');
      if (place == null || !mounted) return;
      if (files.isEmpty || files[index].path != path) return;
      final current = store.state(path);
      if ((current.fields['place'] ?? '').trim().isNotEmpty) return;
      await savePhotoField(path, 'place', place);
      if (!mounted) return;
      setState(() => status = '已根据照片坐标填入地点：$place');
      return;
    }
  }

  Future<void> loadLatest() async {
    loading = true;
    while (mounted && files.isNotEmpty && current == null) {
      final ticket = generation;
      final path = files[index].path;
      try {
        final image = await decodePhotoImage(path, maxEdge: 1200);
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
          setState(() => previewError =
              e is PhotoDecodeException ? e.message : '预览失败：$e');
          break;
        }
      }
    }
    loading = false;
  }

  @override
  void dispose() {
    scanner.cancel();
    folderWatch.stop();
    _refreshTimer?.cancel();
    _verifyTimer?.cancel();
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
    if (photo == null) {
      final message =
          previewError ?? (files.isEmpty ? '请选择照片目录' : '正在生成预览…');
      return Center(
          child: previewError != null && asksForHeifCodec(previewError!)
              ? HeifInstallNotice(message)
              : Text(message));
    }
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
      failed = [];
      failedExportJobs = [];
      failedExportOptions = options.copy();
      var choice = ExportConflictChoice.keepAll;
      if (collisions.isNotEmpty && mounted) {
        choice = await showDialog<ExportConflictChoice>(
                context: context,
                // Clicking the dimmed area means "cancel": same as the close
                // button and the same as every other panel in the app.
                barrierDismissible: true,
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
      // Skipping a conflicting photo means it is not part of this batch at
      // all: the photo already in the output folder stays untouched.
      final toExport = <ExportJob>[];
      for (final job in jobs) {
        if (choice == ExportConflictChoice.skipExisting &&
            await File(job.target).exists()) continue;
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
        toExport.add(job);
      }
      final skippedExisting = jobs.length - toExport.length;
      failed = [];
      failedExportJobs = [];
      failedExportOptions = options.copy();
      final outcome = await runExportJobs(toExport, options,
          replace: choice == ExportConflictChoice.replace);
      done = outcome.done;
      wasCancelled = outcome.cancelled;
      if (skippedExisting > 0 && mounted && !wasCancelled)
        setState(() =>
            status = '已跳过 $skippedExisting 张同名照片 · 导出 $done 张，共 ${jobs.length} 张');
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

  /// Runs one batch, keeping a progress note on disk so a crash can be
  /// resumed. Already exported photos are never repeated, and a photo that
  /// failed once is never retried automatically.
  Future<({int done, bool cancelled})> runExportJobs(
      List<ExportJob> jobs, ExportOptions options,
      {bool replace = false}) async {
    final noteStore = ExportRecoveryStore.standard();
    final errors = <String>[];
    var done = 0;
    var cancelled = false;
    final skipped = <String>{};
    setState(() {
      busy = true;
      cancel = false;
      total = jobs.length;
      completed = 0;
    });
    try {
      for (var index = 0; index < jobs.length; index++) {
        final job = jobs[index];
        if (cancel) {
          cancelled = true;
          break;
        }
        setState(() => status = '正在导出 ${index + 1}/${jobs.length}');
        final noteName = job.source.uri.pathSegments.last;
        final rest = [
          for (final later in jobs.skip(index + 1))
            RecoveryJob(later.source.path, later.target, later.stem)
        ];
        try {
          await noteStore.write(ExportRecovery(noteName,
              pending: [
                RecoveryJob(job.source.path, job.target, job.stem),
                ...rest
              ],
              completed: done,
              skipped: skipped.toList(),
              options: options));
        } catch (_) {}
        try {
          final managed = await openForExport(job.source.path, options);
          try {
            await noteStore.write(ExportRecovery(noteName,
                width: managed.width,
                height: managed.height,
                pending: [
                  RecoveryJob(job.source.path, job.target, job.stem),
                  ...rest
                ],
                completed: done,
                skipped: skipped.toList(),
                options: options));
          } catch (_) {}
          if (cancel) {
            cancelled = true;
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
            cancelled = true;
            break;
          }
          await publishExport(job, data, replace: replace);
          done++;
        } catch (error) {
          failed.add(job.source);
          failedExportJobs.add(job);
          skipped.add(job.source.path);
          errors.add('$noteName：$error');
        }
        if (mounted) setState(() => completed++);
      }
      if (errors.isNotEmpty && mounted) {
        await showDialog<void>(
            context: context,
            barrierDismissible: true,
            builder: (ctx) => WorkspaceDialog(
                    title: Text('失败 ${failed.length} 张'),
                    content: SizedBox(
                        width: 560,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                  height: 160,
                                  child: SingleChildScrollView(
                                      child: SelectableText(errors.join('\n')))),
                              if (errors.any(asksForHeifCodec)) ...[
                                const SizedBox(height: 16),
                                const HeifStoreButtons()
                              ]
                            ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('关闭'))
                    ]));
      }
    } finally {
      try {
        await noteStore.clear();
      } catch (_) {}
      if (mounted)
        setState(() {
          busy = false;
        });
    }
    return (done: done, cancelled: cancelled);
  }

  Widget neutralButton(String text, VoidCallback? action) => TextButton(
      style: TextButton.styleFrom(
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest),
      onPressed: action,
      child: Text(text, style: const TextStyle(fontSize: 13)));

  /// Opens the map for one photo and stores whatever place is chosen.
  Future<void> pickPlaceFor(String path) async {
    final place = await showPlacePicker(context, app: appSettings);
    if (place == null || place.trim().isEmpty || !mounted) return;
    await savePhotoField(path, 'place', place.trim());
    if (mounted) {
      setState(() => status = '已填入地点：${place.trim()}');
      store.state(path);
    }
  }

  Future<void> openSettingsPanel() async {
    await showSettings(
        context: context, workspace: workspaceSettings, app: appSettings);
    if (!mounted) return;
    // The clear-records action may have wiped what is on screen.
    setState(() {});
  }

  Widget header() => WorkspaceHeader(
      settings: workspaceSettings,
      editing: false,
      onBrowse: () {},
      onEdit: busy || files.isEmpty ? null : openEditor,
      onOpenSettings: openSettingsPanel,
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
                              color: EditorTypography.dimOn(context)))),
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
      relinkCount: pendingRelink.length,
      onRelink: files.isEmpty ? null : openRelink,
      autoRelinkCount: autoRelinked.length,
      onShowAutoRelink: showAutoRelink,
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
                          if (total > 0) ...[
                            LinearProgressIndicator(value: completed / total),
                            const SizedBox(height: 6),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('$completed',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ],
                                          color: scheme.onSurface)),
                                  Text(' / $total',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ],
                                          color: Theme.of(context).hintColor))
                                ])
                          ],
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
                          if (Platform.isWindows && !maximized)
                            Positioned.fill(child: windowEdges()),
                        ])))));
      })));
}
