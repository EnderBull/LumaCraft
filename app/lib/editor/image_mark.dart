import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'background_style.dart';

class ImageMark {
  String data, filename;
  double width, ratio;
  ImageMark(
      {this.data = '', this.filename = '', this.width = 180, this.ratio = 1});
  Map<String, dynamic> toJson() =>
      {'data': data, 'filename': filename, 'width': width, 'ratio': ratio};
  factory ImageMark.fromJson(Map<String, dynamic> j) => ImageMark(
      data: j['data'] is String ? j['data'] : '',
      filename: j['filename'] is String ? j['filename'] : '',
      width: styleNumber(j, 'width', 180, 4, 2000),
      ratio: styleNumber(j, 'ratio', 1, .001, 1000));
}

// Cache owns originals; scenes own clones so eviction cannot invalidate a frame.
final _images = <String, ui.Image>{};
final _loading = <String, Future<void>>{};
final _pins = <Object, Set<String>>{};
void pinImageMarks(Object owner, Iterable<ImageMark> marks) {
  _pins[owner] = marks.map((m) => m.data).where((s) => s.isNotEmpty).toSet();
}

void releaseImageMarks(Object owner) {
  _pins.remove(owner);
  _trimImages({});
}

void _trimImages(Set<String> keep) {
  final protected = {...keep, ..._pins.values.expand((keys) => keys)};
  for (final key in _images.keys.toList()) {
    final bytes = _images.values
        .fold<int>(0, (sum, image) => sum + image.width * image.height * 4);
    if (_images.length <= 16 && bytes <= 64 * 1024 * 1024) break;
    if (!protected.contains(key)) _images.remove(key)?.dispose();
  }
}

ui.Image? imageMarkClone(String data) => _images[data]?.clone();
bool imageMarkReady(String data) => data.isEmpty || _images.containsKey(data);
Future<void> prepareImageMarks(Iterable<ImageMark> marks) async {
  final data = marks.map((m) => m.data).where((s) => s.isNotEmpty).toSet();
  for (final key in data) {
    if (_images.containsKey(key)) continue;
    await (_loading[key] ??= _decodeMark(key));
  }
  _trimImages(data);
}

Future<void> _decodeMark(String key) async {
  try {
    final codec = await ui.instantiateImageCodec(base64Decode(key));
    try {
      _images[key] = (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  } finally {
    _loading.remove(key);
  }
}

Future<ImageMark> importImageMark(String path) async {
  final file = File(path);
  if (await file.length() > 12 * 1024 * 1024)
    throw const FormatException('图片超过 12 MB，请缩小后导入');
  final result = await compute(_normaliseMark, await file.readAsBytes());
  return ImageMark(
      data: result.$1,
      ratio: result.$2,
      filename: path.split(RegExp(r'[/\\]')).last);
}

(String, double) _normaliseMark(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('无法读取图片，请使用 PNG 或 JPG');
  var image = img.bakeOrientation(decoded);
  final ratio = image.width / image.height;
  if (math.max(image.width, image.height) > 2048) {
    image = img.copyResize(image,
        width: image.width >= image.height ? 2048 : null,
        height: image.height > image.width ? 2048 : null,
        interpolation: img.Interpolation.average);
  }
  final isJpeg = bytes.length > 2 && bytes[0] == 0xff && bytes[1] == 0xd8;
  final encoded =
      isJpeg ? img.encodeJpg(image, quality: 95) : img.encodePng(image);
  return (base64Encode(encoded), ratio);
}
