import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/editor/builtin_library.dart';
import 'package:lumacraft/editor/editor_controller.dart';
import 'package:lumacraft/editor/preset_package.dart';
import 'package:lumacraft/editor/shape_render.dart';
import 'package:lumacraft/editor/shape_style.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/style_render.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/ui/editor/shape_picker.dart';
import 'package:flutter/services.dart';

Future<img.Image> paintToImage(ShapeStyle s, {double opacity = 100}) async {
  final recorder = ui.PictureRecorder();
  paintShape(Canvas(recorder), const Offset(150, 150), s, opacity);
  final picture = recorder.endRecording();
  final image = await picture.toImage(300, 300);
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final out = img.Image.fromBytes(
      width: 300,
      height: 300,
      bytes: data.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba);
  image.dispose();
  picture.dispose();
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('参数保存读取、范围限制与种类切换', () {
    final s = ShapeStyle(kind: 'trapezoid', width: 99, rotation: 45, inset: .3)
      ..stroke = true
      ..strokeOpacity = 40
      ..fillOpacity = 70;
    final back = ShapeStyle.fromJson(s.toJson());
    expect(back.kind, 'trapezoid');
    expect(back.rotation, 45);
    expect(back.strokeOpacity, 40, reason: '描边与填充的不透明度必须分开保存');
    expect(back.fillOpacity, 70);
    final wild = ShapeStyle.fromJson({
      'kind': 'unknown',
      'width': 1e9,
      'height': -5,
      'rotation': -90,
      'skew': 9,
      'inset': 9,
      'fillOpacity': 500
    });
    expect(wild.kind, 'rect');
    expect(wild.width, shapeLimits['width']!.$2);
    expect(wild.height, shapeLimits['height']!.$1);
    expect(wild.rotation, 270, reason: '负角度按 360° 折算');
    expect(wild.skew, shapeLimits['skew']!.$2);
    expect(wild.inset, shapeLimits['inset']!.$2);
    expect(wild.fillOpacity, 100);
    final shape = ShapeStyle(width: 200, height: 90);
    shape.applyKind('line');
    expect(shape.height, 3);
    shape.applyKind('rect');
    expect(shape.height, greaterThan(20), reason: '线条切回块状形状时不能保持细线厚度');
  });

  test('八种形状都能绘制，圆角不超出外接矩形，旋转后的外接矩形正确', () async {
    for (final kind in shapeKindNames.keys) {
      final s = ShapeStyle(kind: kind, width: 120, height: 80, radius: 12)
        ..stroke = kind != 'line'
        ..strokeWidth = 4;
      final bounds = shapePath(s).getBounds();
      expect(bounds.width, lessThanOrEqualTo(120.01), reason: kind);
      expect(bounds.height, lessThanOrEqualTo(80.01), reason: kind);
      final image = await paintToImage(s);
      expect(image.toUint8List().any((v) => v != 0), true, reason: '$kind 应有绘制内容');
    }
    final rotated = shapeBounds(const Offset(100, 100),
        ShapeStyle(width: 100, height: 20, rotation: 90));
    expect(rotated.width, closeTo(20, .001));
    expect(rotated.height, closeTo(100, .001));
    expect(rotated.center.dx, closeTo(100, .001));
  });

  test('填充与描边独立不透明度，三角形左右分别设色', () async {
    final rect = ShapeStyle(kind: 'rect', width: 100, height: 100)
      ..fillColor = 0xffff0000
      ..fillOpacity = 50
      ..stroke = true
      ..strokeWidth = 10
      ..strokeColor = 0xff0000ff
      ..strokeOpacity = 100;
    final image = await paintToImage(rect);
    final center = image.getPixel(150, 150);
    expect(center.a, closeTo(128, 2), reason: '填充 50%');
    final edge = image.getPixel(150 - 50, 150);
    expect(edge.a, 255, reason: '描边 100% 覆盖在填充之上');
    expect(edge.b, 255);
    final triangle = ShapeStyle(kind: 'triangle', width: 120, height: 120)
      ..fillColor = 0xffff0000
      ..fillColor2 = 0xff0000ff
      ..split = true;
    final split = await paintToImage(triangle);
    expect(split.getPixel(135, 190).r, 255, reason: '左半为第一种颜色');
    expect(split.getPixel(165, 190).b, 255, reason: '右半为第二种颜色');
    for (var y = 150; y < 205; y++) {
      expect(split.getPixel(150, y).a, 255, reason: '交界线不能透出背景');
    }
    final faded = await paintToImage(triangle..fillOpacity = 50);
    expect(faded.getPixel(165, 190).a, closeTo(128, 2));
    expect(faded.getPixel(135, 190).a, closeTo(128, 2), reason: '半透明时两色整体套用不透明度，不叠加变浓');
  });

  test('线条：圆头与虚线', () async {
    final solid = await paintToImage(
        ShapeStyle(kind: 'line', width: 200, height: 10, fillColor: 0xff000000));
    expect(solid.getPixel(150, 150).a, 255);
    final dashed = await paintToImage(ShapeStyle(
        kind: 'line', width: 200, height: 10, fillColor: 0xff000000)
      ..dashed = true);
    var gaps = 0;
    for (var x = 50; x < 250; x++) {
      if (dashed.getPixel(x, 150).a == 0) gaps++;
    }
    expect(gaps, greaterThan(20), reason: '虚线应有空隙');
    final round = await paintToImage(ShapeStyle(
        kind: 'line', width: 200, height: 20, fillColor: 0xff000000)
      ..round = true);
    expect(round.getPixel(51, 141).a, lessThan(255), reason: '圆头端点的角应被削去');
    final flat = await paintToImage(ShapeStyle(
        kind: 'line', width: 200, height: 20, fillColor: 0xff000000));
    expect(flat.getPixel(51, 141).a, 255);
  });

  test('抓点：宽高、圆角、专有参数随拖动变化，旋转后对侧顶点保持不动', () {
    final rect = ShapeStyle(kind: 'rect', width: 100, height: 60, radius: 10);
    final grips = shapeGrips(rect, 5);
    expect(grips.where((g) => g.type == 'size').length, 8);
    expect(grips.where((g) => g.type == 'radius').length, 1);
    dragShapeRadius(rect, const Offset(50 - 20 - 5, 30), 5);
    expect(rect.radius, closeTo(20, .001));
    dragShapeRadius(rect, const Offset(0, 30), 5);
    expect(rect.radius, closeTo(shapeMaxCut(rect), .001), reason: '圆角不能超过最短边的一半');

    final para = ShapeStyle(kind: 'parallelogram', width: 200, height: 60);
    dragShapeAdjust(para, const Offset(-100 + 50, -30));
    expect(para.skew, closeTo(.25, .001));
    final trap = ShapeStyle(kind: 'trapezoid', width: 200, height: 60);
    dragShapeAdjust(trap, const Offset(-100 + 60, -30));
    expect(trap.inset, closeTo(.3, .001));
    final hex = ShapeStyle(kind: 'hexagon', width: 200, height: 100);
    dragShapeAdjust(hex, const Offset(-100 + 80, -50));
    expect(hex.inset, closeTo(.4, .001));
    hex.pointy = true;
    dragShapeAdjust(hex, const Offset(100, -50 + 30));
    expect(hex.inset, closeTo(.3, .001));

    // 旋转 90° 后，局部右侧抓点指向画布下方；左侧顶点固定在 (0,-50)。
    final r = resizeShapeByGrip(
        center: Offset.zero,
        rotation: 90,
        width: 100,
        height: 50,
        sx: 1,
        sy: 0,
        pointer: const Offset(0, 100));
    expect(r.width, closeTo(150, .001));
    expect(r.height, 50);
    expect(r.center.dx, closeTo(0, .001));
    expect(r.center.dy, closeTo(25, .001));
    final proportional = resizeShapeByGrip(
        center: Offset.zero,
        rotation: 0,
        width: 100,
        height: 50,
        sx: 1,
        sy: 1,
        pointer: const Offset(150, 40),
        keepRatio: true);
    expect(proportional.width / proportional.height, closeTo(2, .001));
    final minimum = resizeShapeByGrip(
        center: Offset.zero,
        rotation: 0,
        width: 100,
        height: 50,
        sx: 1,
        sy: 0,
        pointer: const Offset(-500, 0));
    expect(minimum.width, 1, reason: '拖过对侧时保持最小尺寸，不翻转');
    final back = shapeToLocal(const Offset(5, 5), 37,
        shapeToWorld(const Offset(5, 5), 37, const Offset(12, -8)));
    expect(back.dx, closeTo(12, .001));
    expect(back.dy, closeTo(-8, .001));
  });

  test('样式文档、横竖布局覆盖、撤销与 .lmp 往返', () {
    final c = EditorController(StyleDocument(name: '形状测试'));
    c.add('shape', 1.5);
    final node = c.doc.nodes.single;
    expect(node.type, 'shape');
    c.edit(() {
      node.shape.kind = 'hexagon';
      node.shape.width = 150;
      node.shape.split = true;
    });
    c.undo();
    expect(c.doc.nodes.single.shape.kind, 'rect');
    c.redo();
    expect(c.doc.nodes.single.shape.kind, 'hexagon');

    final doc = c.doc.copy()..setAdaptive(true);
    doc.switchLayout('portrait');
    final portrait = doc.nodes.single;
    portrait.shape.width = 60;
    portrait.shape.rotation = 30;
    doc.switchLayout('general');
    expect(doc.nodes.single.shape.width, 150, reason: '竖图覆盖不影响通用布局');
    expect(doc.forRatio(2 / 3).nodes.single.shape.width, 60);
    expect(doc.forRatio(2 / 3).nodes.single.shape.rotation, 30);
    expect(doc.forRatio(1.5).nodes.single.shape.width, 150);

    final text = encodeLmp([SharedPreset(doc)]);
    final json = jsonDecode(text) as Map;
    expect(json['requires'], contains('shapeV1'));
    final back = decodeLmp(text).single.style;
    expect(back.nodes.single.shape.kind, 'hexagon');
    expect(back.forRatio(2 / 3).nodes.single.shape.width, 60);

    final plain = StyleDocument(name: '无形状');
    expect(
        (jsonDecode(encodeLmp([SharedPreset(plain)])) as Map)['requires'],
        isNot(contains('shapeV1')));

    final bad = jsonDecode(text) as Map;
    ((bad['presets'] as List).first['style']['nodes'] as List).first['shape']
        ['kind'] = 'star';
    expect(() => decodeLmp(jsonEncode(bad)), throwsFormatException);
    final badLayout = jsonDecode(text) as Map;
    (((badLayout['presets'] as List).first['style']['layouts'] as Map)['portrait']
        ['nodes'] as Map).values.first['shape']['width'] = 99999;
    expect(() => decodeLmp(jsonEncode(badLayout)), throwsFormatException);
    final old = jsonDecode(text) as Map;
    old['requires'] = ['shapeV2'];
    expect(() => decodeLmp(jsonEncode(old)), throwsFormatException,
        reason: '未知能力一律拒绝');
    c.dispose();
  });

  test('内置预设里的短线是形状组件，尺寸与原字符一致，且不再有字符短线', () async {
    final library = BuiltinLibrary.decode(
        await File('assets/builtins/library.json').readAsString());
    StyleNode node(String preset, String id) => library.entries
        .firstWhere((e) => e.id == preset)
        .style
        .nodes
        .firstWhere((n) => n.id == id);
    for (final id in ['gallery-line-left', 'gallery-line-right']) {
      final n = node('gallery', id);
      expect(n.type, 'shape', reason: id);
      expect(n.shape.kind, 'line');
      expect(n.shape.width, closeTo(25.38, .001), reason: '长度与原“——”字符一致');
      expect(n.shape.height, closeTo(1.0, .001), reason: '粗细与原“——”字符一致');
    }
    final accent = node('travel', 'travel-accent');
    expect(accent.type, 'shape');
    expect(accent.shape.kind, 'line');
    expect(accent.shape.rotation, 90);
    expect(accent.shape.width, closeTo(42, .001), reason: '竖条高度 42，与原“▎”一致');
    expect(accent.shape.height, closeTo(9.5, .001),
        reason: '方图/竖图上原“▎”左侧 1 px 在画布外被裁掉，可见宽度 9.5');
    expect(
        library.entries
            .firstWhere((e) => e.id == 'travel')
            .style
            .forRatio(1.5)
            .node('travel-accent')!
            .shape
            .height,
        closeTo(10.5, .001),
        reason: '横图未被裁，宽度 10.5，与原“▎”一致');
    for (final e in library.entries) {
      for (final n in e.style.nodes.where((n) => n.type == 'text')) {
        expect(RegExp(r'^[\s|│┃—▎▏\-]+$').hasMatch(n.text), false,
            reason: '${e.id}/${n.id} 不应再用字符画短线');
      }
    }
    expect(library.entries.firstWhere((e) => e.id == 'travel').style
        .forRatio(2 / 3).node('travel-accent')!.y, closeTo(25.75, .001));
  });

  testWidgets('形状选择器：8 个图标 4×2 排列，带名称，点选切换', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var kind = 'rect';
    final changes = <String>[];
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(true),
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 264,
                    child: StatefulBuilder(
                        builder: (context, set) => ShapePicker(
                            value: kind,
                            onChanged: (v) {
                              changes.add(v);
                              set(() => kind = v);
                            })))))));
    expect(find.byType(ShapeKindIcon), findsOneWidget, reason: '收起时只显示当前形状图标');
    await tester.tap(find.byType(ShapePicker));
    await tester.pumpAndSettle();
    expect(find.byType(ShapeKindIcon), findsNWidgets(9), reason: '触发器 1 个加网格 8 个');
    for (final name in shapeKindNames.values) {
      expect(find.text(name), findsWidgets);
    }
    final grid = shapeKindNames.keys
        .map((k) => tester
            .getTopLeft(find.descendant(
                of: find.byType(InkWell), matching: find.byType(ShapeKindIcon)).at(
                    shapeKindNames.keys.toList().indexOf(k) + 1)))
        .toList();
    for (var i = 0; i < 4; i++) {
      expect(grid[i].dy, closeTo(grid[0].dy, .5), reason: '第一行 4 个图标等高');
      expect(grid[i + 4].dy, closeTo(grid[4].dy, .5), reason: '第二行 4 个图标等高');
      expect(grid[i].dx, closeTo(grid[i + 4].dx, .5), reason: '两行的列对齐');
    }
    expect(grid[4].dy, greaterThan(grid[0].dy + 40), reason: '共两行');
    expect(grid[1].dx, greaterThan(grid[0].dx));
    expect(tester.takeException(), null);
    await tester.tap(find.text('菱形'));
    await tester.pumpAndSettle();
    expect(changes, ['diamond']);
    expect(find.byType(ShapeKindIcon), findsOneWidget, reason: '点选后立即关闭');
    await tester.tap(find.byType(ShapePicker));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ShapeKindIcon), findsOneWidget, reason: 'Esc 关闭且不改变形状');
    expect(changes.length, 1);
  });

  test('导出渲染包含形状，位置随锚点和旋转生效', () async {
    final directory = await Directory(
            'test/shape-output/run-${DateTime.now().millisecondsSinceEpoch}')
        .create(recursive: true);
    final source = img.Image(width: 600, height: 400);
    img.fill(source, color: img.ColorRgb8(200, 200, 200));
    final file = File('${directory.path}/source.jpg');
    await file.writeAsBytes(img.encodeJpg(source, quality: 100));
    final doc = StyleDocument(
        borders: {'top': 0, 'left': 0, 'right': 0, 'bottom': 20});
    final bar = StyleNode(
        type: 'shape', name: '色条', anchor: 'bottom', x: 50, y: 50)
      ..shape = ShapeStyle(
          kind: 'rect',
          width: 300,
          height: 40,
          fillColor: 0xffff0000,
          rotation: 0);
    doc.nodes.add(bar);
    doc.order.add(bar.id);
    final output = await renderStyledPhoto(file.path, doc, {}, true);
    await File('${directory.path}/shape.png').writeAsBytes(output);
    final decoded = img.decodePng(output)!;
    final g = StyleGeometry(doc, 1.5), point = g.point(bar);
    final scale = decoded.height / g.size.height;
    final pixel = decoded.getPixel(
        (point.dx * scale).round(), (point.dy * scale).round());
    expect(pixel.r, 255);
    expect(pixel.g, lessThan(5));
    final outside = decoded.getPixel(
        ((point.dx + 200) * scale).round(), (point.dy * scale).round());
    expect(outside.r, greaterThan(190));
    expect(outside.g, greaterThan(190), reason: '形状范围外保持背景色');
  });
}
