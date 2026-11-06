import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/export/color_management.dart';
import 'package:lumacraft/photo_state.dart';

void main() {
  const root = 'test/fixtures/heic';
  test('HEIC 能读出拍摄时间，且不把方向标记再转一次', () async {
    final info = readCapture('$root/exif-gps-date.heic');
    expect(info['time'], '2026:01:01 12:00:00');
    final turned = captureExif(await File('$root/orientation-6.heic').readAsBytes());
    expect(turned?.imageIfd.orientation, 6);
    final managed = await decodeSrgbPhoto('$root/orientation-6.heic');
    expect(managed.width, 1200);
    expect(managed.height, 800);
  });

  test('普通 HEIC 可解码，预览按最长边缩小', () async {
    final full = await decodeSrgbPhoto('$root/basic-8bit-srgb.heic');
    expect(full.width, 1600);
    expect(full.height, 1200);
    final preview = await decodeSrgbPhoto('$root/basic-8bit-srgb.heic', maxEdge: 100);
    expect(mathMax(preview.width, preview.height), 100);
    expect(preview.width, 100);
    expect(preview.height, 75);
    final small = await decodeSrgbPhoto('$root/orientation-4.heic', maxEdge: 240);
    final arrow = small.rgba[(80 * small.width + 48) * 4];
    final arrowBlue = small.rgba[(80 * small.width + 48) * 4 + 2];
    expect(arrow, greaterThan(180), reason: '缩小后黄色箭头不能变成青色');
    expect(arrowBlue, lessThan(80));
  });

  test('手机那种拼合大图能按完整尺寸打开', () async {
    final managed = await decodeSrgbPhoto('$root/grid-12mp-512px-tiles.heic', maxEdge: 320);
    expect(managed.width, 320);
    expect(managed.height, 240);
  });

  test('整张高亮度 HDR 会说明无法打开，损坏文件也会说明', () async {
    expect(
        () => decodeSrgbPhoto('$root/hdr-pq-10bit-bt2020.heic'),
        throwsA(isA<PhotoDecodeException>().having(
            (error) => error.message, 'message', contains('高亮度'))));
    expect(
        () => decodeSrgbPhoto('$root/broken-truncated.heic'),
        throwsA(isA<PhotoDecodeException>().having(
            (error) => error.message, 'message', contains('损坏'))));
  });
}

int mathMax(int a, int b) => a > b ? a : b;
