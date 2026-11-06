import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/photo_state.dart';

/// 测量「每 2 秒核对一次文件夹」到底有多重。
void main() {
  test('列举目录耗时', () async {
    Future<Duration> time(String tag, Directory dir, {bool recursive = false}) async {
      final clock = Stopwatch()..start();
      const rounds = 20;
      for (var i = 0; i < rounds; i++) {
        await for (final entity in dir.list(
            recursive: recursive, followLinks: false)) {
          if (entity is File) photoFilePattern.hasMatch(entity.path);
        }
      }
      clock.stop();
      final per = clock.elapsedMicroseconds / rounds / 1000;
      // ignore: avoid_print
      print('PERF $tag: ${per.toStringAsFixed(2)} ms/次');
      return clock.elapsed;
    }

    for (final count in [200, 2000, 10000]) {
      final dir = Directory('build/perf-$count');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);
      for (var i = 0; i < count; i++) {
        File('${dir.path}/photo$i.jpg').writeAsStringSync('');
      }
      await time('$count 个文件', dir);
    }

    // 递归：40 个子目录、共 6000 张。
    final deep = Directory('build/perf-deep');
    if (deep.existsSync()) deep.deleteSync(recursive: true);
    deep.createSync(recursive: true);
    for (var d = 0; d < 40; d++) {
      final sub = Directory('${deep.path}/album$d')..createSync();
      for (var i = 0; i < 150; i++) {
        File('${sub.path}/p$i.jpg').writeAsStringSync('');
      }
    }
    await time('递归 40 个子目录 / 6000 文件', deep, recursive: true);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
