import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/directory_browser.dart';

/// 真实目录监视：复制一张照片进当前目录，应当收到一次刷新通知；
/// 连续复制多张只合并成少数几次。
void main() {
  test('新增照片会触发刷新通知', () async {
    final root = Directory('build/export-ui-check-0161-watch')
      ..createSync(recursive: true);
    final target = Directory('${root.path}/photos')..createSync(recursive: true);
    final watch = PhotoFolderWatch();
    var fired = 0;
    var firstAt = Duration.zero;
    final clock = Stopwatch()..start();
    await watch.start([target.path], recursive: false, onChanged: () {
      fired++;
      if (fired == 1) firstAt = clock.elapsed;
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    File('${target.path}/新照片.jpg').writeAsBytesSync([1, 2, 3]);
    // 等防抖窗口过去。
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    watch.stop();
    expect(fired, greaterThanOrEqualTo(1));
    expect(firstAt.inMilliseconds, lessThan(2500));
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('停止监视后不再通知', () async {
    final root = Directory('build/export-ui-check-0161-watch/stopped')
      ..createSync(recursive: true);
    final watch = PhotoFolderWatch();
    var fired = 0;
    await watch.start([root.path], recursive: false, onChanged: () => fired++);
    watch.stop();
    File('${root.path}/之后新增.jpg').writeAsBytesSync([9]);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(fired, 0);
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('子目录里的新增也通知', () async {
    final root = Directory('build/export-ui-check-0161-watch/nested')
      ..createSync(recursive: true);
    final child = Directory('${root.path}/子目录')..createSync(recursive: true);
    final watch = PhotoFolderWatch();
    var fired = 0;
    await watch.start([root.path], recursive: true, onChanged: () => fired++);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    File('${child.path}/深层.jpg').writeAsBytesSync([4]);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    watch.stop();
    expect(fired, greaterThanOrEqualTo(1));
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('删除照片也会触发刷新通知', () async {
    final root = Directory('build/export-ui-check-0161-watch/deleted')
      ..createSync(recursive: true);
    final photo = File('${root.path}/要被删掉.jpg')..writeAsBytesSync([7]);
    final watch = PhotoFolderWatch();
    var fired = 0;
    await watch.start([root.path], recursive: false, onChanged: () => fired++);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    photo.deleteSync();
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    watch.stop();
    expect(fired, greaterThanOrEqualTo(1));
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('合并连续多次事件', () async {
    final root = Directory('build/export-ui-check-0161-watch/burst')
      ..createSync(recursive: true);
    final watch = PhotoFolderWatch();
    var fired = 0;
    await watch.start([root.path], recursive: false, onChanged: () => fired++);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (var i = 0; i < 8; i++) {
      File('${root.path}/连续$i.jpg').writeAsBytesSync([i]);
    }
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    watch.stop();
    expect(fired, greaterThanOrEqualTo(1));
    expect(fired, lessThanOrEqualTo(3), reason: '连续写入不应触发太多次重扫');
  }, timeout: const Timeout(Duration(minutes: 1)));
}

