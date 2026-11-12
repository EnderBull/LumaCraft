import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/style_render.dart';
import 'package:lumacraft/export/color_management.dart';
import 'package:lumacraft/export/export_options.dart';
import 'package:lumacraft/photo_state.dart';
import 'package:lumacraft/render.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Mac P3 HEIC 导出 JPG 和 PNG，成片含 sRGB ICC 与补填 EXIF', () async {
    final path = File('test/fixtures/heic/display-p3-10bit.heic').absolute.path;
    final managed = await openForExport(path, ExportOptions());
    expect(managed.width, greaterThan(0));
    expect(managed.height, greaterThan(0));
    expect(iccIsWideGamut(managed.profile), isFalse);
    expect(String.fromCharCodes(managed.profile.sublist(36, 40)), 'acsp');
    final photo = await managed.image();
    addTearDown(photo.dispose);
    for (final png in [false, true]) {
      final bytes = await renderStyledPhoto(
        path,
        StyleDocument.template(),
        {'camera': 'MAC TEST', 'iso': '800'},
        png,
        options: ExportOptions()..format = png ? 'png' : 'jpg',
        managedPhoto: photo,
        srgbProfile: managed.profile,
      );
      final binary = String.fromCharCodes(bytes);
      expect(binary, contains(png ? 'iCCP' : 'ICC_PROFILE'));
      final exif = captureExif(bytes);
      expect(exif, isNotNull);
      expect(readCaptureFields(exif!), containsPair('camera', 'MAC TEST'));
      expect(readCaptureFields(exif), containsPair('iso', '800'));
    }
  }, skip: !Platform.isMacOS);
}
