import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/export/export_options.dart';
import 'package:lumacraft/export/export_recovery.dart';

void main() {
  test('续导跳过中断的那张和已失败的，不重复已完成的', () {
    final note = ExportRecovery('卡住.jpg',
        pending: const [
          RecoveryJob(r'D:\照片\卡住.jpg', r'D:\输出\卡住.jpg', '卡住'),
          RecoveryJob(r'D:\照片\好的.jpg', r'D:\输出\好的.jpg', '好的'),
          RecoveryJob(r'D:\照片\上次失败.jpg', r'D:\输出\上次失败.jpg', '上次失败'),
          RecoveryJob(r'D:\照片\删掉了.jpg', r'D:\输出\删掉了.jpg', '删掉了'),
        ],
        completed: 5,
        skipped: const [r'D:\照片\上次失败.jpg'],
        options: ExportOptions()..directory = r'D:\输出');
    final jobs = resumableJobs(note,
        exists: (path) => !path.endsWith('删掉了.jpg'));
    expect(jobs.map((j) => j.stem), ['好的']);
  });

  test('只有中断那一张时没有可继续的照片', () {
    final note = ExportRecovery('唯一.jpg',
        pending: const [
          RecoveryJob(r'D:\照片\唯一.jpg', r'D:\输出\唯一.jpg', '唯一')
        ],
        options: ExportOptions()..directory = r'D:\输出');
    expect(resumableJobs(note, exists: (_) => true), isEmpty);
  });

  test('没有导出设置或没有剩余照片时不能续导', () {
    expect(
        resumableJobs(const ExportRecovery('x.jpg'), exists: (_) => true),
        isEmpty);
    expect(
        resumableJobs(ExportRecovery('x.jpg',
            pending: const [RecoveryJob('a', 'b', 'a')]),
            exists: (_) => true),
        isEmpty);
  });

  test('中断那张被跳过，不会回到同一张反复中断', () {
    final dir = Directory('build/export-ui-check-0158-resume')
      ..createSync(recursive: true);
    final note = ExportRecovery('大图.jpg',
        pending: [
          RecoveryJob('${dir.path}/大图.jpg', '${dir.path}/大图_L.jpg', '大图'),
          RecoveryJob('${dir.path}/正常.jpg', '${dir.path}/正常_L.jpg', '正常'),
        ],
        options: ExportOptions()..directory = dir.path);
    final jobs = resumableJobs(note, exists: (_) => true);
    expect(jobs.map((j) => j.stem), ['正常']);
  });
}
