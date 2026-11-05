import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/directory_browser.dart';
import 'package:lumacraft/ui/directory_panel.dart';
import 'package:lumacraft/ui/browse_viewport.dart';
import 'package:lumacraft/ui/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('重叠目录递归合并去重及旧扫描取消', () async {
    final root = await Directory(
            'test/browse-output/run-${DateTime.now().millisecondsSinceEpoch}')
        .create(recursive: true);
    final child = await Directory('${root.path}/child').create();
    await File('${root.path}/a.jpg').writeAsString('sample');
    await File('${child.path}/b.jpeg').writeAsString('sample');
    await File('${child.path}/skip.txt').writeAsString('sample');
    final scanner = PhotoScanner(),
        done = Completer<void>(),
        files = <String>[];
    scanner.startMany([root.path, child.path],
        recursive: true,
        onBatch: (batch) => files.addAll(batch.map((f) => f.path)),
        onDone: (_) => done.complete(),
        onError: (e) => fail(e));
    await done.future;
    expect(files.length, 2);
    expect(files.toSet().length, 2);
    var stale = 0;
    final next = Completer<void>();
    scanner.start(root.path,
        recursive: true,
        onBatch: (_) => stale++,
        onDone: (_) => stale++,
        onError: (_) => stale++);
    scanner.startMany([child.path],
        recursive: false,
        onBatch: (_) {},
        onDone: (_) => next.complete(),
        onError: (e) => fail(e));
    await next.future;
    expect(stale, 0);
    scanner.cancel();
  });
  testWidgets('浏览画布Alt滚轮缩放、空格拖动和复位', (tester) async {
    final key = GlobalKey<BrowseViewportState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BrowseViewport(
                key: key, child: const Center(child: Text('照片'))))));
    final center = tester.getCenter(find.byType(BrowseViewport));
    if (Platform.isWindows) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('lumacraft/window'),
          (_) async => HardwareKeyboard.instance.isAltPressed);
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendEventToBinding(PointerScrollEvent(
        position: center, scrollDelta: const Offset(0, -120)));
    await tester.pumpAndSettle();
    expect(key.currentState!.zoom, greaterThan(1));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    final releasedZoom = key.currentState!.zoom;
    await tester.sendEventToBinding(PointerScrollEvent(
        position: center, scrollDelta: const Offset(0, -120)));
    await tester.pumpAndSettle();
    expect(key.currentState!.zoom, releasedZoom);
    if (Platform.isWindows) {
      const channel = MethodChannel('lumacraft/window');
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => false);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendEventToBinding(PointerScrollEvent(
          position: center, scrollDelta: const Offset(0, -120)));
      await tester.pumpAndSettle();
      expect(key.currentState!.zoom, releasedZoom,
          reason: 'Windows实时状态优先于可能残留的Flutter Alt状态');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
    await tester.tapAt(center);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    final before = key.currentState!.pan;
    await tester.dragFrom(center, const Offset(100, 40));
    await tester.pumpAndSettle();
    expect((key.currentState!.pan - before).distance, greaterThan(10));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    key.currentState!.reset();
    await tester.pumpAndSettle();
    expect(key.currentState!.zoom, 1);
    expect(key.currentState!.pan, Offset.zero);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('目录Ctrl/Shift多选及区域CtrlD', (tester) async {
    Set<String> selected = {};
    final key = GlobalKey();
    late StateSetter refresh;
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: Scaffold(
            body: SizedBox(
                width: 300,
                child: StatefulBuilder(builder: (ctx, set) {
                  refresh = set;
                  return DirectoryPanel(
                      key: key,
                      currentPath: null,
                      selectedPaths: selected,
                      onSelectMany: (v) => set(() => selected = v),
                      includeChildren: false,
                      enabled: true,
                      scanning: false,
                      count: 0,
                      onSelect: (_) {},
                      onRecursive: (_) {},
                      onChooseDirectory: () {});
                })))));
    final dynamic state = key.currentState;
    state.setState(() {
      state.roots = ['Q:\\sample-a', 'Q:\\sample-b', 'Q:\\sample-c'];
    });
    await tester.pump();
    await tester.tap(find.text('Q:\\sample-a'));
    await tester.pump();
    expect(selected, {'Q:\\sample-a'});
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Q:\\sample-c'));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(selected.length, 2);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('Q:\\sample-b'));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(selected, {'Q:\\sample-b', 'Q:\\sample-c'});
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(selected, isEmpty);
    refresh(() {});
    await tester.pumpWidget(const SizedBox());
  });
}
