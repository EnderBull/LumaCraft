import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/export/export_options.dart';
import 'package:lumacraft/export/export_preferences.dart';
import 'package:lumacraft/export/export_recovery.dart';
import 'package:lumacraft/main.dart' as app;
import 'package:lumacraft/photo_state.dart';
import 'package:lumacraft/ui/export/export_dialog.dart';

/// 用真实的大照片（D:\AI Agent\LumaCraft\test 里用户提供的那批）导出，
/// 确认「导出一开头就把进度记录写到盘上」，这样被任务管理器强杀、
/// 或者点 X 关闭，下次打开才有东西可以问用户要不要继续。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('真实照片导出中，进度记录确实在盘上', (tester) async {
    expect(Platform.environment['LUMACRAFT_DATA_DIR'],
        contains('export-ui-check'));
    final source = Directory(r'D:\AI Agent\LumaCraft\test');
    expect(source.existsSync(), isTrue, reason: '需要用户提供的测试照片');
    final photos = source
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jpg'))
        .toList()
      ..sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
    expect(photos.length, greaterThanOrEqualTo(3));
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Directory output;
    await tester.runAsync(() async {
      final root = PhotoStore.defaultFile().parent;
      output = await Directory('${root.path}/out').create(recursive: true);
      await File('${root.path}/workspace.json')
          .writeAsString(jsonEncode({'version': 1, 'lastDirectory': source.path}));
      await ExportPreferences(File('${root.path}/export-settings.json')).save(
          ExportOptions()
            ..directory = output.path
            ..edgePixels = 4000,
          defaultNamingTemplate());
    });
    await tester.pumpWidget(const app.LumaCraftApp());
    final dynamic state = tester.state(find.byType(app.Workshop));
    for (var i = 0;
        i < 200 && (state.ready != true || state.files.length < 3);
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(state.files.length, greaterThanOrEqualTo(3));
    // 只导最大的三张，够慢，能在中途看到进度记录。
    await tester.tap(find.text('全选'));
    await tester.pump();
    await tester.tap(find.text('导出照片'));
    var dialogUp = false;
    for (var i = 0; i < 100 && !dialogUp; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
      dialogUp = find.byType(ExportDialog).evaluate().isNotEmpty;
    }
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(ExportDialog), findsOneWidget);
    await tester.tap(find.textContaining('导出 ').last);
    await tester.pump(const Duration(milliseconds: 100));
    final store = ExportRecoveryStore.standard();
    var seen = false;
    for (var i = 0; i < 400 && !seen; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump(const Duration(milliseconds: 25));
      // 真实照片的拍摄信息不一定齐全，会先问一句；这里照用户的做法点继续。
      final proceed = find.widgetWithText(FilledButton, '继续导出');
      if (proceed.evaluate().isNotEmpty) {
        await tester.tap(proceed);
        await tester.pump(const Duration(milliseconds: 50));
      }
      seen = (await tester.runAsync(() => store.file.exists())) ?? false;
    }
    // ignore: avoid_print
    print('DIAG busy=${state.busy} status=${state.status} '
        'completed=${state.completed}/${state.total} seen=$seen '
        'files=${store.file.parent.listSync().map((e) => e.uri.pathSegments.last).join(",")}');
    expect(seen, isTrue, reason: '导出开始后进度记录必须落盘，否则强杀后无从续导');
    final note = await tester.runAsync(() => store.readInterrupted());
    expect(note, isNotNull);
    expect(note!.canResume, isTrue);
    expect(note.pending, isNotEmpty);
    expect(note.options?.directory, output.path);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 5)));
}
