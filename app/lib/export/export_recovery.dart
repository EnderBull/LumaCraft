import 'dart:convert';
import 'dart:io';
import '../editor/style_document.dart';
import '../export/export_options.dart';
import '../photo_state.dart';
import '../usage_data.dart';
import 'export_task.dart';

/// One photo of an export batch, fixed when the user confirmed the export:
/// the style it was given, the shooting fields that went onto the frame, the
/// output name, and — for a file the user agreed to replace — what that file
/// looked like then. Resuming uses exactly this, never the current screen.
class RecoveryJob {
  final String source, target, stem;
  final bool film;
  final Map<String, String> fields;

  /// Style as JSON; null for a photo exported with the old film layout.
  final Map<String, dynamic>? style;
  final FileSnapshot? replaced;
  const RecoveryJob(this.source, this.target, this.stem,
      {this.film = false,
      this.fields = const {},
      this.style,
      this.replaced});

  Map<String, dynamic> toJson({int? styleIndex}) => {
        'source': source,
        'target': target,
        'stem': stem,
        if (film) 'film': true,
        if (fields.isNotEmpty) 'fields': fields,
        if (styleIndex != null) 'style': styleIndex,
        if (replaced != null)
          'replaced': {
            'type': replaced!.type.toString(),
            'size': replaced!.size,
            'modified': replaced!.modified.microsecondsSinceEpoch,
          },
      };

  static RecoveryJob? fromJson(Object? json, [List<Object?> styles = const []]) {
    if (json is! Map) return null;
    final source = json['source'], target = json['target'];
    if (source is! String || target is! String || source.isEmpty) return null;
    Map<String, dynamic>? style;
    final index = json['style'];
    if (index is int && index >= 0 && index < styles.length) {
      final value = styles[index];
      if (value is Map) style = Map<String, dynamic>.from(value);
    }
    FileSnapshot? replaced;
    final r = json['replaced'];
    if (r is Map && r['size'] is int && r['modified'] is int) {
      final type = const [
        FileSystemEntityType.file,
        FileSystemEntityType.directory,
        FileSystemEntityType.link,
        FileSystemEntityType.pipe,
        FileSystemEntityType.notFound,
      ].firstWhere(
          (t) => t.toString() == r['type'],
          orElse: () => FileSystemEntityType.file);
      replaced = FileSnapshot(type, r['size'] as int,
          DateTime.fromMicrosecondsSinceEpoch(r['modified'] as int));
    }
    return RecoveryJob(source, target, json['stem'] as String? ?? '',
        film: json['film'] == true,
        fields: {
          if (json['fields'] is Map)
            for (final e in (json['fields'] as Map).entries)
              '${e.key}': '${e.value}'
        },
        style: style,
        replaced: replaced);
  }

  /// Rebuilds the job for the exporter. A style that cannot be read back
  /// falls to [fallback] (the default style) rather than the old film layout.
  ExportJob toExportJob({StyleDocument? fallback}) {
    StyleDocument? doc;
    if (style != null) {
      try {
        doc = StyleDocument.fromJson(Map<String, dynamic>.from(style!));
      } catch (_) {
        doc = fallback;
      }
    }
    return ExportJob(File(source), doc, film, Map.of(fields), stem, target)
      ..replacedStat = replaced;
  }

  static RecoveryJob fromExportJob(ExportJob job) => RecoveryJob(
      job.source.path, job.target, job.stem,
      film: job.film,
      fields: Map.of(job.fields),
      style: job.style?.toJson(),
      replaced: job.replacedStat);
}

Map<String, dynamic> _optionsToJson(ExportOptions o) => {
      'directory': o.directory,
      'format': o.format,
      'quality': o.quality,
      'sizeEdge': o.sizeEdge,
      'edgePixels': o.edgePixels,
      'retainCaptureInfo': o.retainCaptureInfo,
      'retainGps': o.retainGps,
      'scope': o.scope
    };

ExportOptions? _optionsFromJson(Map json) {
  final directory = json['directory'];
  if (directory is! String || directory.isEmpty) return null;
  int? dim(Object? value) => value is int && value > 0 ? value : null;
  return ExportOptions()
    ..directory = directory
    ..format = json['format'] == 'png' ? 'png' : 'jpg'
    ..quality = (json['quality'] as int? ?? 92).clamp(1, 100)
    ..sizeEdge = json['sizeEdge'] == 'short' ? 'short' : 'long'
    ..edgePixels = dim(json['edgePixels'])
    ..retainCaptureInfo = json['retainCaptureInfo'] != false
    ..retainGps = json['retainGps'] == true
    ..scope = json['scope'] as String? ?? 'selected';
}

/// Everything fixed when an export batch starts. Written once, next to the
/// progress record; the progress record only says how far the batch got.
class ExportBatch {
  final ExportOptions options;
  final bool replace;
  final List<RecoveryJob> jobs;
  const ExportBatch(this.options, this.jobs, {this.replace = false});

  Map<String, dynamic> toJson() {
    // Many photos share one style; keep one copy of each.
    final styles = <String>[];
    final jobsJson = <Map<String, dynamic>>[];
    for (final job in jobs) {
      int? index;
      if (job.style != null) {
        final key = jsonEncode(job.style);
        index = styles.indexOf(key);
        if (index < 0) {
          styles.add(key);
          index = styles.length - 1;
        }
      }
      jobsJson.add(job.toJson(styleIndex: index));
    }
    return {
      'version': 3,
      'replace': replace,
      'options': _optionsToJson(options),
      'styles': [for (final s in styles) jsonDecode(s)],
      'jobs': jobsJson,
    };
  }

  static ExportBatch? fromJson(Object? json) {
    if (json is! Map || json['version'] != 3) return null;
    final options = json['options'] is Map
        ? _optionsFromJson(json['options'] as Map)
        : null;
    if (options == null || json['jobs'] is! List) return null;
    final styles = json['styles'] is List ? json['styles'] as List : const [];
    final jobs = <RecoveryJob>[];
    for (final item in json['jobs'] as List) {
      final job = RecoveryJob.fromJson(item, styles);
      if (job == null) return null;
      jobs.add(job);
    }
    return ExportBatch(options, jobs, replace: json['replace'] == true);
  }
}
/// Progress of one export batch, written to disk while it runs.
///
/// A normal finish deletes this file. Closing the window writes
/// export-recovery.dismissed next to it and the note is then ignored. A crash
/// or a frozen exit leaves the note behind, and the next launch offers to
/// continue from the photo that was in progress.
class ExportRecovery {
  final String fileName;
  final int? width, height;

  /// Photos not exported yet, in the original order.
  final List<RecoveryJob> pending;

  /// Photos exported before the interruption; never repeated on resume.
  final int completed;

  /// Photos that already failed once. Skipped on resume so a photo that
  /// cannot be exported never puts the batch into a loop.
  final List<String> skipped;
  final ExportOptions? options;

  /// A batch written by [ExportRecoveryStore.writeBatch]. When set, [pending]
  /// and [options] come from that file, starting at photo [index].
  final String? batchId;
  final int index;

  /// Whether the user agreed to replace existing files in this batch.
  final bool replace;
  const ExportRecovery(this.fileName,
      {this.width,
      this.height,
      this.pending = const [],
      this.completed = 0,
      this.skipped = const [],
      this.options,
      this.batchId,
      this.index = 0,
      this.replace = false});

  /// The same note with the batch's photos and settings filled in.
  ExportRecovery withBatch(ExportBatch batch) => ExportRecovery(fileName,
      width: width,
      height: height,
      pending: batch.jobs.skip(index).toList(),
      completed: completed,
      skipped: skipped,
      options: batch.options,
      batchId: batchId,
      index: index,
      replace: batch.replace);

  /// Photos a resume will actually export: everything after the one that was
  /// in progress, which is never retried.
  int get resumeCount => pending.isEmpty ? 0 : pending.length - 1;

  int? get pixels =>
      width == null || height == null ? null : width! * height!;

  /// True when there is enough information to carry on exporting.
  bool get canResume => options != null && pending.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'version': 2,
        'file': fileName,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (completed > 0) 'completed': completed,
        if (skipped.isNotEmpty) 'skipped': skipped,
        // With a batch file the photos and settings live there; this record
        // stays small however long the batch is.
        if (batchId != null) ...{'batch': batchId, 'index': index} else ...{
          if (pending.isNotEmpty)
            'pending': [for (final j in pending) j.toJson()],
          if (options != null) ..._optionsToJson(options!),
        }
      };

  static ExportRecovery? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['file'];
    if (name is! String || name.isEmpty) return null;
    int? dim(Object? value) => value is int && value > 0 ? value : null;
    final pending = <RecoveryJob>[];
    if (json['pending'] is List) {
      for (final item in json['pending'] as List) {
        final job = RecoveryJob.fromJson(item);
        if (job != null) pending.add(job);
      }
    }
    final skipped = <String>[
      for (final item in (json['skipped'] as List? ?? const []))
        if (item is String && item.isNotEmpty) item
    ];
    final options = _optionsFromJson(json);
    final batch = json['batch'];
    return ExportRecovery(name,
        width: dim(json['width']),
        height: dim(json['height']),
        pending: pending,
        completed: json['completed'] as int? ?? 0,
        skipped: skipped,
        options: options,
        batchId: batch is String && batch.isNotEmpty ? batch : null,
        index: json['index'] is int && json['index'] >= 0 ? json['index'] : 0);
  }
}

String exportRecoveryMessage(ExportRecovery note, {bool closedByUser = false}) {
  final size = note.pixels == null
      ? ''
      : '这张照片约 ${(note.pixels! / 10000).round()} 万像素。';
  final rest = note.canResume
      ? '这一批还剩 ${note.resumeCount} 张没有导出（不含中断时正在处理的那一张）。'
      : '';
  final why = closedByUser
      ? '上次导出「${note.fileName}」时，软件在导出过程中被关闭了，这一批没有做完。'
      : '上次导出「${note.fileName}」时软件自己停住了，不是正常关闭。';
  return '$why$size$rest\n\n'
      '成片接近上限（最长边 16384 像素，总计约 1.34 亿像素）时，内存可能不够，软件会卡住或闪退。'
      '如果继续，中断时正在处理的那一张不会恢复导出，避免一直卡在同一张上；已导出的不会重做。';
}

/// Photos to export when carrying on a batch that stopped.
///
/// The photo that was in progress when it stopped is skipped: it is the most
/// likely cause, and retrying it would stop the batch again. Photos that
/// already failed and photos that no longer exist are skipped too, so
/// resuming always makes progress and never loops.
List<RecoveryJob> resumableJobs(ExportRecovery note,
    {required bool Function(String path) exists}) {
  if (!note.canResume) return const [];
  final skipped = <String>{
    ...note.skipped,
    note.pending.first.source,
  };
  return [
    for (final job in note.pending.skip(1))
      if (!skipped.contains(job.source) && exists(job.source)) job
  ];
}

class ExportRecoveryStore {
  final File file;
  ExportRecoveryStore(this.file);
  factory ExportRecoveryStore.standard() => ExportRecoveryStore(File(
      '${PhotoStore.defaultFile().parent.path}/export-recovery.json'));

  Future<void> write(ExportRecovery note) =>
      UsageData.write(() => _write(note));

  Future<void> _write(ExportRecovery note) async {
    await file.parent.create(recursive: true);
    // Writing straight to the note can leave half a file if the process is
    // killed mid-write, and a half file reads as "no export in progress".
    // Write beside it and swap, which the filesystem does atomically.
    final temp = File('${file.path}.writing');
    final handle = await temp.open(mode: FileMode.write);
    try {
      await handle.writeString(jsonEncode(note.toJson()));
      await handle.flush();
    } finally {
      await handle.close();
    }
    try {
      await temp.rename(file.path);
    } catch (_) {
      // On Windows a rename onto an existing file can fail; fall back to a
      // direct write so the progress is never lost.
      await file.writeAsString(jsonEncode(note.toJson()), flush: true);
      try {
        await temp.delete();
      } catch (_) {}
    }
  }

  /// A window close leaves this file beside the note. The native window
  /// handler and this name must stay the same.
  File get dismissedFile =>
      File('${file.parent.path}/export-recovery.dismissed');

  /// Whether the previous session was closed from the window rather than
  /// dying. The user is told either way, this only changes the wording.
  Future<bool> closedByUser() async {
    final existed = await dismissedFile.exists();
    if (existed) {
      try {
        await dismissedFile.delete();
      } catch (_) {}
    }
    return existed;
  }

  /// Any unfinished export, whether the window was closed or the app died.
  ///
  /// A user closing the window in the middle of an export still leaves work
  /// undone, so it is reported too and the choice of continuing is theirs.
  Future<ExportRecovery?> readInterrupted() => read();

  Future<ExportRecovery?> read() async {
    if (!await file.exists()) return null;
    try {
      final note =
          ExportRecovery.fromJson(jsonDecode(await file.readAsString()));
      if (note == null) return const ExportRecovery('一张照片');
      if (note.batchId == null) return note;
      final batch = await readBatch(note.batchId!);
      // A batch that cannot be read still reports the interruption; it just
      // cannot be resumed.
      return batch == null ? note : note.withBatch(batch);
    } catch (_) {
      return const ExportRecovery('一张照片');
    }
  }

  File batchFile(String id) => File('${file.parent.path}/export-batch-$id.json');

  /// Writes the batch once and returns its id. Written beside the target and
  /// swapped in, so a kill mid-write never leaves a half file; the id is new
  /// every time, so an older record keeps pointing at its own batch until the
  /// new progress record replaces it.
  Future<String> writeBatch(ExportBatch batch) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await UsageData.writeStringAtomic(
        batchFile(id), jsonEncode(batch.toJson()),
        suffix: '.writing');
    if (!await batchFile(id).exists()) {
      throw const FileSystemException('保存导出批次失败');
    }
    return id;
  }

  Future<ExportBatch?> readBatch(String id) async {
    final f = batchFile(id);
    if (!await f.exists()) return null;
    try {
      return ExportBatch.fromJson(jsonDecode(await f.readAsString()));
    } catch (_) {
      return null;
    }
  }

  /// Removes every batch file except [keep]. Called once the progress record
  /// points at [keep], so the older record was valid until then.
  Future<void> pruneBatches({String? keep}) async {
    try {
      await for (final entity in file.parent.list()) {
        final name = entity.uri.pathSegments.last;
        if (entity is File &&
            name.startsWith('export-batch-') &&
            (keep == null || name != 'export-batch-$keep.json')) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> clear() async {
    // The marker only explains why a batch stopped; once the batch is dealt
    // with (finished, resumed or dismissed) it must go too, otherwise it
    // would describe a later crash as a voluntary close.
    await pruneBatches();
    for (final target in [file, dismissedFile]) {
      try {
        if (await target.exists()) await target.delete();
      } catch (_) {}
    }
  }
}
