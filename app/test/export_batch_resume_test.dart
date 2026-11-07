import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/export/export_options.dart';
import 'package:lumacraft/export/export_recovery.dart';
import 'package:lumacraft/export/export_task.dart';
import 'package:lumacraft/main.dart' as app;
import 'package:lumacraft/photo_state.dart';

/// 续导必须用原批次当时固定下来的样式、拍摄字段、文件名和替换授权，
/// 不能用续导那一刻界面上的当前状态。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  StyleDocument styled(int color, String name) =>
      StyleDocument.template()
        ..name = name
        ..background = color
        ..borders['top'] = 20
        ..borders['bottom'] = 20
        ..borders['left'] = 20
        ..borders['right'] = 20;

  Directory fresh(String tag) => Directory(
      'build/export-ui-check-batch/$tag-${DateTime.now().microsecondsSinceEpoch}')
    ..createSync(recursive: true);

  group('批次记录', () {
    test('样式、字段、文件名、替换授权都存进批次，进度记录只有进度', () async {
      final dir = fresh('roundtrip');
      final store = ExportRecoveryStore(File('${dir.path}/export-recovery.json'));
      final red = styled(0xffff0000, '红');
      final green = styled(0xff00ff00, '绿');
      final target = File('${dir.path}/b.jpg')..writeAsStringSync('existing');
      final snapshot = FileSnapshot.of(target.statSync());
      final jobs = [
        ExportJob(File('${dir.path}/a.jpg'), red, false,
            {'model': 'CAM-A', 'lens': 'L1'}, 'a', '${dir.path}/a_out.jpg'),
        ExportJob(File('${dir.path}/b.jpg'), green, true, {'model': 'CAM-B'},
            'b', target.path)
          ..replacedStat = snapshot,
        ExportJob(File('${dir.path}/c.jpg'), red, false, {}, 'c',
            '${dir.path}/c_out.jpg'),
      ];
      final options = ExportOptions()
        ..directory = dir.path
        ..format = 'png'
        ..quality = 77
        ..sizeEdge = 'short'
        ..edgePixels = 3000
        ..retainGps = true;
      final id = await store.writeBatch(ExportBatch(
          options, [for (final j in jobs) RecoveryJob.fromExportJob(j)],
          replace: true));
      await store.write(ExportRecovery('b.jpg',
          completed: 1,
          skipped: const ['x.jpg'],
          batchId: id,
          index: 1,
          replace: true));

      final progressText = store.file.readAsStringSync();
      expect(progressText, isNot(contains('"style"')), reason: '进度记录不含样式');
      expect(progressText, isNot(contains('pending')));
      expect(progressText.length, lessThan(400));

      final note = (await store.read())!;
      expect(note.canResume, isTrue);
      expect(note.replace, isTrue);
      expect(note.completed, 1);
      expect(note.options!.format, 'png');
      expect(note.options!.quality, 77);
      expect(note.options!.edgePixels, 3000);
      expect(note.options!.retainGps, isTrue);
      expect(note.pending.map((j) => j.stem), ['b', 'c']);
      final back = note.pending.first.toExportJob();
      expect(back.film, isTrue);
      expect(back.fields, {'model': 'CAM-B'});
      expect(back.target, target.path);
      expect(back.style!.background, 0xff00ff00);
      expect(back.replacedStat!.size, snapshot.size);
      expect(back.replacedStat!.modified, snapshot.modified);
      // 记录里的授权：目标没变就允许替换，变了就拒绝。
      await publishExport(back, [1, 2, 3], replace: true);
      expect(target.readAsBytesSync(), [1, 2, 3]);
      final again = note.pending.first.toExportJob();
      await expectLater(publishExport(again, [9], replace: true),
          throwsA(isA<FileSystemException>()),
          reason: '目标在授权后变了，必须保护');
      expect(target.readAsBytesSync(), [1, 2, 3]);
    });

    test('同一样式只存一份', () async {
      final dir = fresh('dedupe');
      final red = styled(0xffff0000, '红');
      final jobs = [
        for (var i = 0; i < 5; i++)
          RecoveryJob.fromExportJob(ExportJob(File('${dir.path}/$i.jpg'), red,
              false, {}, '$i', '${dir.path}/o$i.jpg'))
      ];
      final json = ExportBatch(ExportOptions()..directory = dir.path, jobs)
          .toJson();
      expect((json['styles'] as List).length, 1);
      expect(ExportBatch.fromJson(jsonDecode(jsonEncode(json)))!.jobs.length, 5);
    });

    test('新记录可读之前，旧记录一直有效', () async {
      final dir = fresh('keep-old');
      final store = ExportRecoveryStore(File('${dir.path}/export-recovery.json'));
      final options = ExportOptions()..directory = dir.path;
      RecoveryJob job(String n) => RecoveryJob('${dir.path}/$n.jpg',
          '${dir.path}/$n-out.jpg', n,
          style: styled(0xffff0000, n).toJson());
      final a = await store.writeBatch(
          ExportBatch(options, [job('a1'), job('a2'), job('a3')]));
      await store.write(ExportRecovery('a1.jpg', batchId: a, index: 0));
      // 续导开始：新批次先写好，但新进度还没写。此时意外退出。
      final b = await store.writeBatch(ExportBatch(options, [job('a3')]));
      var note = (await store.read())!;
      expect(note.canResume, isTrue, reason: '旧记录必须仍可读');
      expect(note.pending.map((j) => j.stem), ['a1', 'a2', 'a3']);
      // 新进度写好，旧批次才清理。
      await store.write(ExportRecovery('a3.jpg', batchId: b, index: 0));
      await store.pruneBatches(keep: b);
      expect(store.batchFile(a).existsSync(), isFalse);
      expect(store.batchFile(b).existsSync(), isTrue);
      note = (await store.read())!;
      expect(note.pending.map((j) => j.stem), ['a3']);
      await store.clear();
      expect(store.batchFile(b).existsSync(), isFalse, reason: '清理时批次一并清掉');
      expect(store.file.existsSync(), isFalse);
    });

    test('批次文件丢失时仍报告中断，只是不能续导', () async {
      final dir = fresh('lost');
      final store = ExportRecoveryStore(File('${dir.path}/export-recovery.json'));
      await store.write(ExportRecovery('丢.jpg', batchId: '404', index: 0));
      final note = (await store.read())!;
      expect(note.fileName, '丢.jpg');
      expect(note.canResume, isFalse);
    });
  });

  testWidgets('真实续导：用原批次的样式、保留替换授权、保护被改动的目标', (tester) async {
    final root = PhotoStore.defaultFile().parent;
    expect(Platform.environment['LUMACRAFT_DATA_DIR'],
        contains('export-ui-check'));
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final input = Directory('${root.path}/resume-input');
    final output = Directory('${root.path}/resume-output');
    late File p1, p2, p3, p4, o3, o4;
    late String batchId;
    await tester.runAsync(() async {
      for (final d in [input, output]) {
        if (d.existsSync()) d.deleteSync(recursive: true);
        d.createSync(recursive: true);
      }
      for (final name in ['p1', 'p2', 'p3', 'p4']) {
        final image = img.Image(width: 120, height: 80);
        img.fill(image, color: img.ColorRgb8(80, 130, 150));
        image.exif.imageIfd[0x0110] = 'CAMERA';
        await File('${input.path}/$name.jpg').writeAsBytes(img.encodeJpg(image));
      }
      p1 = File('${input.path}/p1.jpg');
      p2 = File('${input.path}/p2.jpg');
      p3 = File('${input.path}/p3.jpg');
      p4 = File('${input.path}/p4.jpg');
      o3 = File('${output.path}/p3.jpg')..writeAsStringSync('old-3');
      o4 = File('${output.path}/p4.jpg')..writeAsStringSync('old-4');
      // 原批次：红色样式；p3、p4 的重名已确认替换。
      final red = styled(0xffff0000, '红');
      ExportJob job(File s, String stem, {File? replaced}) =>
          ExportJob(s, red.copy(), false, {'model': 'BATCH'}, stem,
              '${output.path}/$stem.jpg')
            ..replacedStat =
                replaced == null ? null : FileSnapshot.of(replaced.statSync());
      final jobs = [
        job(p1, 'p1'),
        job(p2, 'p2'),
        job(p3, 'p3', replaced: o3),
        job(p4, 'p4', replaced: o4),
      ];
      final options = ExportOptions()
        ..directory = output.path
        ..edgePixels = 300;
      final notes = ExportRecoveryStore.standard();
      batchId = await notes.writeBatch(ExportBatch(
          options, [for (final j in jobs) RecoveryJob.fromExportJob(j)],
          replace: true));
      await notes.write(ExportRecovery('p1.jpg',
          batchId: batchId, index: 0, replace: true));
      // 中断期间：p4 的目标被用户改了；当前样式也换成了蓝色。
      await Future<void>.delayed(const Duration(milliseconds: 30));
      o4.writeAsStringSync('user-edited-4');
      await File('${root.path}/workspace.json').writeAsString(
          jsonEncode({'version': 1, 'lastDirectory': input.path}));
      final store = PhotoStore(PhotoStore.defaultFile());
      for (final f in [p1, p2, p3, p4]) {
        store.state(f.path).style = styled(0xff0000ff, '蓝');
      }
      await store.save();
    });
    await tester.pumpWidget(const app.LumaCraftApp());
    Future<void> waitFor(bool Function() done, [int rounds = 200]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump(const Duration(milliseconds: 40));
        if (done()) return;
      }
      fail('续导流程未在预期时间内完成');
    }

    await waitFor(() => find.text('上次导出没有完成').evaluate().isNotEmpty);
    await tester.tap(find.textContaining('继续导出剩下的 3 张'));
    await tester.pump();
    // p4 的目标被改过，会弹出失败说明。
    await waitFor(() => find.textContaining('失败 1 张').evaluate().isNotEmpty);
    await tester.tap(find.text('关闭'));
    final dynamic state = tester.state(find.byType(app.Workshop));
    await waitFor(() => state.busy != true);

    Future<int> corner(File f) async {
      final bytes = (await tester.runAsync(() => f.readAsBytes()))!;
      final image = img.decodeImage(bytes)!;
      final p = image.getPixel(2, 2);
      return (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt();
    }

    expect(File('${output.path}/p1.jpg').existsSync(), isFalse,
        reason: '中断时正在处理的那张被跳过');
    final red = await corner(File('${output.path}/p2.jpg'));
    expect((red >> 16) & 255, greaterThan(200), reason: 'p2 用原批次的红色样式');
    expect(red & 255, lessThan(60), reason: 'p2 不能是当前的蓝色样式');
    final replaced = await corner(o3);
    expect((replaced >> 16) & 255, greaterThan(200), reason: 'p3 已授权替换，且样式是红色');
    expect(o4.readAsStringSync(), 'user-edited-4', reason: 'p4 的目标被改动过，必须受保护');
    expect(ExportRecoveryStore.standard().file.existsSync(), isFalse,
        reason: '续导完成后记录清掉');
    expect(ExportRecoveryStore.standard().batchFile(batchId).existsSync(),
        isFalse);
    await tester.pumpWidget(const SizedBox());
    // 数据目录和别的用例共用，清掉这里写的记录。
    await tester.runAsync(() async {
      for (final name in ['workspace.json', 'photo-state.json']) {
        final f = File('${root.path}/$name');
        if (f.existsSync()) f.deleteSync();
      }
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}
