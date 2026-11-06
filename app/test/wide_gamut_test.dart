import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/export/color_management.dart';

/// Copies the sRGB profile and swaps the primaries for Display P3 ones. The
/// header and tag table stay valid, which is all the detector reads.
Uint8List withP3Primaries(Uint8List srgb) {
  final out = Uint8List.fromList(srgb);
  final data = ByteData.sublistView(out);
  const p3 = <String, List<double>>{
    'rXYZ': [0.5151, 0.2412, -0.0011],
    'gXYZ': [0.2920, 0.6922, 0.0419],
    'bXYZ': [0.1571, 0.0666, 0.7840]
  };
  for (var i = 0; i < data.getUint32(128); i++) {
    final entry = 132 + i * 12;
    final tag = String.fromCharCodes(out.sublist(entry, entry + 4));
    final values = p3[tag];
    if (values == null) continue;
    final offset = data.getUint32(entry + 4);
    for (var c = 0; c < 3; c++) {
      data.setInt32(offset + 8 + c * 4, (values[c] * 65536).round());
    }
  }
  return out;
}

void main() {
  test('只有比 sRGB 更宽的颜色说明才算广色域', () async {
    final profile =
        await Process.run(colorToolPath(), ['--profile'], stdoutEncoding: null);
    expect(profile.exitCode, 0);
    final srgb = Uint8List.fromList(profile.stdout as List<int>);
    expect(iccIsWideGamut(srgb), isFalse);
    final p3 = withP3Primaries(srgb);
    expect(iccIsWideGamut(p3), isTrue);
    expect(iccIsWideGamut(Uint8List(0)), isFalse);
    expect(iccIsWideGamut(p3.sublist(0, 100)), isFalse);
  });

  test('广色域 JPG 走 Windows 转换，普通 sRGB JPG 仍走快速解码', () async {
    final dir = Directory('build/export-ui-check-0150-wide')
      ..createSync(recursive: true);
    final picture = img.Image(width: 40, height: 30);
    img.fill(picture, color: img.ColorRgb8(120, 90, 60));
    final encoded = Uint8List.fromList(img.encodeJpg(picture, quality: 95));
    final profile =
        await Process.run(colorToolPath(), ['--profile'], stdoutEncoding: null);
    final srgb = Uint8List.fromList(profile.stdout as List<int>);
    final plain = File('${dir.path}/plain.jpg')
      ..writeAsBytesSync(embedSrgbProfile(encoded, srgb, false));
    final wide = File('${dir.path}/wide.jpg')
      ..writeAsBytesSync(embedSrgbProfile(encoded, withP3Primaries(srgb), false));
    expect(jpegUsesWideGamut(plain.path), isFalse);
    expect(jpegUsesWideGamut(wide.path), isTrue);
    // A file larger than the 256 KB head read must not overflow that buffer.
    final big = img.Image(width: 1200, height: 900);
    img.fill(big, color: img.ColorRgb8(30, 200, 120));
    for (var y = 0; y < big.height; y += 3) {
      img.drawLine(big,
          x1: 0,
          y1: y,
          x2: big.width - 1,
          y2: y,
          color: img.ColorRgb8(y % 255, 20, 200 - (y % 200)));
    }
    final bigFile = File('${dir.path}/big.jpg')
      ..writeAsBytesSync(img.encodeJpg(big, quality: 100));
    expect(await bigFile.length(), greaterThan(262144));
    expect(jpegUsesWideGamut(bigFile.path), isFalse);
    final plainImage = await decodePhotoImage(plain.path, maxEdge: 40);
    final wideImage = await decodePhotoImage(wide.path, maxEdge: 40);
    expect(plainImage.width, 40);
    expect(wideImage.width, 40);
    plainImage.dispose();
    wideImage.dispose();
  });
}
