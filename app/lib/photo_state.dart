import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'editor/style_document.dart';
import 'package:image/image.dart' as img;

final photoFilePattern =
    RegExp(r'\.(jpe?g|heic|heif|hif)$', caseSensitive: false);

bool heifPath(String path) =>
    RegExp(r'\.(heic|heif|hif)$', caseSensitive: false).hasMatch(path);

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

img.ExifData? _heifExif(Uint8List bytes) {
  if (bytes.length < 16 ||
      bytes[4] != 0x66 ||
      bytes[5] != 0x74 ||
      bytes[6] != 0x79 ||
      bytes[7] != 0x70) return null;
  for (var i = 0; i + 10 < bytes.length; i++) {
    if (bytes[i] != 0x45 ||
        bytes[i + 1] != 0x78 ||
        bytes[i + 2] != 0x69 ||
        bytes[i + 3] != 0x66 ||
        bytes[i + 4] != 0 ||
        bytes[i + 5] != 0) continue;
    final start = i + 6;
    final little = bytes[start] == 0x49 &&
        bytes[start + 1] == 0x49 &&
        bytes[start + 2] == 0x2a &&
        bytes[start + 3] == 0;
    final big = bytes[start] == 0x4d &&
        bytes[start + 1] == 0x4d &&
        bytes[start + 2] == 0 &&
        bytes[start + 3] == 0x2a;
    if (!little && !big) continue;
    try {
      return img.ExifData.fromInputBuffer(
          img.InputBuffer(Uint8List.sublistView(bytes, start)));
    } catch (_) {}
  }
  return null;
}

img.ExifData? captureExif(Uint8List bytes) {
  try {
    final jpg = img.decodeJpgExif(bytes);
    if (jpg != null) return jpg;
  } catch (_) {}
  final heif = _heifExif(bytes);
  if (heif != null) return heif;
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
  // Coordinates stay out of the info fields on purpose: they are only used to
  // look up a place name, and are never written into the exported file.
  final gps = readGpsCoordinates(exif);
  if (gps != null) values[gpsField] = gps;
  return values;
}

/// Key under which the raw coordinates travel, so the place lookup can find
/// them without another file read. Not part of [infoFields], so it never shows
/// up as an editable field.
const gpsField = '_gps';

/// "longitude,latitude" with 6 decimals, which is what the map service wants.
String? readGpsCoordinates(img.ExifData exif) {
  try {
    final gps = exif.gpsIfd;
    final latitude = gps.gpsLatitude;
    final longitude = gps.gpsLongitude;
    if (latitude == null || longitude == null) return null;
    if (!latitude.isFinite || !longitude.isFinite) return null;
    // Both zero means the camera had no fix, not a real place.
    if (latitude.abs() < 1e-6 && longitude.abs() < 1e-6) return null;
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    // The reference tag says which hemisphere: S and W are negative.
    final latRef = (gps.gpsLatitudeRef ?? 'N').toUpperCase();
    final lonRef = (gps.gpsLongitudeRef ?? 'E').toUpperCase();
    final lat = latRef.startsWith('S') ? -latitude : latitude;
    final lon = lonRef.startsWith('W') ? -longitude : longitude;
    return '${lon.toStringAsFixed(6)},${lat.toStringAsFixed(6)}';
  } catch (_) {
    // A GPS block that cannot be read is the same as no coordinates.
    return null;
  }
}

/// Cheap identity of a photo's content.
///
/// Reads the file size plus the first and last 32 KB. That is a few
/// milliseconds per photo even for a large file, and it changes as soon as
/// different pixels are stored — exactly what is needed to notice that two
/// file names were swapped.
String photoFingerprint(String path) {
  final handle = File(path).openSync();
  try {
    final length = handle.lengthSync();
    const sample = 32768;
    final head = Uint8List(sample);
    final headRead = handle.readIntoSync(head, 0, sample);
    final tail = Uint8List(sample);
    var tailRead = 0;
    if (length > sample) {
      handle.setPositionSync(length - sample);
      tailRead = handle.readIntoSync(tail, 0, sample);
    }
    var hash = 0xcbf29ce484222325;
    void mix(int byte) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
    }

    for (var i = 0; i < headRead; i++) {
      mix(head[i]);
    }
    for (var i = 0; i < tailRead; i++) {
      mix(tail[i]);
    }
    for (var i = 0; i < 8; i++) {
      mix((length >> (i * 8)) & 0xff);
    }
    return '${length.toRadixString(16)}-${hash.toRadixString(16)}';
  } finally {
    handle.closeSync();
  }
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

  /// Capture time as read from the file when the photo was first opened.
  /// Kept in the record so a moved photo can be recognised later.
  String? captureTime;

  /// Cheap identity of the photo's content. Records follow the picture, not
  /// the file name, so swapping two file names never swaps their styles.
  String? fingerprint;
  PhotoState();
  PhotoState.fromJson(Map<String, dynamic> json) {
    film = json['film'] == true;
    styleSource = json['styleSource'] as String?;
    if (json['style'] != null)
      style = StyleDocument.fromJson(Map<String, dynamic>.from(json['style']));
    edited = json['edited'] == true;
    captureTime = json['captureTime'] as String?;
    fingerprint = json['fingerprint'] as String?;
    fields.addAll(Map<String, String>.from(json['fields'] as Map? ?? {}));
  }
  Map<String, dynamic> toJson() => {
        'film': film,
        if (styleSource != null) 'styleSource': styleSource,
        'edited': edited,
        if (captureTime != null) 'captureTime': captureTime,
        if (fingerprint != null) 'fingerprint': fingerprint,
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
  /// True when the record carries something the user would miss. Capture time
  /// is read automatically, so it alone does not make a record worth keeping:
  /// it is kept from the file itself.
  bool get hasContent =>
      edited ||
      style != null ||
      fields.values.any((value) => value.trim().isNotEmpty);
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

  /// Moves a record to the photo's new location. A record that already holds
  /// real content wins, so the newer file is never overwritten by an old
  /// record; a record created merely by opening the folder is replaced.
  bool relink(String oldPath, String newPath) {
    final record = photos[oldPath];
    if (record == null) return false;
    if (oldPath == newPath) return false;
    final existing = photos[newPath];
    if (existing != null && existing.hasContent) {
      photos.remove(oldPath);
      return false;
    }
    photos.remove(oldPath);
    photos[newPath] = record;
    return true;
  }
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
