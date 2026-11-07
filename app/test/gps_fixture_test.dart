import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// 用 image 包生成一张带 GPS 的 JPG，确认读取逻辑正确。
void main() {
  final dir = Directory('build/gps-fixtures')..createSync(recursive: true);

  void write(String name, double? lat, double? lon,
      {String latRef = 'N', String lonRef = 'E'}) {
    final image = img.Image(width: 120, height: 90);
    img.fill(image, color: img.ColorRgb8(80, 120, 150));
    image.exif.imageIfd[0x0110] = 'TESTCAM';
    if (lat != null && lon != null) {
      image.exif.gpsIfd
        ..gpsLatitudeRef = latRef
        ..gpsLatitude = lat
        ..gpsLongitudeRef = lonRef
        ..gpsLongitude = lon;
    }
    File('${dir.path}/$name').writeAsBytesSync(img.encodeJpg(image));
  }

  test('准备带 GPS 的测试照片', () {
    // 杭州西湖附近
    write('gps-hangzhou.jpg', 30.259244, 120.130264);
    // 南半球：悉尼，南纬西经要用负数表示
    write('gps-sydney.jpg', 33.868820, 151.209290,
        latRef: 'S', lonRef: 'E');
    // 西半球：纽约
    write('gps-newyork.jpg', 40.712776, 74.005974,
        latRef: 'N', lonRef: 'W');
    // 没有 GPS
    write('gps-none.jpg', null, null);
    // ignore: avoid_print
    print('GEOFIX 已生成在 ${dir.path}');
    expect(Directory(dir.path).listSync().length, 4);
  });
}
