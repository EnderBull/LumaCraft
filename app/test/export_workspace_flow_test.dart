import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/main.dart' as app;
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/photo_state.dart';
import 'package:lumacraft/export/export_options.dart';
import 'package:lumacraft/export/export_preferences.dart';
import 'package:lumacraft/ui/export/export_dialog.dart';
import 'package:lumacraft/ui/export/export_conflict_dialog.dart';

void main() {
  testWidgets('真实工作台：取消重名/全部保留/替换保存/失败重试', (tester) async {
    final root = PhotoStore.defaultFile().parent;
    // The command must provide an isolated root; never touch a normal session.
    expect(Platform.environment['LUMACRAFT_DATA_DIR'],
        contains('export-ui-check'));
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Directory input, output;
    late File first, second, conflict;
    await tester.runAsync(() async {
      input = await Directory('${root.path}/input').create(recursive: true);
      output = await Directory('${root.path}/output').create(recursive: true);
      for (final name in ['one', 'two']) {
        final image = img.Image(width: 120, height: 80);
        img.fill(image, color: img.ColorRgb8(80, 130, 150));
        image.exif.imageIfd[0x0110] = 'CAMERA';
        image.exif.exifIfd[0xa434] = 'LENS';
        image.exif.exifIfd[0x9003] = '2021:06:20 16:45:01';
        image.exif.exifIfd[0x8827] = img.IfdValueShort(200);
        image.exif.exifIfd[0x920a] = img.IfdValueRational(35, 1);
        image.exif.exifIfd[0x829d] = img.IfdValueRational(4, 1);
        image.exif.exifIfd[0x829a] = img.IfdValueRational(1, 250);
        await File('${input.path}/$name.jpg')
            .writeAsBytes(img.encodeJpg(image));
      }
      first = File('${input.path}/one.jpg');
      second = File('${input.path}/two.jpg');
      conflict = File('${output.path}/one_LumaCraft.jpg');
      await conflict.writeAsString('existing-output');
      await File('${root.path}/workspace.json').writeAsString(
          jsonEncode({'version': 1, 'lastDirectory': input.path}));
      final store = PhotoStore(PhotoStore.defaultFile());
      store.state(first.path).style = StyleDocument.template();
      await store.save();
      await ExportPreferences(File('${root.path}/export-settings.json')).save(
          ExportOptions()
            ..directory = output.path
            ..edgePixels = 300,
          defaultNamingTemplate());
    });
    await tester.pumpWidget(const app.LumaCraftApp());
    final dynamic state = tester.state(find.byType(app.Workshop));
    Future<void> waitFor(bool Function() done) async {
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 30));
        if (done()) return;
      }
      fail('工作台流程未在预期时间内完成');
    }

    await waitFor(() => state.ready == true && state.files.length == 2);
    await tester.tap(find.text('全选'));
    await tester.pump();
    Future<void> start() async {
      await tester.tap(find.text('导出照片'));
      await waitFor(() => find.byType(ExportDialog).evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      await tester.tap(find.text('导出 2 张照片'));
      await tester.pumpAndSettle();
      await waitFor(
          () => find.byType(ExportConflictDialog).evaluate().isNotEmpty);
      await tester.pumpAndSettle();
    }

    await start();
    await tester.tap(find.descendant(
        of: find.byType(ExportConflictDialog), matching: find.text('取消导出')));
    await tester.pumpAndSettle();
    await waitFor(() => state.busy == false);
    await tester.runAsync(() async {
      expect(await conflict.readAsString(), 'existing-output');
      expect(await File('${output.path}/two_LumaCraft.jpg').exists(), false);
    });
    await start();
    await tester.tap(find.text('全部保留'));
    await tester.pumpAndSettle();
    await waitFor(() => state.busy == false);
    await tester.runAsync(() async {
      expect(await conflict.readAsString(), 'existing-output');
      expect(await File('${output.path}/one_LumaCraft_1.jpg').exists(), true);
      expect(
          img
              .decodeJpg(
                  await File('${output.path}/two_LumaCraft.jpg').readAsBytes())!
              .width,
          300);
    });
    await start();
    await tester.tap(find.text('替换保存'));
    await tester.pumpAndSettle();
    await waitFor(() => state.busy == false);
    await tester.runAsync(() async {
      expect(img.decodeJpg(await conflict.readAsBytes())!.width, 300);
    });
    late List<int> goodSource;
    await tester.runAsync(() async {
      goodSource = await second.readAsBytes();
      await second.writeAsString('invalid-image');
    });
    await start();
    await tester.tap(find.text('替换保存'));
    await tester.pumpAndSettle();
    await waitFor(() => find.text('失败 1 张').evaluate().isNotEmpty);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    await waitFor(() => state.busy == false);
    expect(state.failed.length, 1);
    await tester.runAsync(() => second.writeAsBytes(goodSource));
    await tester.tap(find.text('重试失败 1 张'));
    await tester.pumpAndSettle();
    await waitFor(
        () => find.byType(ExportConflictDialog).evaluate().isNotEmpty);
    await tester.pumpAndSettle();
    await tester.tap(find.text('替换保存'));
    await tester.pumpAndSettle();
    await waitFor(() => state.busy == false);
    expect(state.failed, isEmpty);
    expect(state.total, 1);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
}
