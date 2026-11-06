import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/fonts/font_catalog.dart';
import 'package:lumacraft/editor/builtin_library.dart';
import 'package:lumacraft/editor/preset_store.dart';
import 'package:lumacraft/editor/preset_package.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/style_render.dart';
import 'package:lumacraft/ui/editor/prototype_controls.dart';
import 'package:lumacraft/ui/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> fonts() async {
    for (final f in artworkFonts) {
      final loader = FontLoader(f.family)..addFont(rootBundle.load(f.asset));
      await loader.load();
    }
  }

  test('官方字体离线资源、许可及新旧.lmp兼容', () async {
    await fonts();
    expect(artworkFonts.length, 8);
    for (final f in artworkFonts) {
      expect(
          (await rootBundle.load(f.asset)).lengthInBytes, greaterThan(10000));
      final license = f.asset.replaceFirst(RegExp(r'\.(ttf|otf)$'), '-OFL.txt');
      expect((await rootBundle.loadString(license)).toUpperCase(),
          contains('OPEN FONT LICENSE'));
      final p = TextPainter(
          text: TextSpan(
              text: f.latinOnly ? 'Mountain Silence 23mm' : '山海之间 · 23mm',
              style: artworkTextStyle(f.id).copyWith(fontSize: 26)),
          textDirection: TextDirection.ltr)
        ..layout();
      expect(p.width, greaterThan(60));
      expect(p.height, greaterThan(20));
      p.dispose();
      final style = StyleDocument.template()..nodes.first.font = f.id;
      final encoded = encodeLmp([SharedPreset(style)]);
      expect((jsonDecode(encoded)['requires'] as List),
          contains('bundledFontsV1'));
      expect(decodeLmp(encoded).single.style.nodes.first.font, f.id);
    }
    final old = encodeLmp([SharedPreset(StyleDocument.template())]);
    expect((jsonDecode(old)['requires'] as List),
        isNot(contains('bundledFontsV1')));
    expect(decodeLmp(old).single.style.nodes.first.font, 'serif');
  });
  test('内置工作库保存重启、恢复与发行版只读隔离', () async {
    final dir = await Directory(
            'test/builtin-output/run-${DateTime.now().microsecondsSinceEpoch}')
        .create(recursive: true);
    final store =
        PresetStore(File('${dir.path}/presets.json'), authoring: true);
    await store.load();
    expect(store.entries.map((p) => p.id),
        containsAll(['gallery', 'travel', 'film']));
    expect(store.builtinFolders.map((f) => f.name),
        containsAll(['简约', '旅行', '手机水印']));
    expect(store.entries.map((e) => e.id), isNot(contains('brushed-metal')));
    final frame = store.entries.firstWhere((e) => e.id == 'double-frame');
    expect(frame.folder, 'builtin:simple');
    expect(frame.style.photoStroke.enabled, isTrue);
    expect(frame.style.photoStroke.target, 'canvas');
    expect(frame.style.photoStroke.inset, 22);
    expect(frame.style.nodes.any((n) => n.id == 'frame'), isFalse);
    final candy = store.entries.firstWhere((e) => e.id == 'candy-polka');
    expect(candy.style.photoStroke.inset, -8);
    expect(candy.style.photoStroke.width, 16);
    expect(candy.style.nodes.any((n) => n.id == 'ring'), isFalse);
    final original = store.entries.first.style.toJson();
    await store.saveBuiltin('gallery',
        store.entries.first.style.copy()..name = '手工维护作品', 'simple');
    final reopened = PresetStore(store.file, authoring: true);
    await reopened.load();
    expect(reopened.entries.first.style.name, '手工维护作品');
    final release = PresetStore(store.file, authoring: false);
    await release.load();
    expect(release.entries.first.style.name, '画廊签名');
    await expectLater(
        release.saveBuiltin('gallery', StyleDocument(), 'simple'),
        throwsStateError);
    final exported = BuiltinLibrary.decode(reopened.builtinLibrary.encode());
    expect(exported.entries.first.style.name, '手工维护作品');
    await reopened.restoreBuiltin('gallery');
    expect(reopened.entries.first.style.toJson(), original);
    expect(await store.file.exists(), false, reason: '内置工作库不能覆盖用户库');
    final malformed = jsonDecode(exported.encode());
    malformed['presets'][0]['folder'] = 'missing';
    expect(() => BuiltinLibrary.decode(jsonEncode(malformed)),
        throwsFormatException);
  });
  test('三款预设横竖排版与真实字体画布输出', () async {
    await fonts();
    final library = BuiltinLibrary.decode(
        await rootBundle.loadString('assets/builtins/library.json'));
    final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
    canvas.drawRect(
        const Rect.fromLTWH(0, 0, 900, 600),
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, const Offset(900, 600),
              [const Color(0xff2d6078), const Color(0xffb3bfb6)]));
    final picture = recorder.endRecording(),
        photo = await picture.toImage(900, 600);
    picture.dispose();
    final fields = {
      'camera': 'FUJIFILM X-T5',
      'lens': 'XF 23mm F1.4',
      'focal': '35',
      'aperture': '2.8',
      'shutter': '1/250',
      'iso': '200',
      'place': '川西 · 新都桥',
      'time': '2026:10:18 06:42:00'
    };
    for (final p in library.entries) {
      for (final ratio in [1.5, 2 / 3, 1.0]) {
        final scene = StyleScene(p.style, photo, fields, ratioOverride: ratio);
        final bounds = Offset.zero &
            Size(scene.geometry.size.width, scene.geometry.size.height);
        for (final rect in scene.bounds.values) {
          expect(bounds.inflate(1).contains(rect.topLeft), true,
              reason: '${p.id} $ratio $rect');
          expect(bounds.inflate(1).contains(rect.bottomRight), true,
              reason: '${p.id} $ratio $rect');
        }
        final record = ui.PictureRecorder(), c = Canvas(record);
        scene.paint(c);
        final drawing = record.endRecording(),
            image = await drawing.toImage(scene.geometry.size.width.ceil(),
                scene.geometry.size.height.ceil());
        expect(
            await image.toByteData(format: ui.ImageByteFormat.png), isNotNull);
        image.dispose();
        drawing.dispose();
        scene.dispose();
      }
    }
    photo.dispose();
  });
  testWidgets('字体下拉每项使用真实字体且无菜单动画', (tester) async {
    await fonts();
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: Scaffold(
            body: SizedBox(
                width: 300,
                child: PrototypeSelect(
                    value: 'sourceSans',
                    options: artworkFontOptions,
                    optionStyle: (id) =>
                        artworkTextStyle(id).copyWith(fontSize: 14),
                    onChanged: (_) {})))));
    await tester.tap(find.text('思源黑体'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('Jost')).style!.fontFamily, 'LCJost');
    expect(tester.widget<Text>(find.text('得意黑')).style!.fontFamily, 'LCSmiley');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
}
