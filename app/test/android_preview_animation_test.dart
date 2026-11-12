import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/editor/style_render.dart';

void main() {
  testWidgets('编辑栏缩放预览区域时复用照片绘制层', (tester) async {
    final photo = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(Colors.blue, ui.BlendMode.src);
      final picture = recorder.endRecording();
      try {
        return await picture.toImage(80, 60);
      } finally {
        picture.dispose();
      }
    });
    addTearDown(photo!.dispose);
    final height = ValueNotifier<double>(360);
    addTearDown(height.dispose);
    final style = StyleDocument.template();
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: ValueListenableBuilder<double>(
          valueListenable: height,
          child: StylePreview(
            photo: photo,
            document: style,
            onComponentTap: (_) {},
            selectedComponent: style.nodes.first.id,
          ),
          builder: (context, value, child) =>
              SizedBox(width: 320, height: value, child: child),
        ),
      ),
    ));
    final finder = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is StylePainter,
    );
    final layer = tester.renderObject<RenderCustomPaint>(finder).parent!
        as RenderRepaintBoundary;
    final initialPaints = layer.debugSymmetricPaintCount;
    final initialComposites = layer.debugAsymmetricPaintCount;
    for (final size in [320.0, 280.0, 240.0, 200.0, 160.0]) {
      height.value = size;
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.renderObject<RenderCustomPaint>(finder).parent, same(layer));
    expect(layer.debugSymmetricPaintCount, initialPaints);
    expect(layer.debugAsymmetricPaintCount, initialComposites + 5);
  });
}
