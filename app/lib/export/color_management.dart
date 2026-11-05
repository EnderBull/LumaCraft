import 'dart:io';
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

Future<ManagedPhoto> decodeSrgbPhoto(String path) async {
  if (!Platform.isWindows) throw UnsupportedError('此版本的受管理导出需要 Windows');
  final exif = captureExif(await File(path).readAsBytes());
  final orientation = exif?.imageIfd.orientation ?? 1;
  final result = await Process.run(
      colorToolPath(), [File(path).absolute.path, '$orientation'],
      stdoutEncoding: null, stderrEncoding: null);
  if (result.exitCode != 0)
    throw StateError('照片解码或色彩转换失败（${result.exitCode}），未生成带错误色彩标签的文件');
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
