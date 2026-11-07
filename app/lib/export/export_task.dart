import 'dart:io';
import '../editor/style_document.dart';

/// What a file looked like when the user agreed to replace it. A FileStat
/// cannot be rebuilt from disk, and the record has to survive a restart.
class FileSnapshot {
  final FileSystemEntityType type;
  final int size;
  final DateTime modified;
  const FileSnapshot(this.type, this.size, this.modified);
  factory FileSnapshot.of(FileStat stat) =>
      FileSnapshot(stat.type, stat.size, stat.modified);
  bool matches(FileStat now) =>
      now.type == type && now.size == size && now.modified == modified;
}

class ExportJob {
  final File source;
  final StyleDocument? style;
  final bool film;
  final Map<String, String> fields;
  final String stem;
  String target;
  FileSnapshot? replacedStat;
  ExportJob(
      this.source, this.style, this.film, this.fields, this.stem, this.target);
}

/// A staged file is only published after encoding has completed.
Future<void> publishExport(ExportJob job, List<int> data,
    {required bool replace}) async {
  final out = File(job.target);
  final stage = File('${job.target}.lumacraft-${newObjectId()}.pending');
  await stage.writeAsBytes(data, flush: true);
  if (replace && job.replacedStat != null) {
    if (!job.replacedStat!.matches(await out.stat())) {
      throw FileSystemException(
          '目标文件在确认后发生变化，已停止替换；临时文件保留在 ${stage.path}', out.path);
    }
  } else {
    try {
      await out.create(exclusive: true);
    } on FileSystemException {
      throw FileSystemException(
          '目标文件已被其他操作创建；请重试并重新选择重名处理方式。临时文件：${stage.path}', out.path);
    }
  }
  await stage.rename(out.path);
}
