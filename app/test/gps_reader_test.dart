import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/photo_state.dart';

/// GPS 读取：北纬东经为正，南纬西经为负，没有坐标时不返回。
///
/// 用生成的固定测试照片，不依赖用户电脑上的私人照片。
void main() {
  const folder = 'build/gps-fixtures';

  void ensureFixtures() {
    if (Directory(folder).existsSync() &&
        File('$folder/gps-hangzhou.jpg').existsSync()) return;
    fail('缺少测试照片，请先运行 gps_fixture_test.dart 生成');
  }

  test('杭州：北纬东经为正', () {
    ensureFixtures();
    final gps = readCapture('$folder/gps-hangzhou.jpg')[gpsField];
    expect(gps, isNotNull);
    final parts = gps!.split(',');
    final lon = double.parse(parts[0]), lat = double.parse(parts[1]);
    expect(lon, closeTo(120.130264, .01));
    expect(lat, closeTo(30.259244, .01));
    // 经度在前，和小地图接口要求一致。
    expect(lon.abs(), greaterThan(lat.abs()));
  });

  test('悉尼：南纬变成负数', () {
    ensureFixtures();
    final gps = readCapture('$folder/gps-sydney.jpg')[gpsField]!;
    final lat = double.parse(gps.split(',')[1]);
    expect(lat, lessThan(0), reason: '南纬应为负');
    expect(lat, closeTo(-33.868820, .01));
  });

  test('纽约：西经变成负数', () {
    ensureFixtures();
    final gps = readCapture('$folder/gps-newyork.jpg')[gpsField]!;
    final lon = double.parse(gps.split(',')[0]);
    expect(lon, lessThan(0), reason: '西经应为负');
    expect(lon, closeTo(-74.005974, .01));
  });

  test('没有坐标时不返回 _gps', () {
    ensureFixtures();
    final info = readCapture('$folder/gps-none.jpg');
    expect(info.containsKey(gpsField), isFalse);
    // 但相机信息仍然读得到。
    expect(info['camera'], 'TESTCAM');
  });

  test('坐标精确到 6 位小数', () {
    ensureFixtures();
    final gps = readCapture('$folder/gps-hangzhou.jpg')[gpsField]!;
    for (final part in gps.split(',')) {
      expect(part.split('.').last.length, 6);
    }
  });

  test('_gps 不出现在可编辑字段里', () {
    expect(infoFields.containsKey(gpsField), isFalse,
        reason: '坐标只用于查地名，不能给用户改');
  });
}
