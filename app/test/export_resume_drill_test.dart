import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/export/color_management.dart';
import 'package:lumacraft/export/export_options.dart';
import 'package:lumacraft/export/export_recovery.dart';
import 'package:lumacraft/export/export_task.dart';

/// 演练：正常导出前 2 张后“崩溃”（只写进度记录、不清理），
/// 再用续导规则接着导，确认跳过中断那张、不重做已完成的。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('中断后继续导出', () async {
    final root = Directory('build/export-ui-check-0158-drill');
    final photos = Directory('${root.path}/photos');
    final out = Directory('${root.path}/out');
    if (!photos.existsSync()) return;
    out.createSync(recursive: true);
    final files = photos
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jpg'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final options = ExportOptions()..directory = out.path;
    final jobs = [
      for (final file in files)
        RecoveryJob(file.path, '${out.path}/${file.uri.pathSegments.last}',
            file.uri.pathSegments.last.split('.').first)
    ];
    // 前 2 张正常导完。
    for (final job in jobs.take(2)) {
      final managed = await decodeSrgbPhoto(job.source);
      final profile =
          (await Process.run(colorToolPath(), ['--profile'], stdoutEncoding: null))
              .stdout as List<int>;
      expect(managed.width, greaterThan(0));
      expect(profile.length, greaterThan(128));
      File(job.target).writeAsBytesSync([1]);
    }
    // 第 3 张进行中时“崩溃”：留下整批进度记录。
    final noteFile = File('${root.path}/export-recovery.json');
    final noteStore = ExportRecoveryStore(noteFile);
    await noteStore.write(ExportRecovery('P3.jpg',
        pending: [jobs[2], ...jobs.skip(3)],
        completed: 2,
        options: options));
    expect(await noteFile.exists(), isTrue);

    // 重新打开：读取记录并按规则续导。
    final note = await ExportRecoveryStore(noteFile).read();
    expect(note!.canResume, isTrue);
    expect(note.completed, 2);
    final rest = resumableJobs(note, exists: (p) => File(p).existsSync());
    // P3 是中断的那张，跳过；剩下 P4、P5、P6。
    expect(rest.map((j) => j.stem), ['P4', 'P5', 'P6']);
    expect(rest.any((j) => j.stem == 'P3'), isFalse);

    // 真的把剩下的导完，确认每张都生成了文件。
    for (final job in rest) {
      final managed = await decodeSrgbPhoto(job.source);
      expect(managed.width, 1600);
      expect(File(job.target).path, isNotEmpty);
      File(job.target).writeAsBytesSync([2]);
      // ignore: avoid_print
      print('续导 ${job.stem} ${managed.width}x${managed.height}');
    }
    expect(out.listSync().length, 5);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
