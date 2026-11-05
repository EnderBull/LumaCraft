import 'dart:async';
import 'dart:io';
import '../../lib/directory_browser.dart';

Future<void> main() async {
  final root = Directory('output/directory-check');
  final child = Directory('${root.path}/child');
  await child.create(recursive: true);
  await File('${root.path}/one.jpg').writeAsString('scan fixture');
  await File('${child.path}/two.JPG').writeAsString('scan fixture');
  await File('${root.path}/skip.txt').writeAsString('not a photo');
  final scanner = PhotoScanner();
  Future<List<File>> scan(String path, bool recursive) async {
    final done = Completer<void>();
    final found = <File>[];
    scanner.start(path,
        recursive: recursive,
        onBatch: found.addAll,
        onDone: (_) => done.complete(),
        onError: (message) => throw StateError(message));
    await done.future;
    return found;
  }

  if ((await scan(root.path, false)).length != 1 ||
      (await scan(root.path, true)).length != 2) throw StateError('目录范围错误');
  final fresh = Completer<void>();
  final found = <File>[];
  var stale = false;
  scanner.start(root.path,
      recursive: true,
      onBatch: (_) => stale = true,
      onDone: (_) => stale = true,
      onError: (_) => stale = true);
  scanner.start(child.path,
      recursive: false,
      onBatch: found.addAll,
      onDone: (_) => fresh.complete(),
      onError: (e) => throw StateError(e));
  await fresh.future;
  scanner.cancel();
  if (stale || found.length != 1 || !found.single.path.endsWith('two.JPG')) {
    throw StateError('过期扫描结果进入新目录');
  }
  final directories = await childDirectories(root.path);
  print('children=$directories expected=${child.path} roots=${diskRoots()}');
  if (!directories
          .map((path) => Directory(path).absolute.uri)
          .contains(child.absolute.uri) ||
      diskRoots().isEmpty) {
    throw StateError('目录树或盘符读取错误');
  }
  print('PASS 磁盘、子目录、当前/递归范围与扫描取消');
}
