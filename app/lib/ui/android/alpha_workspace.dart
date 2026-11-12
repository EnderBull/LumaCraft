import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../editor/preset_store.dart';
import '../../editor/preset_package.dart';
import 'mobile_edits.dart';
import '../../editor/style_document.dart';
import '../../export/android_photo_io.dart';
import '../../export/export_naming.dart';
import '../../export/export_options.dart';
import '../../export/photo_export.dart';
import '../../photo_state.dart';
import '../../workspace_settings.dart';
import '../../usage_data.dart';

class AlphaPhoto {
  final AndroidPhoto source;
  Future<File>? _thumbnail;

  AlphaPhoto(this.source);

  Future<File> thumbnail() => _thumbnail ??= _loadThumbnail();

  Future<File> _loadThumbnail() async => AndroidDecodedPhoto.decode(
        await source.readablePath(),
        160,
      ).then((decoded) => decoded.file);

  Future<void> dispose() async {
    final thumbnail = _thumbnail;
    if (thumbnail != null) {
      try {
        await (await thumbnail).delete();
      } on Object catch (_) {
        // The thumbnail may have failed to decode.
      }
    }
  }
}

class AlphaPreview {
  final AndroidDecodedPhoto decoded;
  final ui.Image image;
  final Map<String, String> fields;

  const AlphaPreview(this.decoded, this.image, this.fields);

  void dispose() {
    image.dispose();
    unawaited(_discard(decoded.file));
  }
}

Future<void> _discard(File file) async {
  try {
    await file.delete();
  } on FileSystemException catch (_) {
    // Cache cleanup must not replace an operation's result.
  }
}

class AlphaWorkspace extends ChangeNotifier {
  final photos = <AlphaPhoto>[];
  final _favoriteIds = <String>{};
  PresetStore? _store;
  WorkspaceSettings? _preferences;
  PresetEntry? _chosen;
  final _edits = MobileEdits(StyleDocument.template());
  final _drafts = <String, StyleDocument>{};
  int index = -1;
  int _selectionRevision = 0;
  bool _disposed = false;
  File? _session;
  Future<void> _sessionWrites = Future.value();
  final _removed = <(int, AlphaPhoto)>[];
  String? sessionError;

  void _saveSession() {
    final file = _session;
    if (file == null || _disposed) return;
    final data = {
      'version': 1,
      'photos': [for (final photo in photos) photo.source.toJson()],
      'index': index,
      'preset': presetId,
      'style': style.toJson(),
      'drafts': _drafts.map((id, draft) => MapEntry(id, draft.toJson())),
      'edits': _edits.snapshot({for (final photo in photos) photo.source.path}),
    };
    _sessionWrites = _sessionWrites.then((_) async {
      await UsageData.writeStringAtomic(file, jsonEncode(data), gated: false);
      sessionError = null;
    }).catchError((Object _) {
      sessionError = '无法保存本次编辑会话。';
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> _restoreSession(File file) async {
    _session = file;
    if (!await file.exists()) return;
    try {
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (_disposed || data['version'] != 1) return;
      final restored = (data['photos'] as List)
          .map(
            (row) => AlphaPhoto(
                AndroidPhoto.fromJson(Map<String, dynamic>.from(row as Map))),
          )
          .toList();
      if (restored.isEmpty) return;
      final saved = StyleDocument.fromJson(
          Map<String, dynamic>.from(data['style'] as Map));
      final drafts = (data['drafts'] as Map).map((id, value) => MapEntry(
          id as String,
          StyleDocument.fromJson(Map<String, dynamic>.from(value as Map))));
      _edits.loadStyle(saved);
      _edits.restore(Map<String, dynamic>.from(data['edits'] as Map));
      final savedId = data['preset'] as String?;
      _chosen = savedId == null
          ? null
          : presets.where((entry) => entry.id == savedId).firstOrNull ??
              PresetEntry(savedId, saved);
      _drafts.addAll(drafts);
      photos.addAll(restored);
      select((data['index'] as int).clamp(0, photos.length - 1), save: false);
    } on Object {
      sessionError = '无法读取上次编辑会话。';
    }
  }

  bool get canUndoRemoval => _removed.isNotEmpty;
  void removePhoto(AlphaPhoto photo) {
    if (busy) return;
    final at = photos.indexOf(photo);
    if (at < 0) return;
    final previous = current;
    _removed.add((at, photo));
    photos.removeAt(at);
    if (identical(previous, photo)) {
      index = -1;
      if (photos.isNotEmpty) {
        select(at.clamp(0, photos.length - 1));
        return;
      }
      final oldPreview = preview;
      if (oldPreview != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => oldPreview.dispose());
      }
      preview = null;
      loading = false;
      previewError = null;
      _selectionRevision++;
    } else if (previous != null) {
      index = photos.indexOf(previous);
    }
    _saveSession();
    notifyListeners();
  }

  void undoRemoval() {
    if (busy || _removed.isEmpty) return;
    final previous = current;
    final (at, photo) = _removed.removeLast();
    photos.insert(at.clamp(0, photos.length), photo);
    if (previous == null) {
      select(photos.indexOf(photo));
    } else {
      index = photos.indexOf(previous);
      _saveSession();
      notifyListeners();
    }
  }

  AlphaPreview? preview;
  bool loading = false;
  String? busyMessage;
  String? previewError;
  String? libraryError;
  bool libraryReady = false;

  List<PresetEntry> get presets => _store?.entries ?? const [];
  List<PresetFolder> get folders => [
        ...?_store?.builtinFolders,
        for (final folder in _store?.folders ?? const <PresetFolder>[])
          PresetFolder('user:${folder.id}', folder.name),
      ];
  bool isFavorite(String id) => _favoriteIds.contains(id);
  String? get presetId => _chosen?.id;
  StyleDocument get style => _edits.style;
  String get _captionScope => presetId ?? 'gallery';
  StyleDocument get currentStyle {
    final photo = current;
    return photo == null
        ? style
        : _edits.styleFor(photo.source.path, _captionScope);
  }

  Map<String, String> get fields {
    final photo = current;
    final original = preview?.fields ?? const <String, String>{};
    return photo == null
        ? original
        : _edits.fieldsFor(photo.source.path, original);
  }

  List<UserPreset> get userPresets => _store?.presets ?? const [];
  List<PresetFolder> get userFolders => _store?.folders ?? const [];
  bool get canUndo => _edits.canUndo;
  bool get canRedo => _edits.canRedo;

  void editComponent(String id, void Function(StyleNode) change) {
    if (busy) return;
    _edits.editComponent(id, change);
    _saveSession();
    notifyListeners();
  }

  StyleNode? presetDefault(String id) => _chosen?.style.node(id);

  void resetComponentNumber(String id, double Function(StyleNode) read,
      void Function(StyleNode, double) apply) {
    final saved = _chosen?.style;
    if (busy || saved == null) return;
    _edits.resetComponentNumber(id, saved, read, apply);
    _saveSession();
    notifyListeners();
  }

  void previewComponent(String id, void Function(StyleNode)? change) {
    if (busy) return;
    _edits.previewComponent(id, change);
    notifyListeners();
  }

  void cancelComponentPreview() {
    if (_edits.cancelPreview()) notifyListeners();
  }

  String? caption(String id) {
    final photo = current;
    return photo == null
        ? null
        : _edits.caption(photo.source.path, _captionScope, id);
  }

  void editCaption(String id, String? value) {
    final photo = current;
    if (photo == null || busy || style.locked(id)) return;
    _edits.editCaption(photo.source.path, _captionScope, id, value);
    _saveSession();
    notifyListeners();
  }

  void editCapture(String field, String? value, {String? photoPath}) {
    final photo = photoPath ?? current?.source.path;
    if (photo == null || busy || !infoFields.containsKey(field)) return;
    _edits.editCapture(photo, field, value);
    _saveSession();
    notifyListeners();
  }

  void undo() {
    if (busy) return;
    _edits.undo();
    _saveSession();
    notifyListeners();
  }

  void redo() {
    if (busy) return;
    _edits.redo();
    _saveSession();
    notifyListeners();
  }

  AlphaPhoto? get current => index >= 0 ? photos[index] : null;
  bool get busy => busyMessage != null;

  Future<void> initialize() async {
    try {
      final path = await androidPlatform.invokeMethod<String>('settingsPath');
      final folder = File(path!).parent;
      if (_disposed) return;
      final store = PresetStore(File('${folder.path}/editor-presets.json'),
          authoring: false);
      _store = store;
      await store.load();
      if (_disposed) return;
      _chosen =
          store.entries.where((item) => item.id == 'gallery').firstOrNull ??
              store.entries.firstOrNull;
      if (_chosen case final chosen?) _edits.loadStyle(chosen.style);
      await _restoreSession(File('${folder.path}/android-session.json'));
      if (_disposed) return;
      final marker = File('${folder.path}/android-export-running');
      if (await marker.exists()) {
        sessionError = '上次导出已中断。已保存的成片仍在相册。';
        await _discard(marker);
      }
      if (_disposed) return;
      if (sessionError == null || sessionError!.startsWith('上次导出')) {
        await androidPlatform.invokeMethod<void>('sweepSessionPhotos', {
          'paths': [for (final photo in photos) photo.source.path],
        });
      }
      final preferences =
          WorkspaceSettings(File('${folder.path}/workspace.json'));
      try {
        await preferences.load();
        if (_disposed) {
          preferences.dispose();
          return;
        }
        _preferences = preferences;
        _favoriteIds.addAll(preferences.favorites);
      } on Object catch (_) {
        preferences.dispose();
        if (!_disposed) libraryError = '收藏记录读取失败，请稍后重试。';
      }
    } on Object catch (_) {
      if (!_disposed) libraryError = '预设库加载失败，请重启后重试。';
    } finally {
      if (!_disposed) {
        libraryReady = true;
        notifyListeners();
      }
    }
  }

  void replaceSession(List<AndroidPhoto> sources) {
    if (sources.isEmpty || busy) return;
    for (final photo in [...photos, ..._removed.map((entry) => entry.$2)]) {
      unawaited(photo.dispose().catchError((Object _) {}));
    }
    photos
      ..clear()
      ..addAll(sources.map(AlphaPhoto.new));
    _removed.clear();
    _drafts.clear();
    _edits.loadStyle(_chosen?.style ?? StyleDocument.template());
    _edits.restore({'captions': [], 'capture': []});
    index = -1;
    select(0);
  }

  Future<void> pick({required bool album}) async {
    if (busy) return;
    busyMessage = '正在导入照片…';
    notifyListeners();
    try {
      final selected = await AndroidPhoto.pickPhotos(album: album);
      if (_disposed) {
        for (final photo in selected) {
          await _discard(File(photo.path));
        }
        return;
      }
      if (selected.isEmpty) return;
      final first = photos.length;
      photos.addAll(selected.map(AlphaPhoto.new));
      select(first);
    } finally {
      busyMessage = null;
      if (!_disposed) notifyListeners();
    }
  }

  void select(int value, {bool save = true}) {
    if (_disposed ||
        value < 0 ||
        value >= photos.length ||
        (value == index && previewError == null)) return;
    final previous = preview;
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
    preview = null;
    index = value;
    loading = true;
    previewError = null;
    final revision = ++_selectionRevision;
    if (save) _saveSession();
    notifyListeners();
    unawaited(_loadPreview(photos[value].source, revision));
  }

  Future<void> _loadPreview(AndroidPhoto source, int revision) async {
    AndroidDecodedPhoto? decoded;
    ui.Image? image;
    try {
      final path = await source.readablePath();
      decoded = await AndroidDecodedPhoto.decode(path, 1600);
      if (_disposed || revision != _selectionRevision) return;
      image = await decoded.openImage();
      final fields = await compute(readCapture, path);
      if (_disposed || revision != _selectionRevision) return;
      preview = AlphaPreview(decoded, image, fields);
      decoded = null;
      image = null;
    } on Object catch (_) {
      if (!_disposed && revision == _selectionRevision) {
        previewError = '无法打开这张照片。请确认文件是可读的 JPEG、HEIC 或 HEIF。';
      }
    } finally {
      image?.dispose();
      if (decoded != null) await _discard(decoded.file);
      if (!_disposed && revision == _selectionRevision) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void choosePreset(PresetEntry preset) {
    if (busy || preset.id == _chosen?.id) return;
    if (_chosen case final previous?) _drafts[previous.id] = style.copy();
    _chosen = preset;
    _edits.loadStyle(_drafts[preset.id] ?? preset.style);
    _saveSession();
    notifyListeners();
  }

  SharedPreset sharePreset({PresetEntry? entry}) {
    final chosen = entry ?? _chosen;
    final folderId = chosen?.folder ?? '';
    final folder = folders
            .where((item) =>
                item.id == folderId ||
                (chosen?.builtIn == false && item.id == 'user:$folderId'))
            .firstOrNull
            ?.name ??
        '';
    return SharedPreset((entry?.style ?? style).copy(), folder: folder);
  }

  Future<int> importPresets(List<SharedPreset> incoming,
      {bool activate = true}) async {
    final store = _store;
    if (store == null) throw StateError('预设库暂不可用。');
    final first = store.presets.length;
    final imported = mergeLmp(store, incoming, {});
    await store.saveLibrary(imported.presets, imported.folders);
    if (!_disposed && imported.count > 0 && activate) {
      final id = imported.presets[first].id;
      choosePreset(store.entries.firstWhere((p) => p.id == 'user:$id'));
    }
    if (!_disposed && !activate) notifyListeners();
    return imported.count;
  }

  Future<String> savePreset(String name,
      {String? replaceId, String folder = ''}) async {
    final store = _store;
    if (store == null) throw StateError('预设库暂不可用。');
    if (name.trim().isEmpty) throw const FormatException('请输入预设名称。');
    final items = [...store.presets];
    final oldIndex = items.indexWhere((p) => p.id == replaceId);
    if (replaceId != null && oldIndex < 0) throw StateError('该用户预设已不存在。');
    final old = oldIndex < 0 ? null : items[oldIndex];
    final copy = style.copy()
      ..name = uniquePresetName(
          name.trim(),
          items
              .where((item) => item.id != old?.id)
              .map((item) => item.style.name));
    final saved = UserPreset(old?.id ?? newObjectId(), copy,
        folder: old?.folder ?? folder);
    if (oldIndex < 0) {
      items.add(saved);
    } else {
      items[oldIndex] = saved;
      _drafts.remove('user:${saved.id}');
    }
    await store.saveLibrary(items, store.folders);
    if (_chosen?.id == 'user:${saved.id}') {
      _chosen = store.entries.firstWhere((entry) => entry.id == _chosen!.id);
    }
    if (!_disposed) notifyListeners();
    return copy.name;
  }

  Future<String> copyLibraryPreset(PresetEntry entry) async {
    final store = _store;
    if (store == null) throw StateError('预设库暂不可用。');
    final copy = entry.style.copy()
      ..name = uniquePresetName(entry.style.name + ' 副本',
          store.presets.map((item) => item.style.name));
    await store.saveLibrary([
      ...store.presets,
      UserPreset(newObjectId(), copy,
          folder: entry.builtIn ? '' : entry.folder),
    ], store.folders);
    if (!_disposed) notifyListeners();
    return copy.name;
  }

  Future<void> updateLibraryPreset(
    String entryId, {
    String? name,
    String? folder,
    String? newFolder,
    bool remove = false,
  }) async {
    final store = _store;
    if (store == null) throw StateError('预设库暂不可用。');
    if (!entryId.startsWith('user:')) throw StateError('内置预设不能修改。');
    final items = [...store.presets];
    final index = items.indexWhere((item) => item.id == entryId.substring(5));
    if (index < 0) throw StateError('该用户预设已不存在。');
    final folders = [...store.folders];
    if (newFolder != null) {
      final title = newFolder.trim();
      if (title.isEmpty) throw const FormatException('请输入分组名称。');
      if (folders.any((item) => item.name == title)) {
        throw const FormatException('已有同名分组。');
      }
      final created = PresetFolder(newObjectId(), title);
      folders.add(created);
      folder = created.id;
    }
    if (folder != null &&
        folder.isNotEmpty &&
        !folders.any((item) => item.id == folder)) {
      throw StateError('该分组已不存在。');
    }
    final old = items[index];
    if (remove) {
      items.removeAt(index);
    } else {
      final next = old.style.copy();
      if (name != null) {
        final trimmed = name.trim();
        if (trimmed.isEmpty) throw const FormatException('请输入预设名称。');
        next.name = uniquePresetName(
            trimmed,
            items
                .where((item) => item.id != old.id)
                .map((item) => item.style.name));
      }
      items[index] = UserPreset(old.id, next, folder: folder ?? old.folder);
    }
    await store.saveLibrary(items, folders);
    if (_disposed) return;
    if (remove) {
      _drafts.remove(entryId);
      if (_chosen?.id == entryId) _chosen = null;
      final preferences = _preferences;
      if (_favoriteIds.remove(entryId) && preferences != null) {
        preferences.favorites.remove(entryId);
        await preferences.save();
      }
    } else {
      final draft = _drafts[entryId];
      if (name != null && draft != null) draft.name = items[index].style.name;
      if (_chosen?.id == entryId) {
        _chosen = store.entries.firstWhere((entry) => entry.id == entryId);
        if (name != null) style.name = _chosen!.style.name;
      }
    }
    _saveSession();
    if (!_disposed) notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final preferences = _preferences;
    if (preferences == null) throw StateError('暂时无法保存收藏。');
    if (!_favoriteIds.remove(id)) _favoriteIds.add(id);
    preferences.favorites
      ..clear()
      ..addAll(_favoriteIds);
    notifyListeners();
    await preferences.save();
    if (preferences.saveError != null) {
      throw StateError(preferences.saveError!);
    }
  }

  bool exporting = false, _cancelExport = false;
  final _failed = <(AndroidPhoto, StyleDocument, Map<String, String>)>[];
  List<String> get failedNames => [for (final job in _failed) job.$1.name];
  final _publishedNames = <String>{};
  ExportOptions? _failedOptions;
  bool get canRetryExport => !busy && _failed.isNotEmpty;

  void cancelExport() {
    if (exporting) _cancelExport = true;
  }

  Future<String> exportCurrent(ExportOptions options) {
    final active = current?.source;
    if (active == null || busy) throw StateError('请先打开一张照片。');
    _edits.cancelPreview();
    _publishedNames.clear();
    final sources =
        options.scope == 'all' ? photos.map((p) => p.source) : [active];
    return _runExport([
      for (final photo in sources)
        (
          photo,
          _edits.styleFor(photo.path, _captionScope).copy(),
          _edits.fieldsFor(photo.path, const {})
        )
    ], options.copy());
  }

  Future<String> retryExport() {
    if (!canRetryExport) throw StateError('当前没有可重试的照片。');
    return _runExport([..._failed], _failedOptions!.copy(), retry: true);
  }

  Future<String> _runExport(
      List<(AndroidPhoto, StyleDocument, Map<String, String>)> jobs,
      ExportOptions options,
      {bool retry = false}) async {
    final folder = _session?.parent;
    if (folder == null) throw StateError('无法访问导出任务记录。');
    if (!retry) _failed.clear();
    _failedOptions = options;
    _cancelExport = false;
    exporting = true;
    busyMessage = '正在准备导出…';
    notifyListeners();
    final marker = File('${folder.path}/android-export-running');
    var saved = 0;
    var attempted = 0;
    String? stopped;
    try {
      await marker.writeAsString('1', flush: true);
      await androidPlatform.invokeMethod<void>('startExport',
          {'total': jobs.length}).timeout(const Duration(seconds: 10));
      for (final job in jobs) {
        final (source, jobStyle, overrides) = job;
        if (_cancelExport) break;
        attempted++;
        busyMessage = '正在导出 $attempted / ${jobs.length}';
        notifyListeners();
        await androidPlatform.invokeMethod<void>('exportProgress',
            {'completed': attempted - 1, 'total': jobs.length});
        AndroidDecodedPhoto? decoded;
        AndroidDecodedPhoto? palette;
        ui.Image? image;
        try {
          final path = await source.readablePath();
          final effectiveFields = {
            ...await compute(readCapture, path),
            ...overrides
          };
          if (_cancelExport) break;
          decoded = await AndroidDecodedPhoto.decode(path, 0);
          image = await decoded.openImage();
          if (jobStyle.nodes.any((node) => node.type == 'palette')) {
            palette = await AndroidDecodedPhoto.decode(path, 1600);
          }
          if (_cancelExport) break;
          final bytes = await encodeStyledExport(
              sourcePath: path,
              style: jobStyle,
              fields: effectiveFields,
              options: options,
              photo: image,
              profile: androidSrgbProfile,
              palettePhotoPath: palette?.file.path);
          if (_cancelExport) break;
          final name = resolveExportName(
              defaultNamingTemplate(), source.name, effectiveFields, attempted);
          final filename = '${name.stem}.${options.format}';
          await publishToAndroidGallery(bytes, filename, options.format,
              replace: options.replaceAndroidExports &&
                  !_publishedNames.contains(filename.toLowerCase()));
          _publishedNames.add(filename.toLowerCase());
          _failed.remove(job);
          saved++;
        } on Object catch (error) {
          final detail = error.toString().toLowerCase();
          if (!retry) _failed.add(job);
          if (detail.contains('enospc') ||
              detail.contains('no space left') ||
              detail.contains('edquot')) {
            stopped = '存储空间不足，已停止导出';
          }
          await _logExportFailure(
              stopped == null ? 'photo_failed' : 'storage_full');
        } finally {
          image?.dispose();
          if (decoded != null) await _discard(decoded.file);
          if (palette != null) await _discard(palette.file);
        }
        if (stopped != null) break;
      }
      final status = stopped ?? (_cancelExport ? '已取消导出' : '导出结束');
      return '$status · 成功 $saved 张 · 失败 ${_failed.length} 张';
    } finally {
      try {
        await androidPlatform.invokeMethod<void>('finishExport');
      } finally {
        await _discard(marker);
        exporting = false;
        busyMessage = null;
        if (!_disposed) notifyListeners();
      }
    }
  }

  Future<void> _logExportFailure(String code) async {
    final folder = _session?.parent;
    if (folder == null) return;
    try {
      final file = File('${folder.path}/android-export-diagnostics.txt');
      final previous =
          await file.exists() ? await file.readAsLines() : <String>[];
      final lines = [...previous, '${DateTime.now().toIso8601String()} $code'];
      await UsageData.writeStringAtomic(
          file, lines.reversed.take(100).toList().reversed.join('\n'),
          gated: false);
    } on Object {
      // Diagnostics do not affect export results.
    }
  }

  Future<String> exportDiagnostics() async {
    final folder = _session?.parent;
    if (folder == null) return '';
    final file = File('${folder.path}/android-export-diagnostics.txt');
    return await file.exists() ? file.readAsString() : '';
  }

  @override
  void dispose() {
    _disposed = true;
    preview?.dispose();
    _edits.dispose();
    _store?.dispose();
    _preferences?.dispose();
    for (final photo in [...photos, ..._removed.map((entry) => entry.$2)]) {
      unawaited(photo.dispose().catchError((Object _) {}));
    }
    super.dispose();
  }
}
