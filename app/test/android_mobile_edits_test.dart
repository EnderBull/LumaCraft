import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/settings/android_map_preview.dart';
import 'package:lumacraft/ui/android/mobile_edits.dart';

void main() {
  test('选点回传采用地点名或有效坐标', () {
    expect(androidPlaceFromTitle('PICK:1|地标|东门|116.3,39.9'), '地标|东门');
    expect(androidPlaceFromTitle('PICK:2||116.3,39.9'), '116.3,39.9');
    expect(androidPlaceFromTitle('PICK:3|无效地点|190,39.9'), isNull);
    expect(androidPlaceFromTitle('STATE:地图已加载'), isNull);
  });

  test('共用样式保留构图，撤销与重做只更改对应照片内容', () {
    final doc = StyleDocument.template();
    final id = doc.nodes.first.id;
    final originalText = doc.nodes.first.text;
    doc.adaptive = true;
    doc.switchLayout('portrait');
    doc.node(id)!
      ..x = 22
      ..fontSize = 17;
    doc.switchLayout('general');

    final edits = MobileEdits(doc);
    addTearDown(edits.dispose);
    edits.editComponent(id, (node) => node.fontSize = 38);
    edits.editCaption('first', 'preset', id, '首张');
    edits.editCaption('second', 'preset', id, '第二张');
    edits.editCapture('first', 'camera', '补填相机');

    expect(edits.style.forRatio(.5).node(id)?.fontSize, 38);
    expect(edits.style.forRatio(.5).node(id)?.x, 22);
    expect(edits.style.order, doc.order);
    expect(edits.style.node(id)?.text, originalText);
    expect(edits.styleFor('first', 'preset').node(id)?.text, '首张');
    expect(edits.styleFor('second', 'preset').node(id)?.text, '第二张');
    expect(edits.styleFor('first', 'preset').forRatio(.5).node(id)?.text, '首张');
    expect(edits.styleFor('first', 'another').node(id)?.text, originalText);
    expect(edits.fieldsFor('first', {'camera': '原始'})['camera'], '补填相机');
    expect(edits.fieldsFor('second', {'camera': '原始'})['camera'], '原始');

    edits.undo();
    edits.undo();
    expect(edits.styleFor('second', 'preset').node(id)?.text, originalText);
    expect(edits.styleFor('first', 'preset').node(id)?.text, '首张');
    edits.undo();
    edits.undo();
    expect(edits.style.forRatio(.5).node(id)?.fontSize, 17);
    edits.redo();
    edits.redo();
    expect(edits.style.forRatio(.5).node(id)?.fontSize, 38);
    expect(edits.styleFor('first', 'preset').node(id)?.text, '首张');
  });
  test('预设数值复位保留独立横竖默认值，拖动预览不写历史', () {
    final baseline = StyleDocument.template()..adaptive = true;
    final id = baseline.nodes.first.id;
    final initial = baseline.node(id)!.fontSize;
    baseline.switchLayout('portrait');
    baseline.node(id)!.fontSize = 19;
    baseline.switchLayout('general');
    final edits = MobileEdits(baseline);
    addTearDown(edits.dispose);

    edits.previewComponent(id, (n) => n.fontSize = 66);
    expect(edits.styleFor('photo', 'preset').node(id)!.fontSize, 66);
    expect(edits.style.node(id)!.fontSize, initial);
    expect(edits.canUndo, isFalse);
    edits.editComponent(id, (n) => n.fontSize = 66);
    edits.resetComponentNumber(
        id, baseline, (n) => n.fontSize, (n, value) => n.fontSize = value);
    expect(edits.style.node(id)!.fontSize, initial);
    expect(edits.style.forRatio(.5).node(id)!.fontSize, 19);
    edits.undo();
    expect(edits.style.forRatio(.5).node(id)!.fontSize, 66);
  });
  test('会话快照保留两张照片各自的文字和地点', () {
    final style = StyleDocument.template();
    final id = style.nodes.first.id;
    final original = MobileEdits(style);
    addTearDown(original.dispose);
    original.editCaption('first', 'gallery', id, '第一张');
    original.editCaption('second', 'gallery', id, '第二张');
    original.editCapture('second', 'place', '西湖');
    final restored = MobileEdits(style);
    addTearDown(restored.dispose);
    restored.restore(original.snapshot({'first', 'second'}));
    expect(restored.caption('first', 'gallery', id), '第一张');
    expect(restored.caption('second', 'gallery', id), '第二张');
    expect(restored.captureValue('first', 'place'), isNull);
    expect(restored.captureValue('second', 'place'), '西湖');
    expect(restored.canUndo, isFalse);
  });
}
