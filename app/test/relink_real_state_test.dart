import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/photo_relink.dart';
import 'package:lumacraft/photo_state.dart';

/// 用真实的记录文件核对：改名后的照片已经有自己的记录时，
/// 旧名字的记录不应再让底栏一直提示「重新关联」。
void main() {
  test('真实记录：改名已接回后不应再有待关联', () async {
    final stateFile = File('local/photo-state.json');
    if (!stateFile.existsSync()) return;
    final store = PhotoStore(stateFile);
    await store.load();
    final dir = Directory(r'D:\AI Agent\LumaCraft\test');
    if (!dir.existsSync()) return;
    final paths = dir
        .listSync()
        .whereType<File>()
        .where((f) => photoFilePattern.hasMatch(f.path))
        .map((f) => f.path)
        .toSet();
    final times = <String, String>{};
    for (final path in paths) {
      final info = readCapture(path);
      times[path] = (info['time'] ?? '').trim();
    }
    final pending = pendingRecords(
        records: store.photos, currentPaths: paths, timesByPath: times);
    // ignore: avoid_print
    print('待关联 ${pending.length} 条：${pending.map((p) => p.fileName).join(', ')}');
    for (final record in pending) {
      // 每个待关联的记录都必须能对上一张没有内容的照片，否则就是误报。
      final freeNames = paths.where((p) {
        final state = store.photos[p];
        return state == null || !state.hasContent;
      }).map((p) => recordFileName(p).toLowerCase()).toSet();
      expect(freeNames, contains(record.fileName.toLowerCase()),
          reason: '${record.fileName} 没有可对上的照片，不该提示');
    }
  });
}
