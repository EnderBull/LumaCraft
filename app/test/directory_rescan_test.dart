import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/directory_browser.dart';

/// 文件夹变化后的重新读取：新增和删除都要反映出来，
/// 结果按路径排序，重复路径不重复出现。
void main() {
  test('重读能发现新增也能发现删除', () async {
    final root = Directory('build/export-ui-check-0162-rescan/fresh');
    if (root.existsSync()) root.deleteSync(recursive: true);
    root.createSync(recursive: true);
    final a = File('${root.path}/A.jpg')..writeAsBytesSync([1]);
    final b = File('${root.path}/B.jpg')..writeAsBytesSync([2]);
    final scanner = PhotoScanner();
    var result = await scanner.collect([root.path], recursive: false);
    expect(result.files.map((f) => f.uri.pathSegments.last), ['A.jpg', 'B.jpg']);

    // 删掉 A，加一张 C。
    a.deleteSync();
    File('${root.path}/C.jpg').writeAsBytesSync([3]);
    result = await scanner.collect([root.path], recursive: false);
    expect(result.files.map((f) => f.uri.pathSegments.last), ['B.jpg', 'C.jpg']);
    expect(b.existsSync(), isTrue);
  });

  test('只算照片文件，子目录按开关决定', () async {
    final root = Directory('build/export-ui-check-0162-rescan/kinds');
    if (root.existsSync()) root.deleteSync(recursive: true);
    root.createSync(recursive: true);
    final child = Directory('${root.path}/子目录')..createSync(recursive: true);
    File('${root.path}/照片.jpg').writeAsBytesSync([1]);
    File('${root.path}/说明.txt').writeAsStringSync('x');
    File('${child.path}/深处.heic').writeAsBytesSync([2]);
    final scanner = PhotoScanner();
    var result = await scanner.collect([root.path], recursive: false);
    expect(result.files.length, 1);
    expect(result.files.single.uri.pathSegments.last, '照片.jpg');
    result = await scanner.collect([root.path], recursive: true);
    // 结果按完整路径排序，子目录里的文件会排在前面。
    expect(result.files.map((f) => f.uri.pathSegments.last).toSet(),
        {'照片.jpg', '深处.heic'});
  });

  test('重复选同一目录不会重复列出', () async {
    final root = Directory('build/export-ui-check-0162-rescan/dup');
    if (root.existsSync()) root.deleteSync(recursive: true);
    root.createSync(recursive: true);
    File('${root.path}/一张.jpg').writeAsBytesSync([1]);
    final scanner = PhotoScanner();
    final result =
        await scanner.collect([root.path, root.path], recursive: true);
    expect(result.files.length, 1);
  });

  test('目录不存在时记为跳过，不抛异常', () async {
    final scanner = PhotoScanner();
    final result = await scanner.collect(
        ['build/export-ui-check-0162-rescan/does-not-exist'],
        recursive: false);
    expect(result.files, isEmpty);
    expect(result.skipped, 1);
  });
}
