import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';
import '../photo_state.dart';

class ManagedPhoto {
  final Uint8List rgba, profile;
  final int width, height;
  ManagedPhoto(this.rgba, this.width, this.height, this.profile);
  Future<ui.Image> image() {
    final result = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        rgba, width, height, ui.PixelFormat.rgba8888, result.complete);
    return result.future;
  }
}

String colorToolPath() {
  final override = Platform.environment['LUMACRAFT_COLOR_TOOL'];
  if (override != null && File(override).existsSync()) return override;
  final adjacent = File(
      '${File(Platform.resolvedExecutable).parent.path}/lumacraft_color_tool.exe');
  if (adjacent.existsSync()) return adjacent.path;
  final development =
      File('build/windows/x64/runner/Release/lumacraft_color_tool.exe');
  if (development.existsSync()) return development.absolute.path;
  throw StateError('缺少色彩转换工具，请使用完整的软件文件夹');
}

const heifCodecMissingMessage =
    '这台电脑还不能读取 HEIC。请在微软商店安装“HEIF 图像扩展”和“HEVC 视频扩展”，装好后再打开。';
const heifStoreProductId = '9PMMSR1CGPWG';
const hevcStoreProductId = '9N4WGH0Z6VHQ';

/// sRGB primaries as stored in a D50-adapted ICC matrix profile.
const _srgbMatrix = <double>[
  0.4360, 0.2225, 0.0139, //
  0.3851, 0.7169, 0.0971,
  0.1431, 0.0606, 0.7141
];

double _fixed(ByteData data, int offset) =>
    data.getInt32(offset, Endian.big) / 65536.0;

/// Head of a file, without pulling a large photo fully into memory.
Uint8List _readHeadSync(String path, int limit) {
  final handle = File(path).openSync();
  try {
    final buffer = Uint8List(limit);
    var filled = 0;
    while (filled < limit) {
      // readIntoSync takes an end index in the buffer, not a byte count.
      final read = handle.readIntoSync(buffer, filled, limit);
      if (read <= 0) break;
      filled += read;
    }
    return Uint8List.sublistView(buffer, 0, filled);
  } finally {
    handle.closeSync();
  }
}

/// True when the embedded ICC profile describes a wider space than sRGB
/// (Display P3, Adobe RGB, ProPhoto...). Flutter's own decoder ignores that
/// profile, so such photos must be converted by Windows or the preview is
/// visibly duller / more saturated than the exported file.
bool iccIsWideGamut(Uint8List profile) {
  if (profile.length < 132) return false;
  final header = ByteData.sublistView(profile);
  if (header.getUint32(0) > profile.length) return false;
  if (String.fromCharCodes(profile.sublist(16, 20)) != 'RGB ') return false;
  final count = header.getUint32(128);
  if (count == 0 || count > 64 || 132 + count * 12 > profile.length)
    return false;
  final primaries = <String, List<double>>{};
  for (var i = 0; i < count; i++) {
    final entry = 132 + i * 12;
    final tag = String.fromCharCodes(profile.sublist(entry, entry + 4));
    if (!['rXYZ', 'gXYZ', 'bXYZ'].contains(tag)) continue;
    final offset = header.getUint32(entry + 4), size = header.getUint32(entry + 8);
    if (size < 20 || offset + 20 > profile.length) return false;
    if (String.fromCharCodes(profile.sublist(offset, offset + 4)) != 'XYZ ')
      return false;
    final data = ByteData.sublistView(profile, offset, offset + 20);
    primaries[tag] = [
      _fixed(data, 8),
      _fixed(data, 12),
      _fixed(data, 16)
    ];
  }
  if (primaries.length != 3) return false;
  final actual = [
    ...primaries['rXYZ']!,
    ...primaries['gXYZ']!,
    ...primaries['bXYZ']!
  ];
  for (var i = 0; i < 9; i++) {
    if ((actual[i] - _srgbMatrix[i]).abs() > 0.012) return true;
  }
  return false;
}

/// Reads only the head of the file: the ICC profile sits before the pixels.
/// Sync on purpose: the preview is already async and tests must stay
/// deterministic.
bool jpegUsesWideGamut(String path) {
  if (heifPath(path)) return false;
  final head = _readHeadSync(path, 262144);
  if (head.length < 4 || head[0] != 0xff || head[1] != 0xd8) return false;
  final pieces = <int, Uint8List>{};
  var p = 2;
  while (p + 4 <= head.length) {
    if (head[p] != 0xff) break;
    final marker = head[p + 1];
    if (marker == 0xda || marker == 0xd9) break;
    final length = (head[p + 2] << 8) | head[p + 3];
    if (length < 2 || p + 2 + length > head.length) break;
    if (marker == 0xe2 &&
        p + 18 <= head.length &&
        String.fromCharCodes(head.sublist(p + 4, p + 15)) == 'ICC_PROFILE') {
      pieces[head[p + 16]] = head.sublist(p + 18, p + 2 + length);
    }
    p += 2 + length;
  }
  if (pieces.isEmpty) return false;
  final ordered = pieces.keys.toList()..sort();
  final profile = Uint8List.fromList(
      [for (final key in ordered) ...pieces[key]!]);
  return iccIsWideGamut(profile);
}

bool asksForHeifCodec(String message) =>
    message.contains(heifCodecMissingMessage);

Future<void> openMicrosoftStoreProduct(String productId) {
  // explorer.exe treats this address as a folder and opens Documents.
  return Process.run('rundll32', [
    'url.dll,FileProtocolHandler',
    'ms-windows-store://pdp/?ProductId=$productId'
  ]);
}

class PhotoDecodeException implements Exception {
  final String message;
  final bool tooLarge;
  const PhotoDecodeException(this.message, {this.tooLarge = false});
  @override
  String toString() => message;
}

String explainDecodeFailure(String detail, {required bool heif}) {
  final match = RegExp(r'0x([0-9A-Fa-f]+)').firstMatch(detail);
  final code = match == null ? '' : '0x${match.group(1)!.toUpperCase()}';
  if (code == '0x88982F80')
    return '这张照片按高亮度方式保存，当前无法打开。手机里常见的 HDR 仍可使用。';
  if (code == '0x88982F50' || code == '0x80040154')
    return heifCodecMissingMessage;
  if (code == '0x8007000E')
    return '这张照片太大，超过可导出的上限（最长边 16384 像素，总计约 1.34 亿像素），请缩小尺寸';
  if (heif && code == '0xC00D36BE') return '这张 HEIC 照片已损坏，无法打开。';
  if (heif) return '这张 HEIC 照片无法打开。';
  return '照片解码或色彩转换失败，未生成文件。';
}

Future<ManagedPhoto> decodeSrgbPhoto(String path, {int maxEdge = 0}) async {
  if (!Platform.isWindows) throw UnsupportedError('此版本的受管理导出需要 Windows');
  // HEIF 的方向已由系统解码器转正。再按文件里的方向标记转一次，画面会转歪。
  var orientation = 1;
  if (!heifPath(path)) {
    final exif = captureExif(await File(path).readAsBytes());
    orientation = exif?.imageIfd.orientation ?? 1;
  }
  final arguments = [File(path).absolute.path, '$orientation'];
  if (maxEdge > 0) arguments.add('$maxEdge');
  final result = await Process.run(colorToolPath(), arguments,
      stdoutEncoding: null, stderrEncoding: null);
  if (result.exitCode != 0) {
    final raw = result.stderr;
    final detail = raw is List<int>
        ? String.fromCharCodes(raw)
        : raw?.toString() ?? '';
    throw PhotoDecodeException(
        explainDecodeFailure(detail, heif: heifPath(path)),
        tooLarge: detail.toUpperCase().contains('0X8007000E'));
  }
  final bytes = Uint8List.fromList(result.stdout as List<int>);
  if (bytes.length < 16) throw const FormatException('色彩工具返回数据不完整');
  final header = ByteData.sublistView(bytes);
  final width = header.getUint32(4, Endian.little),
      height = header.getUint32(8, Endian.little);
  final profileSize = header.getUint32(12, Endian.little);
  if (header.getUint32(0, Endian.little) != 0x31434d4c ||
      width == 0 ||
      height == 0 ||
      profileSize < 128 ||
      bytes.length != 16 + profileSize + width * height * 4) {
    throw const FormatException('色彩工具返回的数据尺寸无效');
  }
  return ManagedPhoto(Uint8List.sublistView(bytes, 16 + profileSize), width,
      height, Uint8List.sublistView(bytes, 16, 16 + profileSize));
}

Future<ui.Image> _decodeWithFlutter(String path, int maxEdge) async {
  final buffer = await ui.ImmutableBuffer.fromFilePath(path);
  // The codec owns the buffer and releases the file handle when it is
  // disposed; disposing the buffer here as well trips an assertion.
  final codec = await ui.instantiateImageCodecWithSize(buffer,
      getTargetSize: (w, h) {
    final scale = math.min(1.0, maxEdge / math.max(w, h));
    return ui.TargetImageSize(
        width: math.max(1, (w * scale).round()),
        height: math.max(1, (h * scale).round()));
  });
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

/// 普通 sRGB 的 JPG 仍用界面自带解码，快且足够。HEIC 和带广色域说明的
/// JPG 交给 Windows，转成普通屏幕颜色，与导出结果一致。
/// 预览传入最长边，避免把手机原图整张展开。
Future<ui.Image> decodePhotoImage(String path, {required int maxEdge}) async {
  if (!heifPath(path) && !jpegUsesWideGamut(path)) {
    try {
      return await _decodeWithFlutter(path, maxEdge);
    } catch (e) {
      if (!Platform.isWindows) throw PhotoDecodeException('预览失败：$e');
    }
  }
  final managed = await decodeSrgbPhoto(path, maxEdge: maxEdge);
  return managed.image();
}

int _crc(List<int> bytes) {
  var crc = 0xffffffff;
  for (final value in bytes) {
    crc ^= value;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc >>> 1) ^ ((crc & 1) == 0 ? 0 : 0xedb88320);
    }
  }
  return crc ^ 0xffffffff;
}

/// Encode-time embedding: pixels must already be converted to this profile.
Uint8List embedSrgbProfile(Uint8List encoded, Uint8List profile, bool png) {
  if (profile.length < 128 ||
      String.fromCharCodes(profile.sublist(36, 40)) != 'acsp' ||
      String.fromCharCodes(profile.sublist(16, 20)) != 'RGB ') {
    throw const FormatException('sRGB ICC 配置无效');
  }
  final output = BytesBuilder(copy: false);
  if (png) {
    output.add(encoded.sublist(0, 33));
    final payload = [...'sRGB'.codeUnits, 0, 0, ...zlib.encode(profile)];
    final body = [...'iCCP'.codeUnits, ...payload];
    final length = ByteData(4)..setUint32(0, payload.length);
    final crc = ByteData(4)..setUint32(0, _crc(body));
    output
      ..add(length.buffer.asUint8List())
      ..add(body)
      ..add(crc.buffer.asUint8List());
    var offset = 33;
    final data = ByteData.sublistView(encoded);
    while (offset + 12 <= encoded.length) {
      final length = data.getUint32(offset), end = offset + length + 12;
      if (end > encoded.length) throw const FormatException('PNG 数据损坏');
      final type =
          String.fromCharCodes(encoded.sublist(offset + 4, offset + 8));
      // Avoid contradictory color declarations or duplicate profiles.
      if (!['iCCP', 'sRGB', 'gAMA', 'cHRM', 'cICP'].contains(type))
        output.add(encoded.sublist(offset, end));
      offset = end;
    }
  } else {
    if (encoded[0] != 255 || encoded[1] != 216)
      throw const FormatException('JPG 数据损坏');
    output.add(encoded.sublist(0, 2));
    const maximum = 65519;
    final count = (profile.length / maximum).ceil();
    for (var i = 0; i < count; i++) {
      final end = ((i + 1) * maximum).clamp(0, profile.length);
      final payload = [
        ...'ICC_PROFILE'.codeUnits,
        0,
        i + 1,
        count,
        ...profile.sublist(i * maximum, end)
      ];
      output.add([
        255,
        226,
        (payload.length + 2) >> 8,
        (payload.length + 2) & 255,
        ...payload
      ]);
    }
    output.add(encoded.sublist(2));
  }
  return output.takeBytes();
}
