import 'dart:io';
import '../editor/style_document.dart';

class ExportJob {
  final File source;
  final StyleDocument? style;
  final bool film;
  final Map<String, String> fields;
  final String stem;
  String target;
  FileStat? replacedStat;
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
    final now = await out.stat(), before = job.replacedStat!;
    if (now.type != before.type ||
        now.size != before.size ||
        now.modified != before.modified) {
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
