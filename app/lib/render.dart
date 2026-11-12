import 'dart:io';
import 'photo_state.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'export/export_options.dart';
import 'export/color_management.dart';

// 在后台 isolate 执行。预览和导出采用同一套尺寸与构图规则。
Uint8List render((String, bool, int, bool) request) {
  return renderPhoto(
      (request.$1, request.$2, request.$3, request.$4, <String, String>{}));
}

Uint8List renderPhoto((String, bool, int, bool, Map<String, String>) request) {
  final (path, film, limit, png, fields) = request;
  final decoded = img.decodeImage(File(path).readAsBytesSync());
  if (decoded == null) throw FormatException('无法解码照片');
  var photo = decoded;
  if (limit > 0 && math.max(photo.width, photo.height) > limit) {
    photo = photo.width >= photo.height
        ? img.copyResize(photo, width: limit)
        : img.copyResize(photo, height: limit);
  }
  final (short, side, top, bottom) = layout(photo.width, photo.height, film);
  final frame = img.Image(
      width: photo.width + side * 2, height: photo.height + top + bottom);
  img.fill(frame,
      color: film ? img.ColorRgb8(12, 12, 12) : img.ColorRgb8(247, 242, 234));
  if (photo.numChannels == 3 && photo.format == img.Format.uint8) {
    final src = photo.buffer.asUint8List();
    final dst = frame.buffer.asUint8List();
    for (var y = 0; y < photo.height; y++) {
      final start = (top + y) * frame.rowStride + side * 3;
      dst.setRange(start, start + photo.width * 3, src, y * photo.rowStride);
    }
  } else {
    img.compositeImage(frame, photo, dstX: side, dstY: top);
  }
  final label = captionImage(film);
  final height = math.max(1, (short * .042).round());
  final scaled = img.copyResize(label, height: height);
  img.compositeImage(frame, scaled,
      dstX: film ? side : (frame.width - scaled.width) ~/ 2,
      dstY: top + photo.height + (bottom - height) ~/ 2);
  writeCaptureTags(decoded.exif, frame, fields);
  return png ? encodePhotoPng(frame) : img.encodeJpg(frame, quality: 92);
}

img.Image captionImage(bool film) {
  final caption = film ? 'FILM ARCHIVE' : 'Gallery Collection';
  final ink = film ? img.ColorRgb8(235, 183, 82) : img.ColorRgb8(55, 50, 46);
  final label =
      img.Image(width: caption.length * 28, height: 54, numChannels: 4);
  img.drawString(label, caption, font: img.arial48, color: ink);
  return label;
}

(int, int, int, int) layout(int width, int height, bool film) {
  final short = math.min(width, height);
  return (
    short,
    (short * (film ? .018 : .045)).ceil(),
    (short * (film ? .067 : .045)).ceil(),
    (short * (film ? .10 : .17)).ceil()
  );
}

void writeCaptureTags(
    img.ExifData? source, img.Image frame, Map<String, String> fields) {
  final original = readCaptureFields(source);
  final supplied = {
    for (final entry in fields.entries)
      if (infoFields.containsKey(entry.key) &&
          entry.value.isNotEmpty &&
          validateInfo(entry.key, entry.value) == null &&
          (entry.key == 'place' || original[entry.key] != entry.value))
        entry.key: entry.value,
  };
  if (source != null) copyCaptureTags(source, frame, supplied.keys.toSet());
  applyInfo(frame.exif, supplied);
}

void copyCaptureTags(
    img.ExifData source, img.Image frame, Set<String> replaced) {
  const tagsByField = <String, Set<int>>{
    'camera': {0x0110},
    'lens': {0xa432, 0xa433, 0xa434},
    'time': {0x9003, 0x9291},
    'shutter': {0x829a, 0x9201},
    'aperture': {0x829d, 0x9202},
    'iso': {0x8827, 0x8830, 0x8831, 0x8832, 0x8833},
    'focal': {0x920a, 0xa405},
  };
  final excluded = {
    for (final field in replaced) ...?tagsByField[field],
  };
  final out = frame.exif;
  for (final tag in [0x010f, 0x0110, 0x0132]) {
    if (!excluded.contains(tag)) out.imageIfd[tag] = source.imageIfd[tag];
  }
  // 拍摄时间、曝光、ISO、焦距、镜头及对应时区。只复制原有字段。
  for (final tag in [
    0x829a,
    0x829d,
    0x8822,
    0x8827,
    0x8830,
    0x8831,
    0x8832,
    0x8833,
    0x9003,
    0x9004,
    0x9010,
    0x9011,
    0x9012,
    0x9201,
    0x9202,
    0x9204,
    0x9207,
    0x9209,
    0x920a,
    0x9290,
    0x9291,
    0x9292,
    0xa405,
    0xa432,
    0xa433,
    0xa434
  ]) {
    if (!excluded.contains(tag)) {
      out.exifIfd[tag] = source.exifIfd[tag] ?? source.imageIfd[tag];
    }
  }
  out.imageIfd.orientation = 1;
  out.exifIfd[0xa002] = img.IfdValueLong(frame.width);
  out.exifIfd[0xa003] = img.IfdValueLong(frame.height);
}

Uint8List encodePhotoPng(img.Image frame) {
  final png = img.encodePng(frame, level: 1);
  final exif = img.OutputBuffer();
  frame.exif.write(exif);
  final chunk = img.OutputBuffer(bigEndian: true);
  final payload = exif.getBytes();
  final body = Uint8List.fromList([...'eXIf'.codeUnits, ...payload]);
  var crc = 0xffffffff;
  for (final byte in body) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc >>> 1) ^ ((crc & 1) == 0 ? 0 : 0xedb88320);
    }
  }
  chunk
    ..writeUint32(payload.length)
    ..writeBytes(body)
    ..writeUint32(crc ^ 0xffffffff);
  // PNG 固定首块 IHDR 结束于第 33 字节，eXIf 放在 IDAT 前。
  return (BytesBuilder(copy: false)
        ..add(Uint8List.sublistView(png, 0, 33))
        ..add(chunk.getBytes())
        ..add(Uint8List.sublistView(png, 33)))
      .takeBytes();
}

// Native TextPainter produces these pixels using the exact preview layout.
Uint8List encodeStyledPixels(
    (Uint8List, int, int, String, Map<String, String>, bool) request) {
  final (pixels, width, height, path, fields, png) = request;
  final frame = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: pixels.buffer,
      bytesOffset: pixels.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba);
  final bytes = File(path).readAsBytesSync();
  final source = captureExif(bytes) ?? img.decodeImage(bytes)?.exif;
  writeCaptureTags(source, frame, fields);
  return png ? encodePhotoPng(frame) : img.encodeJpg(frame, quality: 92);
}

Uint8List encodeExportPixels(
    (
      Uint8List,
      int,
      int,
      String,
      Map<String, String>,
      ExportOptions,
      Uint8List
    ) request) {
  final (pixels, width, height, path, fields, options, profile) = request;
  var frame = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: pixels.buffer,
      bytesOffset: pixels.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba);
  return finishExport(frame, path, fields, options, profile);
}

Uint8List finishExport(img.Image frame, String path, Map<String, String> fields,
    ExportOptions options, Uint8List profile) {
  final source = captureExif(File(path).readAsBytesSync());
  if (options.retainCaptureInfo) {
    writeCaptureTags(source, frame, fields);
  }
  if (options.retainGps && source != null)
    frame.exif.gpsIfd.data.addAll(source.gpsIfd.data);
  frame.exif.imageIfd.orientation = 1;
  frame.exif.exifIfd[0xa002] = img.IfdValueLong(frame.width);
  frame.exif.exifIfd[0xa003] = img.IfdValueLong(frame.height);
  frame.exif.exifIfd[0xa001] = img.IfdValueShort(1);
  return embedSrgbProfile(
      options.format == 'png'
          ? encodePhotoPng(frame)
          : img.encodeJpg(frame, quality: options.quality),
      profile,
      options.format == 'png');
}

Uint8List renderLegacyExport(
    (
      Uint8List,
      int,
      int,
      bool,
      String,
      Map<String, String>,
      ExportOptions,
      Uint8List
    ) request) {
  final (pixels, width, height, film, path, fields, options, profile) = request;
  final photo = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: pixels.buffer,
      bytesOffset: pixels.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba);
  final (short, side, top, bottom) = layout(width, height, film);
  if (options.edgePixels == null)
    validateExportSize(width + side * 2, height + top + bottom);
  var frame = img.Image(width: width + side * 2, height: height + top + bottom);
  img.fill(frame,
      color: film ? img.ColorRgb8(12, 12, 12) : img.ColorRgb8(247, 242, 234));
  img.compositeImage(frame, photo, dstX: side, dstY: top);
  final label = img.copyResize(captionImage(film),
      height: math.max(1, (short * .042).round()));
  img.compositeImage(frame, label,
      dstX: film ? side : (frame.width - label.width) ~/ 2,
      dstY: top + height + (bottom - label.height) ~/ 2);
  if (options.edgePixels != null) {
    final ratio = options.edgePixels! /
        (options.sizeEdge == 'long'
            ? math.max(frame.width, frame.height)
            : math.min(frame.width, frame.height));
    final w = math.max(1, (frame.width * ratio).round()),
        h = math.max(1, (frame.height * ratio).round());
    validateExportSize(w, h);
    frame = img.copyResize(frame,
        width: w, height: h, interpolation: img.Interpolation.cubic);
  }
  return finishExport(frame, path, fields, options, profile);
}

class ExportSizeException implements Exception {
  const ExportSizeException();
  @override
  String toString() => exportSizeLimitMessage;
}

bool exceedsExportLimit(int width, int height) =>
    width < 1 ||
    height < 1 ||
    width > exportMaxEdge ||
    height > exportMaxEdge ||
    width * height > exportMaxPixels;

/// Longest side that still fits even when the photo is square.
int exportSafeLongEdge(int requested) {
  var edge = requested < 1
      ? 1
      : (requested > exportMaxEdge ? exportMaxEdge : requested);
  if (edge * edge <= exportMaxPixels) return edge;
  var low = 1, high = edge;
  while (low < high) {
    final mid = (low + high + 1) >> 1;
    if (mid * mid <= exportMaxPixels) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return low;
}

void validateExportSize(int width, int height) {
  if (exceedsExportLimit(width, height)) throw const ExportSizeException();
}

/// Full-size pixels are used when they fit. A photo past the limit is opened
/// smaller only after the user has chosen an export size that can fit.
Future<ManagedPhoto> openForExport(String path, ExportOptions options) async {
  try {
    final photo = await decodeSrgbPhoto(path);
    if (!exceedsExportLimit(photo.width, photo.height)) return photo;
    if (options.edgePixels == null) throw const ExportSizeException();
  } on PhotoDecodeException catch (error) {
    if (!error.tooLarge || options.edgePixels == null) rethrow;
  }
  final reduced = await decodeSrgbPhoto(path,
      maxEdge: exportSafeLongEdge(options.edgePixels!));
  if (exceedsExportLimit(reduced.width, reduced.height))
    throw const ExportSizeException();
  return reduced;
}
