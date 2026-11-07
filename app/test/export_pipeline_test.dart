import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/export/color_management.dart';
import 'package:lumacraft/export/export_naming.dart';
import 'package:lumacraft/export/export_options.dart';
import 'package:lumacraft/export/export_preferences.dart';
import 'package:lumacraft/export/export_task.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/style_render.dart';
import 'package:lumacraft/photo_state.dart';

Uint8List embeddedProfile(Uint8List bytes, bool png) {
  final data = ByteData.sublistView(bytes);
  if (png) {
    for (var p = 8; p + 12 <= bytes.length;) {
      final n = data.getUint32(p),
          type = String.fromCharCodes(bytes.sublist(p + 4, p + 8));
      if (type == 'iCCP') {
        final payload = bytes.sublist(p + 8, p + 8 + n),
            zero = bytes.indexOf(0, p + 8) - p - 8;
        return Uint8List.fromList(zlib.decode(payload.sublist(zero + 2)));
      }
      p += n + 12;
    }
  } else {
    final pieces = <int, List<int>>{};
    for (var p = 2; p + 4 <= bytes.length;) {
      final marker = bytes[p + 1];
      if (marker == 0xda || marker == 0xd9) break;
      final n = data.getUint16(p + 2);
      if (marker == 0xe2 &&
          String.fromCharCodes(bytes.sublist(p + 4, p + 15)) == 'ICC_PROFILE') {
        pieces[bytes[p + 16]] = bytes.sublist(p + 18, p + 2 + n);
      }
      p += n + 2;
    }
    if (pieces.isNotEmpty)
      return Uint8List.fromList(
          [for (final key in pieces.keys.toList()..sort()) ...pieces[key]!]);
  }
  throw StateError('没有嵌入实际ICC');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory output;
  setUpAll(() async {
    output = await Directory(
            'test/export-output/run-${DateTime.now().millisecondsSinceEpoch}')
        .create(recursive: true);
  });
  test('命名变量、缺失字段、偏好、保留编号和替换发布', () async {
    final name = resolveExportName(
        [
          NamingPart.variable('date'),
          NamingPart.text('_'),
          NamingPart.variable('seq:3')
        ],
        'source.jpg',
        {'time': '2021:06:20 16:45:01'},
        9);
    expect(name.stem, '20210620_009');
    expect(
        resolveExportName(defaultNamingTemplate(), 'DSC_3079.jpg', {}, 1).stem,
        'DSC_3079_LumaCraft');
    expect(
        resolveExportName([NamingPart.variable('lens')], 'x.jpg', {}, 1)
            .missing,
        {'lens'});
    expect(resolveExportName([NamingPart.text('CON')], 'x.jpg', {}, 1).stem,
        '_CON');
    expect(resolveExportName([NamingPart.text('A/B:*?')], 'x.jpg', {}, 1).stem,
        'A_B___');
    final options = ExportOptions()
      ..directory = output.path
      ..edgePixels = 2400
      ..sizeEdge = 'short'
      ..retainGps = true;
    final preferences =
        ExportPreferences(File('${output.path}/preferences.json'));
    await preferences.save(options, defaultNamingTemplate());
    final loaded = await preferences.load();
    expect(loaded.$1.edgePixels, 2400);
    expect(loaded.$1.retainGps, true);
    final source = File('${output.path}/source.jpg');
    await source.writeAsString('source');
    final target = File('${output.path}/test.jpg');
    await target.writeAsString('old');
    final reserved = <String>{};
    final unused = await unusedExportPath(output.path, 'test', 'jpg', reserved);
    expect(unused, endsWith('test_1.jpg'));
    expect(await unusedExportPath(output.path, 'test', 'jpg', reserved),
        endsWith('test_2.jpg'));
    final keep = ExportJob(source, null, false, {}, 'test', unused);
    await publishExport(keep, utf8.encode('new'), replace: false);
    expect(await target.readAsString(), 'old');
    final replace = ExportJob(source, null, false, {}, 'test', target.path)
      ..replacedStat = FileSnapshot.of(await target.stat());
    await publishExport(replace, utf8.encode('replacement'), replace: true);
    expect(await target.readAsString(), 'replacement');
    expect(await source.readAsString(), 'source');
  });
  test('Windows源ICC真正转换，横竖尺寸、EXIF、GPS与JPG/PNG的sRGB ICC读回', () async {
    final profileProcess =
        await Process.run(colorToolPath(), ['--profile'], stdoutEncoding: null);
    expect(profileProcess.exitCode, 0);
    final profile = Uint8List.fromList(profileProcess.stdout as List<int>);
    final linear = Uint8List.fromList(profile),
        table = ByteData.sublistView(linear);
    for (var i = 0; i < table.getUint32(128); i++) {
      final p = 132 + i * 12,
          tag = String.fromCharCodes(linear.sublist(p, p + 4));
      if (['rTRC', 'gTRC', 'bTRC'].contains(tag)) {
        final offset = table.getUint32(p + 4),
            count = table.getUint32(offset + 8);
        expect(
            String.fromCharCodes(linear.sublist(offset, offset + 4)), 'curv');
        expect(count, greaterThan(1));
        for (var j = 0; j < count; j++) {
          table.setUint16(
              offset + 12 + j * 2, (j * 65535 / (count - 1)).round());
        }
      }
    }
    final picture = img.Image(width: 150, height: 100);
    img.fill(picture, color: img.ColorRgb8(128, 128, 128));
    picture.exif.imageIfd[0x0110] = 'COLOR CAMERA';
    picture.exif.imageIfd.orientation = 6;
    picture.exif.exifIfd[0x9003] = '2021:06:20 16:45:01';
    picture.exif.exifIfd[0x8827] = 200;
    picture.exif.gpsIfd[1] = img.IfdValueAscii('N');
    final source = File('${output.path}/linear-input.jpg');
    await source.writeAsBytes(embedSrgbProfile(
        Uint8List.fromList(img.encodeJpg(picture, quality: 100)),
        linear,
        false));
    final managed = await decodeSrgbPhoto(source.path);
    expect(managed.width, 100);
    expect(managed.height, 150);
    expect(managed.rgba[0], inInclusiveRange(180, 195),
        reason: '线性RGB的128须转换到约188，不能只更改ICC标签');
    final photo = await managed.image();
    final style =
        StyleDocument(borders: {'top': 0, 'right': 0, 'bottom': 0, 'left': 0});
    for (final png in [false, true]) {
      final options = ExportOptions()
        ..format = png ? 'png' : 'jpg'
        ..edgePixels = png ? 240 : 120
        ..sizeEdge = png ? 'long' : 'short'
        ..retainCaptureInfo = !png
        ..retainGps = !png;
      final bytes = await renderStyledPhoto(source.path, style, {}, png,
          options: options, managedPhoto: photo, srgbProfile: managed.profile);
      await File('${output.path}/managed.${options.format}')
          .writeAsBytes(bytes);
      expect(embeddedProfile(bytes, png), profile);
      final decoded = img.decodeImage(bytes)!;
      expect(decoded.width, png ? 160 : 120);
      expect(decoded.height, png ? 240 : 180);
      final exif = captureExif(bytes)!;
      expect(exif.imageIfd.orientation, 1);
      expect(exif.exifIfd[0xa002]!.toInt(), decoded.width);
      expect(exif.exifIfd[0xa001]!.toInt(), 1);
      expect(exif.imageIfd[0x0110]?.toString(), png ? null : 'COLOR CAMERA');
      expect(exif.gpsIfd.isEmpty, png);
    }
    photo.dispose();
    expect(captureExif(await source.readAsBytes())!.imageIfd.orientation, 6);
  });
}
