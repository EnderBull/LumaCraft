import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/photo_state.dart';
import 'package:lumacraft/render.dart';

void main() {
  final sampleDirectory = Platform.environment['LUMACRAFT_EXIF_SAMPLES'];
  if (sampleDirectory != null) {
    test('local JPEG samples retain GPS and clean capture information', () {
      final samples = Directory(sampleDirectory)
          .listSync()
          .whereType<File>()
          .where((file) =>
              RegExp(r'\.jpe?g$', caseSensitive: false).hasMatch(file.path))
          .toList();
      expect(samples, isNotEmpty);
      for (final file in samples) {
        final fields = readCapture(file.path);
        expect(fields.containsKey(gpsField), isTrue);
        for (final key in ['camera', 'lens', 'time']) {
          expect((fields[key] ?? '').contains('\u0000'), isFalse);
        }
        final time = fields['time'];
        if (time != null) expect(validateInfo('time', time), isNull);
      }
      expect(readCapture('$sampleDirectory/DSC05957.jpg')['aperture'], '1.4');
      // Keep the paths and coordinates of the user's photos out of the log.
      // ignore: avoid_print
      print('Checked ${samples.length} local JPEG samples.');
    });
  }

  test('GPS combines degrees, minutes and seconds with the hemisphere', () {
    final exif = img.ExifData();
    exif.gpsIfd
      ..gpsLatitudeRef = 'S\u0000'
      ..gpsLongitudeRef = 'W'
      ..[0x0002] = img.IfdValueRational.list([
        for (final n in [0, 15, 30]) img.IfdValueRational(n, 1).toRational()
      ])
      ..[0x0004] = img.IfdValueRational.list([
        for (final n in [0, 7, 30]) img.IfdValueRational(n, 1).toRational()
      ]);

    expect(readCaptureFields(exif)[gpsField], '-0.125000,-0.258333');
  });

  test('camera and time discard NUL padding and time uses EXIF format', () {
    final exif = img.ExifData();
    exif.imageIfd[0x0110] = 'ILCE-7RM4\u0000\u0000';
    exif.exifIfd[0x9003] = '2024-12-30 08:00:09\u0000';

    final fields = readCaptureFields(exif);
    expect(fields['camera'], 'ILCE-7RM4');
    expect(fields['time'], '2024:12:30 08:00:09');
    expect(fields['lens'], isNull);
    expect(
        PhotoState.fromJson({'captureTime': '2024-12-30 08:00:09\u0000'})
            .captureTime,
        fields['time']);
  });

  test('rounded exposure display preserves the original rational on export',
      () {
    final exif = img.ExifData();
    exif.exifIfd[0x829d] = img.IfdValueRational(11744051, 8388608);
    final fields = readCaptureFields(exif);
    expect(fields['aperture'], '1.4');

    final frame = img.Image(width: 1, height: 1);
    writeCaptureTags(exif, frame, fields);
    final aperture = frame.exif.exifIfd[0x829d]!.toRational();
    expect(aperture.numerator, 11744051);
    expect(aperture.denominator, 8388608);
  });

  test('shutter displays a familiar fraction when it represents the value', () {
    final exif = img.ExifData();
    exif.exifIfd[0x829a] = img.IfdValueRational(1, 250);
    expect(readCaptureFields(exif)['shutter'], '1/250');
    exif.exifIfd[0x829a] = img.IfdValueRational(3, 10);
    expect(readCaptureFields(exif)['shutter'], '0.3');
  });
}
