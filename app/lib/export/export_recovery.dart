import 'dart:convert';
import 'dart:io';
import '../export/export_options.dart';
import '../photo_state.dart';

/// One photo still waiting to be exported.
class RecoveryJob {
  final String source, target, stem;
  const RecoveryJob(this.source, this.target, this.stem);
  Map<String, dynamic> toJson() =>
      {'source': source, 'target': target, 'stem': stem};
  static RecoveryJob? fromJson(Object? json) {
    if (json is! Map) return null;
    final source = json['source'], target = json['target'];
    if (source is! String || target is! String || source.isEmpty) return null;
    return RecoveryJob(source, target, json['stem'] as String? ?? '');
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
  const ExportRecovery(this.fileName,
      {this.width,
      this.height,
      this.pending = const [],
      this.completed = 0,
      this.skipped = const [],
      this.options});

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
        if (pending.isNotEmpty) 'pending': [for (final j in pending) j.toJson()],
        if (options != null) ...{
          'directory': options!.directory,
          'format': options!.format,
          'quality': options!.quality,
          'sizeEdge': options!.sizeEdge,
          'edgePixels': options!.edgePixels,
          'retainCaptureInfo': options!.retainCaptureInfo,
          'retainGps': options!.retainGps,
          'scope': options!.scope
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
    ExportOptions? options;
    final directory = json['directory'];
    if (directory is String && directory.isNotEmpty) {
      options = ExportOptions()
        ..directory = directory
        ..format = json['format'] == 'png' ? 'png' : 'jpg'
        ..quality = (json['quality'] as int? ?? 92).clamp(1, 100)
        ..sizeEdge = json['sizeEdge'] == 'short' ? 'short' : 'long'
        ..edgePixels = dim(json['edgePixels'])
        ..retainCaptureInfo = json['retainCaptureInfo'] != false
        ..retainGps = json['retainGps'] == true
        ..scope = json['scope'] as String? ?? 'selected';
    }
    return ExportRecovery(name,
        width: dim(json['width']),
        height: dim(json['height']),
        pending: pending,
        completed: json['completed'] as int? ?? 0,
        skipped: skipped,
        options: options);
  }
}

String exportRecoveryMessage(ExportRecovery note, {bool closedByUser = false}) {
  final size = note.pixels == null
      ? ''
      : '这张照片约 ${(note.pixels! / 10000).round()} 万像素。';
  final rest = note.canResume ? '这一批还剩 ${note.pending.length} 张没有导出。' : '';
  final why = closedByUser
      ? '上次导出「${note.fileName}」时，软件在导出过程中被关闭了，这一批没有做完。'
      : '上次导出「${note.fileName}」时软件自己停住了，不是正常关闭。';
  return '$why$size$rest\n\n'
      '成片接近上限（最长边 16384 像素，总计约 1.34 亿像素）时，内存可能不够，软件会卡住或闪退。'
      '如果继续，会跳过中断时正在处理的那一张，避免一直卡在同一张上；已导出的不会重做。';
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

  Future<void> write(ExportRecovery note) async {
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
      final note = ExportRecovery.fromJson(jsonDecode(await file.readAsString()));
      return note ?? const ExportRecovery('一张照片');
    } catch (_) {
      return const ExportRecovery('一张照片');
    }
  }

  Future<void> clear() async {
    // The marker only explains why a batch stopped; once the batch is dealt
    // with (finished, resumed or dismissed) it must go too, otherwise it
    // would describe a later crash as a voluntary close.
    for (final target in [file, dismissedFile]) {
      try {
        if (await target.exists()) await target.delete();
      } catch (_) {}
    }
  }
}
