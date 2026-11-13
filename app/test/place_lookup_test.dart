import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/photo_state.dart';
import 'package:lumacraft/settings/amap_service.dart';
import 'package:lumacraft/settings/app_settings.dart';
import 'package:lumacraft/settings/place_lookup.dart';

/// 自动填地点的触发条件：只在真的需要时查询，省用户的高德调用次数。
void main() {
  late AppSettings settings;
  late FakeGeocoder geocoder;

  setUp(() {
    geocoder = FakeGeocoder((location) async => const PlaceResult('浙江省杭州市西湖区'));
    settings = AppSettings(File(
        'build/export-ui-check-0286-lookup/settings-${DateTime.now().microsecondsSinceEpoch}.json'))
      ..amapKey = 'k'
      ..amapSecret = 's'
      ..autoFillPlace = true;
  });

  tearDown(() => settings.dispose());

  PlaceLookup build() => PlaceLookup(settings: settings, geocoder: geocoder);

  Map<String, String> infoWithGps([String? gps]) =>
      {if (gps != null) gpsField: gps};

  test('GPS 试用提示区分文件未读到坐标与高德请求失败', () async {
    var queried = false;
    final lookup = PlaceLookup(
        settings: settings,
        geocoder:
            FakeGeocoder((_) async => const PlaceResult(''), failWith: '连接失败'));
    expect(gpsDiagnosticText(infoWithGps()), '未读到 GPS');
    final info = infoWithGps('120.1,30.2');
    expect(gpsDiagnosticText(info), '已读到 GPS');
    final result = await lookup.fill(
        info: info,
        nodeTypes: const ['place'],
        existing: '',
        onQuery: () => queried = true);
    expect(queried, isTrue);
    expect(result, isNull);
    expect(gpsDiagnosticText(info, queryStatus: '高德查询失败'), '已读到 GPS · 高德查询失败');
  });

  test('预设没有地点组件时不查询', () async {
    final lookup = build();
    final result = await lookup.fill(
        info: infoWithGps('120.1,30.2'),
        nodeTypes: const ['text', 'camera'],
        existing: '');
    expect(result, isNull);
    expect(geocoder.calls, 0, reason: '用不到地点就不该消耗调用次数');
  });

  test('预设包含地点组件时查询', () async {
    final lookup = build();
    final result = await lookup.fill(
        info: infoWithGps('120.130264,30.259244'),
        nodeTypes: const ['text', 'place'],
        existing: '');
    expect(result, '浙江省杭州市西湖区');
    expect(geocoder.calls, 1);
  });

  test('已经手动填过地点时不覆盖', () async {
    final lookup = build();
    final result = await lookup.fill(
        info: infoWithGps('120.1,30.2'),
        nodeTypes: const ['place'],
        existing: '我自己写的地点');
    expect(result, isNull);
    expect(geocoder.calls, 0, reason: '用户填的内容不能被自动结果顶掉');
  });

  test('照片没有坐标时不查询', () async {
    final lookup = build();
    final result = await lookup.fill(
        info: infoWithGps(null), nodeTypes: const ['place'], existing: '');
    expect(result, isNull);
    expect(geocoder.calls, 0);
  });

  test('关掉自动填写后不查询', () async {
    settings.autoFillPlace = false;
    final lookup = build();
    final result = await lookup.fill(
        info: infoWithGps('120.1,30.2'),
        nodeTypes: const ['place'],
        existing: '');
    expect(result, isNull);
    expect(geocoder.calls, 0);
  });

  test('没配密钥时不查询', () async {
    settings.amapKey = '';
    final lookup = build();
    final result = await lookup.fill(
        info: infoWithGps('120.1,30.2'),
        nodeTypes: const ['place'],
        existing: '');
    expect(result, isNull);
    expect(geocoder.calls, 0);
  });

  test('同一坐标第二次直接用缓存', () async {
    final lookup = build();
    final first = await lookup.fill(
        info: infoWithGps('120.1,30.2'),
        nodeTypes: const ['place'],
        existing: '');
    final second = await lookup.fill(
        info: infoWithGps('120.1,30.2'),
        nodeTypes: const ['place'],
        existing: '');
    expect(first, second);
    expect(geocoder.calls, 1, reason: '同一地点只查一次');
  });

  test('同时请求同一坐标只发一次', () async {
    final lookup = build();
    await Future.wait([
      lookup.fill(
          info: infoWithGps('120.9,30.9'),
          nodeTypes: const ['place'],
          existing: ''),
      lookup.fill(
          info: infoWithGps('120.9,30.9'),
          nodeTypes: const ['place'],
          existing: ''),
    ]);
    expect(geocoder.calls, 1);
  });

  test('查询失败时返回空，不影响编辑', () async {
    final failing = PlaceLookup(
        settings: settings,
        geocoder: FakeGeocoder((location) async => const PlaceResult(''),
            failWith: '网络不通'));
    final result = await failing.fill(
        info: infoWithGps('120.1,30.2'),
        nodeTypes: const ['place'],
        existing: '');
    expect(result, isNull);
  });

  test('坐标格式不对时不会去查', () async {
    final lookup = build();
    final result = await lookup.fill(
        info: {gpsField: '不是坐标'}, nodeTypes: const ['place'], existing: '');
    expect(result, isNull);
  });
}
