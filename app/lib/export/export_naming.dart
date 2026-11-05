import 'dart:io';
import 'export_options.dart';

class ResolvedExportName {
  final String stem;
  final Set<String> missing;
  ResolvedExportName(this.stem, this.missing);
}

ResolvedExportName resolveExportName(List<NamingPart> template, String filename,
    Map<String, String> fields, int sequence) {
  final missing = <String>{};
  final time =
      RegExp(r'^(\d{4})[:-](\d{2})[:-](\d{2})[ T](\d{2}):(\d{2}):(\d{2})')
          .firstMatch(fields['time'] ?? '');
  final values = <String, String>{
    'name': filename.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    'seq': '$sequence',
    'seq:3': sequence.toString().padLeft(3, '0'),
    'camera': fields['camera'] ?? '',
    'lens': fields['lens'] ?? '',
    'iso': fields['iso'] ?? '',
    'focal': fields['focal'] ?? '',
    'fnum': fields['aperture'] ?? '',
    'shutter': fields['shutter'] ?? '',
    if (time != null) ...{
      'date': '${time[1]}${time[2]}${time[3]}',
      'time': '${time[4]}${time[5]}${time[6]}',
      'yyyy': time[1]!,
      'MM': time[2]!,
      'dd': time[3]!,
      'HH': time[4]!,
      'mm': time[5]!,
      'ss': time[6]!
    }
  };
  final result = template
      .map((part) {
        if (!part.variable) return part.value;
        if (!namingVariables.values
            .any((group) => group.containsKey(part.value))) {
          throw FormatException('不支持的命名变量：${part.value}');
        }
        final value = values[part.value] ?? '';
        if (value.trim().isEmpty) {
          missing.add(part.value);
          return '未填写';
        }
        return value;
      })
      .join()
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
      .trim()
      .replaceAll(RegExp(r'[. ]+$'), '');
  if (result.isEmpty) throw const FormatException('命名模板不能生成空文件名');
  var stem = result;
  if (RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
          caseSensitive: false)
      .hasMatch(stem)) stem = '_$stem';
  if (stem.length > 180) stem = String.fromCharCodes(stem.runes.take(100));
  return ResolvedExportName(stem, missing);
}

String exportPathKey(String path) =>
    File(path).absolute.path.replaceAll('\\', '/').toLowerCase();

Future<String> unusedExportPath(String directory, String stem, String extension,
    Set<String> reserved) async {
  for (var number = 0;; number++) {
    final suffix = number == 0 ? '' : '_$number';
    final path = '$directory/$stem$suffix.$extension';
    if (!reserved.contains(exportPathKey(path)) && !await File(path).exists()) {
      reserved.add(exportPathKey(path));
      return path;
    }
  }
}
