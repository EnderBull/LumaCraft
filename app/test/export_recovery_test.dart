import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/export/export_options.dart';
import 'package:lumacraft/export/export_recovery.dart';

void main() {
  test('导出进度能存下来并读回，包含剩余照片和已完成数', () async {
    final dir = Directory('build/export-ui-check-0158-recovery')
      ..createSync(recursive: true);
    final store = ExportRecoveryStore(File('${dir.path}/export-recovery.json'));
    final options = ExportOptions()
      ..directory = r'D:\输出'
      ..format = 'png'
      ..quality = 88
      ..sizeEdge = 'short'
      ..edgePixels = 4000
      ..retainGps = true
      ..scope = 'edited';
    await store.write(ExportRecovery('两张.jpg', width: 6000, height: 8000,
        pending: const [
          RecoveryJob(r'D:\照片\两张.jpg', r'D:\输出\两张_LumaCraft.png', '两张'),
          RecoveryJob(r'D:\照片\三张.jpg', r'D:\输出\三张_LumaCraft.png', '三张'),
        ],
        completed: 7,
        skipped: const [r'D:\照片\跳过.jpg'],
        options: options));
    final note = await store.read();
    expect(note, isNotNull);
    expect(note!.fileName, '两张.jpg');
    expect(note.pixels, 6000 * 8000);
    expect(note.completed, 7);
    expect(note.skipped, [r'D:\照片\跳过.jpg']);
    expect(note.canResume, isTrue);
    expect(note.pending.length, 2);
    expect(note.pending.first.stem, '两张');
    expect(note.pending.last.target, r'D:\输出\三张_LumaCraft.png');
    expect(note.options!.directory, r'D:\输出');
    expect(note.options!.format, 'png');
    expect(note.options!.quality, 88);
    expect(note.options!.sizeEdge, 'short');
    expect(note.options!.edgePixels, 4000);
    expect(note.options!.retainGps, isTrue);
    expect(note.options!.scope, 'edited');
    expect(exportRecoveryMessage(note), contains('还剩 2 张'));
    expect(exportRecoveryMessage(note), contains('跳过'));
  });

  test('旧版只有文件名的记录仍能读，只是不能继续导出', () async {
    final dir = Directory('build/export-ui-check-0158-recovery/old')
      ..createSync(recursive: true);
    final file = File('${dir.path}/export-recovery.json')
      ..writeAsStringSync(jsonEncode({
        'version': 1,
        'file': '老记录.jpg',
        'width': 6144,
        'height': 8192
      }));
    final store = ExportRecoveryStore(file);
    final note = await store.read();
    expect(note!.fileName, '老记录.jpg');
    expect(note.canResume, isFalse);
    expect(note.pending, isEmpty);
    expect(exportRecoveryMessage(note), isNot(contains('还剩')));
  });

  test('写进度记录不会丢失，读到后能继续', () async {
    final dir = Directory('build/export-ui-check-0171-recovery/stale')
      ..createSync(recursive: true);
    final store = ExportRecoveryStore(File('${dir.path}/export-recovery.json'));
    await store.write(ExportRecovery('进行中.jpg',
        pending: const [RecoveryJob('a', 'b', 'a')],
        options: ExportOptions()..directory = dir.path));
    final note = await store.readInterrupted();
    expect(note?.fileName, '进行中.jpg');
    expect(note!.canResume, isTrue);
    // 写入过程中不会留下半截临时文件。
    expect(await File('${dir.path}/export-recovery.json.writing').exists(),
        isFalse);
  });

  test('主动关闭窗口也会说明，并标记是自己关的', () async {
    final dir = Directory('build/export-ui-check-0158-recovery/closed')
      ..createSync(recursive: true);
    final store = ExportRecoveryStore(File('${dir.path}/export-recovery.json'));
    await store.write(ExportRecovery('x.jpg',
        pending: const [RecoveryJob('a', 'b', 'a')], options: ExportOptions()));
    await store.dismissedFile.writeAsString('');
    expect(await store.closedByUser(), isTrue);
    // 记录仍然在，提示措辞改为“被关闭了”。
    final note = await store.readInterrupted();
    expect(note, isNotNull);
    expect(exportRecoveryMessage(note!, closedByUser: true), contains('被关闭了'));
  });

  test('关闭窗口只留标记，不动进度记录（否则续导就没了）', () async {
    final dir = Directory('build/export-ui-check-0181-close/keeps')
      ..createSync(recursive: true);
    final store = ExportRecoveryStore(File('${dir.path}/export-recovery.json'));
    await store.write(ExportRecovery('还在导.jpg',
        pending: const [RecoveryJob('a', 'b', 'a')],
        options: ExportOptions()..directory = dir.path));
    // 模拟原生侧关窗口：只写标记，绝不删记录。
    await store.dismissedFile.writeAsString('');
    expect(await store.file.exists(), isTrue, reason: '关窗口不能删掉进度记录');
    final note = await store.readInterrupted();
    expect(note, isNotNull);
    expect(note!.canResume, isTrue, reason: '关窗口后下次打开要能继续导出');
    expect(await store.closedByUser(), isTrue);
  });

  test('整批处理完后标记一并清掉，不会误说下一次是主动关闭', () async {
    final dir = Directory('build/export-ui-check-0181-close/tidy')
      ..createSync(recursive: true);
    final store = ExportRecoveryStore(File('${dir.path}/export-recovery.json'));
    await store.write(ExportRecovery('导完.jpg',
        pending: const [RecoveryJob('a', 'b', 'a')], options: ExportOptions()));
    await store.dismissedFile.writeAsString('');
    await store.clear();
    expect(await store.file.exists(), isFalse);
    expect(await store.dismissedFile.exists(), isFalse,
        reason: '标记必须一起清掉，否则下次崩溃会被说成主动关闭');
    expect(await store.readInterrupted(), isNull);
  });

  test('没有进度记录时不该留下标记（关窗口但没在导出）', () async {
    final dir = Directory('build/export-ui-check-0181-close/empty')
      ..createSync(recursive: true);
    final store = ExportRecoveryStore(File('${dir.path}/export-recovery.json'));
    // 原生侧判断的是进度记录是否存在，没有记录就不写标记。
    expect(await store.file.exists(), isFalse);
    expect(await store.dismissedFile.exists(), isFalse);
  });
}
