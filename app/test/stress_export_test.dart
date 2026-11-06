import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/style_render.dart';
import 'package:lumacraft/export/color_management.dart';
import 'package:lumacraft/export/export_options.dart';

/// 连续导出 30 张 4000x3000 的照片，走与界面完全相同的导出代码，
/// 并在每张之后读取自身内存，确认大批量导出不会越积越多。
/// 素材由本测试自己生成，不依赖仓库里的文件。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory photos, output;
  setUpAll(() async {
    final root = Directory('build/export-ui-check-0150-stress');
    photos = Directory('${root.path}/photos');
    output = Directory('${root.path}/out');
    await photos.create(recursive: true);
    await output.create(recursive: true);
    if (photos.listSync().length < 30) await generateStressPhotos(photos);
  });
  test('大批量导出内存与耗时', () async {
    final files = photos
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jpg'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(files.length, 30);
    final options = ExportOptions()
      ..directory = output.path
      ..edgePixels = null
      ..format = 'jpg'
      ..quality = 92;
    final profile =
        await Process.run(colorToolPath(), ['--profile'], stdoutEncoding: null);
    final srgb =
        Uint8List.fromList(profile.stdout as List<int>);
    final watch = Stopwatch()..start();
    var slowest = 0, peak = 0;
    for (var i = 0; i < files.length; i++) {
      final each = Stopwatch()..start();
      final managed = await decodeSrgbPhoto(files[i].path);
      expect(managed.width, 4000);
      expect(managed.height, 3000);
      final photo = await managed.image();
      late List<int> data;
      try {
        data = await renderStyledPhoto(
            files[i].path, StyleDocument.template(), const {}, false,
            options: options, managedPhoto: photo, srgbProfile: srgb);
      } finally {
        photo.dispose();
      }
      expect(data.length, greaterThan(1000));
      await File('${output.path}/${files[i].uri.pathSegments.last}')
          .writeAsBytes(data);
      each.stop();
      if (each.elapsedMilliseconds > slowest) slowest = each.elapsedMilliseconds;
      final rss = ProcessInfo.currentRss ~/ (1024 * 1024);
      if (rss > peak) peak = rss;
      // ignore: avoid_print
      print('photo ${i + 1}/30 ${each.elapsedMilliseconds}ms rss=${rss}MB');
    }
    watch.stop();
    // ignore: avoid_print
    print('TOTAL ${watch.elapsedMilliseconds}ms slowest=${slowest}ms peak=${peak}MB');
    expect(watch.elapsed.inSeconds, lessThan(600));
  }, timeout: const Timeout(Duration(minutes: 12)));
}

/// 30 张大图，只用软件自带的图像库生成，避免依赖外部素材。
Future<void> generateStressPhotos(Directory photos) async {
  final srgb = img.Image(width: 4000, height: 3000, numChannels: 3);
  for (var i = 0; i < 30; i++) {
    final hue = i * 12.0;
    for (var y = 0; y < srgb.height; y += 1) {
      final t = y / srgb.height;
      for (var x = 0; x < srgb.width; x += 1) {
        final s = (x / srgb.width + t) / 2;
        final rgb = _hsvToRgb((hue + s * 60) % 360, 0.65, 0.45 + s * 0.45);
        srgb.setPixelRgb(x, y, rgb[0], rgb[1], rgb[2]);
      }
    }
    final name = 'IMG_${(i + 1).toString().padLeft(4, '0')}_stress.jpg';
    await File('${photos.path}/$name')
        .writeAsBytes(img.encodeJpg(srgb, quality: 90));
  }
}

List<int> _hsvToRgb(double h, double s, double v) {
  final c = v * s, x = c * (1 - ((h / 60) % 2 - 1).abs()), m = v - c;
  final (r, g, b) = switch (h ~/ 60 % 6) {
    0 => (c, x, 0.0),
    1 => (x, c, 0.0),
    2 => (0.0, c, x),
    3 => (0.0, x, c),
    4 => (x, 0.0, c),
    _ => (c, 0.0, x)
  };
  return [
    ((r + m) * 255).round(),
    ((g + m) * 255).round(),
    ((b + m) * 255).round()
  ];
}
