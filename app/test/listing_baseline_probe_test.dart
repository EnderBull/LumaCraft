import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/directory_browser.dart';
import 'package:lumacraft/photo_state.dart';

/// 目录列表基线测量：只量不改。输出以 BASE 开头的行。
/// 量什么：扫描耗时、扫描期间界面线程被卡住的最长时间、
/// 并发扫描的结果是否残缺、一批文件变动会触发几次刷新。
void main() {
  final root = Directory('build/perf-baseline');

  Directory make(String name, int dirs, int perDir, {int bytes = 0}) {
    final dir = Directory('${root.path}/$name');
    if (dir.existsSync()) return dir;
    dir.createSync(recursive: true);
    final data = Uint8List(bytes);
    for (var d = 0; d < dirs; d++) {
      final sub = dirs == 1 ? dir : Directory('${dir.path}/album$d')
        ..createSync();
      for (var i = 0; i < perDir; i++) {
        File('${sub.path}/p$i.jpg').writeAsBytesSync(data);
      }
    }
    return dir;
  }

  /// 同时跑一个高频小定时器，记录事件循环被卡住的最长时间。
  Future<T> withJank<T>(String tag, Future<T> Function() body) async {
    var last = Stopwatch()..start();
    var worst = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 5), (_) {
      final gap = last.elapsedMilliseconds;
      if (gap > worst) worst = gap;
      last = Stopwatch()..start();
    });
    final clock = Stopwatch()..start();
    final result = await body();
    clock.stop();
    timer.cancel();
    // ignore: avoid_print
    print('BASE $tag: 总耗时 ${clock.elapsedMilliseconds} ms，'
        '界面线程最长被卡 $worst ms');
    return result;
  }

  setUpAll(() => root.createSync(recursive: true));

  test('collect 耗时与卡顿：1 万张平铺 / 2 万张 40 个子目录', () async {
    final flat = make('flat10k', 1, 10000);
    final tree = make('tree20k', 40, 500);
    final scanner = PhotoScanner();
    for (final run in [1, 2]) {
      final a = await withJank('collect 1万平铺 第$run次', () async {
        return scanner.collect([flat.path], recursive: false);
      });
      expect(a.files.length, 10000);
      final b = await withJank('collect 2万/40子目录 第$run次', () async {
        return scanner.collect([tree.path], recursive: true);
      });
      expect(b.files.length, 20000);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('startMany 首次扫描 2 万张：批次数和卡顿', () async {
    final tree = make('tree20k', 40, 500);
    final scanner = PhotoScanner();
    var batches = 0, total = 0;
    final done = Completer<void>();
    await withJank('startMany 2万/40子目录', () async {
      scanner.startMany([tree.path],
          recursive: true,
          onBatch: (b) {
            batches++;
            total += b.length;
          },
          onDone: (_) => done.complete(),
          onError: (_) {});
      await done.future;
    });
    // ignore: avoid_print
    print('BASE startMany: $batches 批，共 $total 张（每批界面都要合并排序一次）');
    expect(total, 20000);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('并发扫描：后一次会不会让前一次拿到残缺结果', () async {
    final tree = make('tree20k', 40, 500);
    final scanner = PhotoScanner();
    final first = scanner.collect([tree.path], recursive: true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final second = scanner.collect([tree.path], recursive: true);
    final a = await first, b = await second;
    expect(a.cancelled, isFalse);
    expect(a.files.length, 20000, reason: '后一次扫描不能让前一次拿到残缺结果');
    expect(b.files.length, 20000);
    // ignore: avoid_print
    print('BASE 并发 collect：先发起的拿到 ${a.files.length} 张（应为 20000），'
        '后发起的拿到 ${b.files.length} 张');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('首次扫描进行中又触发 collect：首次扫描是否被打断', () async {
    final tree = make('tree20k', 40, 500);
    final scanner = PhotoScanner();
    var total = 0;
    var finished = false;
    scanner.startMany([tree.path],
        recursive: true,
        onBatch: (b) => total += b.length,
        onDone: (_) => finished = true,
        onError: (_) {});
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final c = await scanner.collect([tree.path], recursive: true);
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    expect(finished, isTrue, reason: '插入的刷新不能打断首次扫描');
    expect(total, 20000);
    expect(c.files.length, 20000);
    expect(c.cancelled, isFalse);
    // ignore: avoid_print
    print('BASE 扫描中插入 collect：首次扫描已收到 $total 张，'
        '是否正常结束 $finished；collect 拿到 ${c.files.length} 张');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('明确取消后，进行中的 collect 标记为已取消（调用方必须丢弃）', () async {
    final tree = make('tree20k', 40, 500);
    final scanner = PhotoScanner();
    final pending = scanner.collect([tree.path], recursive: true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    scanner.cancel();
    final r = await pending;
    expect(r.cancelled, isTrue);
    expect(r.files.length, lessThan(20000));
  });

  test('后台算指纹：结果与同步算法一致，界面不被卡住', () async {
    final dir = make('fingerprint2k', 1, 2000, bytes: 70 * 1024);
    final paths = [for (final f in dir.listSync().whereType<File>()) f.path];
    final expected = {for (final p in paths.take(50)) p: photoFingerprint(p)};
    var last = Stopwatch()..start();
    var worst = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 5), (_) {
      final gap = last.elapsedMilliseconds;
      if (gap > worst) worst = gap;
      last = Stopwatch()..start();
    });
    final result = await fingerprintPaths(paths);
    timer.cancel();
    // ignore: avoid_print
    print('BASE 后台指纹：${paths.length} 张，界面最长被卡 $worst ms');
    expect(result.length, paths.length);
    for (final e in expected.entries) {
      expect(result[e.key], e.value);
    }
    expect(worst, lessThan(100), reason: '界面线程不能被指纹计算长时间占住');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('扫描完成后逐张算指纹（relinkAfterScan 同步循环）会卡多久', () async {
    // 真实照片一般几 MB，指纹只读头尾各 32 KB；用 70 KB 文件即可代表读取量。
    final dir = make('fingerprint2k', 1, 2000, bytes: 70 * 1024);
    final files = dir.listSync().whereType<File>().toList();
    final clock = Stopwatch()..start();
    var worst = 0;
    for (final f in files) {
      final one = Stopwatch()..start();
      photoFingerprint(f.path);
      if (one.elapsedMicroseconds > worst) worst = one.elapsedMicroseconds;
    }
    clock.stop();
    final per = clock.elapsedMicroseconds / files.length;
    // ignore: avoid_print
    print('BASE 指纹：${files.length} 张共 ${clock.elapsedMilliseconds} ms '
        '（每张约 ${per.toStringAsFixed(0)} µs，最慢一张 $worst µs），'
        '整个循环期间界面完全不响应；按 2 万张推算约 '
        '${(per * 20000 / 1000).round()} ms');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('一批文件变动触发几次刷新', () async {
    final dir = Directory('${root.path}/burst')..createSync(recursive: true);
    for (final e in dir.listSync()) {
      e.deleteSync(recursive: true);
    }
    final watch = PhotoFolderWatch();
    var calls = 0;
    await watch.start([dir.path], recursive: false, onChanged: () => calls++);
    // 500 张分约 3 秒写入，模拟拷贝。
    for (var i = 0; i < 500; i++) {
      File('${dir.path}/b$i.jpg').writeAsBytesSync([1]);
      if (i % 20 == 0) await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    final afterCopy = calls;
    for (final f in dir.listSync().whereType<File>()) {
      f.deleteSync();
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    watch.stop();
    // ignore: avoid_print
    print('BASE 通知：拷入 500 张触发 $afterCopy 次刷新，'
        '随后删除 500 张又触发 ${calls - afterCopy} 次');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
