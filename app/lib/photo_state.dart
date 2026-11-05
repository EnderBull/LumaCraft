import 'dart:convert';
import 'editor/style_document.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

const infoFields = <String, String>{
  'camera': '相机型号',
  'lens': '镜头型号',
  'time': '拍摄时间（YYYY:MM:DD HH:mm:ss）',
  'focal': '焦距 mm',
  'aperture': '光圈 f 值',
  'shutter': '快门秒（如 1/250）',
  'iso': 'ISO',
  'place': '地点'
};

img.ExifData? captureExif(Uint8List bytes) {
  final jpg = img.decodeJpgExif(bytes);
  if (jpg != null) return jpg;
  if (bytes.length < 8 ||
      bytes[0] != 137 ||
      String.fromCharCodes(bytes.sublist(1, 4)) != 'PNG') return null;
  final data = ByteData.sublistView(bytes);
  var offset = 8;
  while (offset + 12 <= bytes.length) {
    final length = data.getUint32(offset);
    if (length > bytes.length - offset - 12) return null;
    final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
    if (type == 'eXIf')
      return img.ExifData.fromInputBuffer(img.InputBuffer(
          Uint8List.sublistView(bytes, offset + 8, offset + 8 + length)));
    offset += length + 12;
  }
  return null;
}

Map<String, String> readCapture(String path) {
  final exif = captureExif(File(path).readAsBytesSync());
  if (exif == null) return {};
  final values = <String, String>{};
  void add(String key, Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) values[key] = text;
  }

  add('camera', exif.imageIfd[0x0110]);
  add('lens', exif.exifIfd[0xa434]);
  add('time', exif.exifIfd[0x9003]);
  for (final pair
      in {'focal': 0x920a, 'aperture': 0x829d, 'shutter': 0x829a}.entries) {
    final value = exif.exifIfd[pair.value];
    if (value != null) {
      final number = value.toDouble();
      if (number > 0)
        add(
            pair.key,
            pair.key == 'shutter' && number < 1
                ? '1/${(1 / number).round()}'
                : number.toString());
    }
  }
  add('iso', exif.exifIfd[0x8827]);
  return values;
}

String? validateInfo(String key, String value) {
  if (value.isEmpty || key == 'camera' || key == 'lens' || key == 'place')
    return null;
  if (key == 'time') {
    final match = RegExp(r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$')
        .firstMatch(value);
    if (match != null) {
      final n = List.generate(6, (i) => int.parse(match.group(i + 1)!));
      final date = DateTime(n[0], n[1], n[2], n[3], n[4], n[5]);
      if (date.year == n[0] &&
          date.month == n[1] &&
          date.day == n[2] &&
          date.hour == n[3] &&
          date.minute == n[4] &&
          date.second == n[5]) return null;
    }
    return '拍摄时间格式或日期无效';
  }
  final parts = value.split('/');
  final a = double.tryParse(parts.first);
  final b = parts.length == 2 ? double.tryParse(parts.last) : 1.0;
  if (parts.length > 2 ||
      a == null ||
      b == null ||
      !a.isFinite ||
      !b.isFinite ||
      a <= 0 ||
      b <= 0 ||
      (key != 'shutter' && parts.length > 1)) return '请输入有效正数';
  if (key == 'iso' && (int.tryParse(value) == null || a > 65535))
    return 'ISO 应为 1–65535 的整数';
  return null;
}

void applyInfo(img.ExifData exif, Map<String, String> fields) {
  for (final pair in fields.entries) {
    final key = pair.key, value = pair.value;
    if (value.isEmpty || validateInfo(key, value) != null) continue;
    if (key == 'camera') exif.imageIfd[0x0110] = value;
    if (key == 'lens') exif.exifIfd[0xa434] = value;
    if (key == 'time') exif.exifIfd[0x9003] = value;
    if (key == 'iso')
      exif.exifIfd[0x8827] = img.IfdValueShort(int.parse(value));
    final tag = {'focal': 0x920a, 'aperture': 0x829d, 'shutter': 0x829a}[key];
    if (tag != null) {
      final parts = value.split('/');
      final number = double.parse(parts.first) /
          (parts.length == 2 ? double.parse(parts.last) : 1);
      exif.exifIfd[tag] =
          img.IfdValueRational((number * 1000000).round(), 1000000);
    }
  }
}

class PhotoState {
  bool film = false;
  StyleDocument? style;
  String? styleSource;
  String editorSourceKey(String path) =>
      '$path::${styleSource ?? (film ? "legacy-film" : "legacy-gallery")}';
  bool edited = false;
  final fields = <String, String>{};
  PhotoState();
  PhotoState.fromJson(Map<String, dynamic> json) {
    film = json['film'] == true;
    styleSource = json['styleSource'] as String?;
    if (json['style'] != null)
      style = StyleDocument.fromJson(Map<String, dynamic>.from(json['style']));
    edited = json['edited'] == true;
    fields.addAll(Map<String, String>.from(json['fields'] as Map? ?? {}));
  }
  Map<String, dynamic> toJson() => {
        'film': film,
        if (styleSource != null) 'styleSource': styleSource,
        'edited': edited,
        'fields': fields,
        if (style != null) 'style': style!.toJson()
      };
  Map<String, String> effective(Map<String, String> original) =>
      {...original, ...fields};
  void supplement(Map<String, String> original, Map<String, String> updates,
      bool overwrite) {
    for (final e in updates.entries) {
      if (e.value.isNotEmpty &&
          (overwrite || (fields[e.key] ?? original[e.key] ?? '').isEmpty)) {
        fields[e.key] = e.value;
        edited = true;
      }
    }
  }
}

class PhotoStore {
  final File file;
  final photos = <String, PhotoState>{};
  PhotoStore(this.file);
  static File defaultFile() {
    final dataDirectory = Platform.environment['LUMACRAFT_DATA_DIR'];
    if (dataDirectory != null && dataDirectory.isNotEmpty)
      return File('$dataDirectory/photo-state.json');
    var dir = File(Platform.resolvedExecutable).parent;
    while (dir.parent.path != dir.path) {
      if (File('${dir.path}/pubspec.yaml').existsSync())
        return File('${dir.path}/local/photo-state.json');
      dir = dir.parent;
    }
    return File(
        '${File(Platform.resolvedExecutable).parent.path}/local/photo-state.json');
  }

  Future<void> load() async {
    if (!await file.exists()) return;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (json['version'] != 1) throw const FormatException('不支持的本地记录版本');
    for (final e in (json['photos'] as Map<String, dynamic>).entries) {
      photos[e.key] = PhotoState.fromJson(e.value as Map<String, dynamic>);
    }
  }

  PhotoState state(String path) => photos.putIfAbsent(path, PhotoState.new);
  Future<void> _pending = Future.value();
  Future<void> save() {
    final contents = jsonEncode({
      'version': 1,
      'photos': photos.map((k, v) => MapEntry(k, v.toJson()))
    });
    final next = _pending.then((_) async {
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.pending');
      await temp.writeAsString(contents, flush: true);
      await temp.rename(file.path);
    });
    _pending = next.catchError((Object _) {});
    return next;
  }
}

// 当前预览跟随仍被选中的照片，避免 Ctrl 取消后编辑到其他范围。
class PhotoSelection {
  final paths = <String>{};
  int current = 0;
  int anchor = 0;
  void reset(List<String> files) {
    paths.clear();
    current = 0;
    anchor = 0;
    if (files.isNotEmpty) paths.add(files.first);
  }

  void click(List<String> files, int clicked,
      {bool control = false, bool shift = false}) {
    if (shift) {
      if (!control) paths.clear();
      final start = anchor < clicked ? anchor : clicked;
      final end = anchor > clicked ? anchor : clicked;
      paths.addAll(files.sublist(start, end + 1));
      current = clicked;
    } else if (control) {
      if (!paths.add(files[clicked])) {
        paths.remove(files[clicked]);
        if (paths.isNotEmpty && !paths.contains(files[current])) {
          current = files.indexOf(paths.last);
        }
      } else {
        current = clicked;
      }
      anchor = clicked;
    } else {
      paths
        ..clear()
        ..add(files[clicked]);
      current = clicked;
      anchor = clicked;
    }
  }
}

class InfoSummary {
  final values = <String, int>{};
  int missing = 0;
  InfoSummary(Iterable<Map<String, String>> photos, String key) {
    for (final photo in photos) {
      final value = (photo[key] ?? '').trim();
      if (value.isEmpty) {
        missing++;
      } else {
        values.update(value, (count) => count + 1, ifAbsent: () => 1);
      }
    }
  }
  String get initial => values.length == 1 ? values.keys.single : '';
  String get hint => values.isEmpty ? '缺失' : '多个不同值';
  int get present => values.values.fold(0, (total, count) => total + count);
  String get description => '已有 $present 张 · 缺失 $missing 张';
}
