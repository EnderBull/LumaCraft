import 'dart:convert';
import 'dart:io';
import 'style_document.dart';
import 'builtin_library.dart';
import 'preset_package.dart';
import 'package:flutter/services.dart';
import 'preset_selection.dart';
import 'package:flutter/foundation.dart';

class UserPreset {
  final String id;
  final StyleDocument style;
  final String folder;
  UserPreset(this.id, this.style, {this.folder = ''});
}

class PresetFolder {
  final String id, name;
  PresetFolder(this.id, this.name);
}

class PresetEntry {
  final String id, folder;
  final StyleDocument style;
  final bool builtIn;
  PresetEntry(this.id, this.style, {this.folder = '', this.builtIn = false});
}

class PresetStore extends ChangeNotifier {
  final File file;
  List<UserPreset> presets = [];
  List<PresetFolder> folders = [];
  final selection = PresetSelection();
  String libraryQuery = '', libraryFilter = '全部', libraryFolder = 'all';
  String librarySuitability = 'all';
  final bool authoring;
  BuiltinLibrary builtinLibrary = BuiltinLibrary.seed();
  BuiltinLibrary _originalBuiltins = BuiltinLibrary.seed();
  File get builtinWorkingFile =>
      File('${file.parent.path}/builtin-working.json');
  List<PresetFolder> get builtinFolders => [
        for (final f in builtinLibrary.folders)
          PresetFolder('builtin:${f.id}', f.name)
      ];
  List<PresetEntry> get entries => [
        for (final p in builtinLibrary.entries)
          PresetEntry(p.id, p.style,
              folder: 'builtin:${p.folder}', builtIn: true),
        for (final p in presets)
          PresetEntry('user:${p.id}', p.style, folder: p.folder)
      ];
  Future<void> writeBuiltinLibrary(BuiltinLibrary value) async {
    if (!authoring) throw StateError('发行版内置预设只读');
    final checked = BuiltinLibrary.decode(value.encode());
    await validateLmpAssets(
        [for (final p in checked.entries) SharedPreset(p.style)]);
    // Serialize with existing writes. Never mutate the active library before durable save.
    final task = _queue.catchError((Object _) {}).then((_) async {
      await builtinWorkingFile.parent.create(recursive: true);
      final staged = File('${builtinWorkingFile.path}.pending');
      await staged.writeAsString(checked.encode(), flush: true);
      await staged.rename(builtinWorkingFile.path);
      builtinLibrary = checked;
      notifyListeners();
    });
    _queue = task;
    return task;
  }

  Future<void> saveBuiltin(String id, StyleDocument style, String folder) {
    final items = [
      for (final p in builtinLibrary.entries)
        if (p.id != id) p,
      BuiltinEntry(id, style.copy(), folder: folder)
    ];
    // Preserve position when editing a bundled entry.
    final previous = builtinLibrary.entries.indexWhere((p) => p.id == id);
    if (previous >= 0) items.insert(previous, items.removeLast());
    return writeBuiltinLibrary(BuiltinLibrary(builtinLibrary.folders, items));
  }

  Future<void> restoreBuiltin(String id) {
    final original =
        _originalBuiltins.entries.where((p) => p.id == id).firstOrNull;
    if (original == null) throw StateError('此预设没有封包原稿');
    return saveBuiltin(id, original.style, original.folder);
  }

  /// 没有设置样式的照片默认使用的样式：内置预设“画廊签名”（id 为 gallery）。
  /// 取当前内置库里的这一款，所以制作版里对它的修改会同步生效；
  /// 万一库里没有它，退回库里的第一款。返回副本，调用方可随意修改。
  StyleDocument defaultStyle() => (builtinLibrary.entries
              .where((p) => p.id == 'gallery')
              .firstOrNull ??
          builtinLibrary.entries.first)
      .style
      .copy();

  /// 此版本封包时的默认样式（不受本机维护修改影响）。
  BuiltinEntry? builtinOriginal(String id) =>
      _originalBuiltins.entries.where((p) => p.id == id).firstOrNull;

  /// 整个内置库恢复为此版本封包时的默认状态（包括删除本机新建的内置预设和分组）。
  Future<void> restoreAllBuiltins() => writeBuiltinLibrary(_originalBuiltins);

  bool hasBuiltinOriginal(String id) =>
      _originalBuiltins.entries.any((p) => p.id == id);
  StyleDocument? draft;
  String? draftSource;
  Map<String, StyleDocument> drafts = {};
  StyleDocument? draftFor(String key) =>
      drafts[key] ??
      (draftSource == key || draftSource == null && drafts.isEmpty
          ? draft
          : null);
  bool _loadFailed = false;
  PresetStore(this.file, {bool? authoring})
      : authoring = authoring ?? builtinAuthoring;
  Future<void> load() async {
    _originalBuiltins =
        BuiltinLibrary.decode(await rootBundle.loadString(bundledBuiltinAsset));
    builtinLibrary = _originalBuiltins;
    if (authoring && await builtinWorkingFile.exists()) {
      builtinLibrary =
          BuiltinLibrary.decode(await builtinWorkingFile.readAsString());
      await validateLmpAssets(
          [for (final p in builtinLibrary.entries) SharedPreset(p.style)]);
    }
    if (!await file.exists()) return;
    try {
      final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (j['version'] != 1) throw const FormatException('不支持的预设记录版本');
      presets = (j['presets'] as List)
          .map((p) => UserPreset(p['id'],
              StyleDocument.fromJson(Map<String, dynamic>.from(p['doc'])),
              folder: p['folder'] ?? ''))
          .toList();
      folders = [
        for (final f in j['folders'] as List? ?? [])
          PresetFolder(f['id'], f['name'])
      ];
      for (var i = 0; i < presets.length; i++) {
        final p = presets[i];
        if (p.folder.isNotEmpty && !folders.any((f) => f.id == p.folder))
          presets[i] = UserPreset(p.id, p.style);
      }
      if (j['draft'] != null)
        draft = StyleDocument.fromJson(Map<String, dynamic>.from(j['draft']));
      draftSource = j['draftSource'] as String?;
      drafts = (j['drafts'] as Map? ?? {}).map((key, value) => MapEntry(
          key.toString(),
          StyleDocument.fromJson(Map<String, dynamic>.from(value))));
      _loadFailed = false;
    } catch (_) {
      _loadFailed = true;
      rethrow;
    }
  }

  Future<void> _queue = Future.value();
  Future<void> save(
          {StyleDocument? draft,
          List<UserPreset>? presets,
          String? sourceKey}) =>
      _persist(draft: draft, presets: presets, sourceKey: sourceKey);
  Future<void> saveLibrary(
          List<UserPreset> presets, List<PresetFolder> folders) =>
      _persist(presets: presets, folders: folders);
  Future<void> deleteFolder(String id, {required bool deleteContents}) {
    final next = <UserPreset>[];
    for (final p in presets) {
      if (p.folder != id) {
        next.add(p);
      } else if (!deleteContents) {
        next.add(UserPreset(p.id, p.style));
      }
    }
    return saveLibrary(next, folders.where((f) => f.id != id).toList());
  }

  Future<void> _persist(
      {StyleDocument? draft,
      List<UserPreset>? presets,
      String? sourceKey,
      List<PresetFolder>? folders}) {
    if (_loadFailed) return Future.error(StateError('预设记录读取失败，已停止写入以保留原文件'));
    final draftSnapshot = draft?.copy();
    final presetSnapshot = presets
        ?.map((p) => UserPreset(p.id, p.style.copy(), folder: p.folder))
        .toList();
    final folderSnapshot =
        folders?.map((f) => PresetFolder(f.id, f.name)).toList();
    final next = _queue.catchError((Object _) {}).then((_) async {
      final nextDraft = draftSnapshot ?? this.draft,
          nextPresets = presetSnapshot ?? this.presets;
      final nextFolders = folderSnapshot ?? this.folders;
      final nextDrafts = {...drafts};
      if (draftSnapshot != null && sourceKey != null)
        nextDrafts[sourceKey] = draftSnapshot;
      final data = jsonEncode({
        'version': 1,
        'draft': nextDraft?.toJson(),
        'folders': [
          for (final f in nextFolders) {'id': f.id, 'name': f.name}
        ],
        'draftSource': sourceKey ?? draftSource,
        'drafts': nextDrafts.map((key, value) => MapEntry(key, value.toJson())),
        'presets': nextPresets
            .map((p) =>
                {'id': p.id, 'doc': p.style.toJson(), 'folder': p.folder})
            .toList()
      });
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.pending');
      await temp.writeAsString(data, flush: true);
      await temp.rename(file.path);
      this.draft = nextDraft;
      drafts = nextDrafts;
      draftSource = sourceKey ?? draftSource;
      this.presets = nextPresets;
      this.folders = nextFolders;
      notifyListeners();
    });
    _queue = next;
    return next;
  }
}
