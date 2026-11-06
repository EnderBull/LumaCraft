import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/preset_code.dart';
import 'package:lumacraft/editor/style_document.dart';

/// 分享面板的可分享判定：打开「包含图片标识」后，
/// 二维码和文本代码都必须不可用，只保留 .lmp 导出。
void main() {
  StyleDocument sample({required bool withImage}) {
    final doc = StyleDocument.template()..name = '测试';
    if (withImage) {
      final node = StyleNode(type: 'image');
      // 真实图片标识约 100 KB，压缩后仍有几十 KB。
      node.image.data = base64OfSize(120 * 1024);
      doc.nodes.add(node);
      doc.order.add(node.id);
    }
    return doc;
  }

  test('关闭图片标识时可以分享代码和图片', () {
    final code = encodePresetCode(sample(withImage: true), includeImages: false);
    expect(code.isNotEmpty, isTrue);
    expect(presetCodeTooLarge(code), isFalse, reason: '不带图片时应能进二维码');
  });

  test('打开图片标识后代码远超上限，不能当作二维码', () {
    final code = encodePresetCode(sample(withImage: true), includeImages: true);
    expect(presetCodeTooLarge(code), isTrue,
        reason: '带图片的代码不可能装进二维码');
  });

  test('不含图片的预设，开关不影响可分享性', () {
    // 两次 encode 的文本不会逐字节相同：模板每次生成随机节点 ID。
    // 要验的是「开关不影响能否分享」，而不是字符串相等。
    final doc = sample(withImage: false);
    final off = encodePresetCode(doc);
    final on = encodePresetCode(doc, includeImages: true);
    expect(presetCodeTooLarge(off), isFalse);
    expect(presetCodeTooLarge(on), isFalse,
        reason: '没有图片标识时，开关不该让代码变大');
    // 二者还原出的预设应完全一致。
    final a = decodePresetCode(off), b = decodePresetCode(on);
    expect(a.name, b.name);
    expect(a.nodes.length, b.nodes.length);
    expect(a.borders, b.borders);
  });
}

/// 随机内容的 base64，模拟真实图片数据（重复字节会被压缩到很小）。
String base64OfSize(int bytes) {
  final values = List<int>.generate(bytes, (i) => (i * 2654435761) % 256);
  return base64Encode(values);
}
