import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/directory_browser.dart';

/// 到底需不需要「每 2 秒核对一次」这块兜底？
/// 分别验证三种删除方式能不能被 Windows 的文件通知捕获：
/// 彻底删除、改名、移动出文件夹。回收站删除另测。
void main() {
  Future<void> probe(String tag, Future<void> Function(File) act) async {
    final root = Directory('build/export-ui-check-0174-probe/$tag');
    if (root.existsSync()) root.deleteSync(recursive: true);
    root.createSync(recursive: true);
    final photo = File('${root.path}/一张.jpg')..writeAsBytesSync([1, 2, 3]);
    final watch = PhotoFolderWatch();
    var fired = 0;
    await watch.start([root.path], recursive: false, onChanged: () => fired++);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await act(photo);
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    watch.stop();
    // ignore: avoid_print
    print('PROBE $tag fired=$fired exists=${photo.existsSync()}');
  }

  test('彻底删除', () => probe('shift_delete', (f) async => f.delete()));

  test('改名', () => probe('rename', (f) async => f.rename('${f.parent.path}/新名.jpg')));

  test('移动出文件夹', () async {
    final outside = Directory('build/export-ui-check-0174-probe/outside')
      ..createSync(recursive: true);
    await probe(
        'move_out',
        (f) async => f.rename('${outside.path}/一张.jpg'));
  });

  test('移到回收站', () async {
    await probe('recycle', (f) async {
      final ps = r'Add-Type -AssemblyName Microsoft.VisualBasic;' +
          'Add-Type -AssemblyName System.Windows.Forms;'
              r"[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(" +
          "'${f.path}','OnlyErrorDialogs','SendToRecycleBin')";
      final result =
          await Process.run('powershell', ['-NoProfile', '-Command', ps]);
      // ignore: avoid_print
      print('PS exit=${result.exitCode} err=${result.stderr}');
      if (f.existsSync()) {
        // Fall back so the probe still measures something real.
        await f.delete();
      }
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}
