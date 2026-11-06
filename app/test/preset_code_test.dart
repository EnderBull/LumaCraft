import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/preset_code.dart';
import 'package:lumacraft/editor/style_document.dart';

/// 分享文本：编码后必须能原样还原，关掉图片标识时只丢图片数据，
/// 坏文本要给出明确提示而不是崩溃。
void main() {
  StyleDocument sample({bool withImage = false}) {
    final doc = StyleDocument.template()
      ..name = '测试预设'
      ..suitability = 'portrait';
    doc.nodes.first.text = 'HELLO';
    doc.borders['top'] = 40;
    doc.fill.mode = 'gradient';
    if (withImage) {
      final node = StyleNode(type: 'image');
      node.image.data = base64Encode(List<int>.filled(4096, 7));
      node.image.ratio = 1.5;
      node.image.width = 200;
      doc.nodes.add(node);
      doc.order.add(node.id);
    }
    return doc;
  }

  test('编码后能原样还原', () {
    final doc = sample();
    final code = encodePresetCode(doc);
    expect(code.startsWith(presetCodePrefix), isTrue);
    final back = decodePresetCode(code);
    expect(back.name, '测试预设');
    expect(back.suitability, 'portrait');
    expect(back.borders['top'], 40);
    expect(back.fill.mode, 'gradient');
    expect(back.nodes.first.text, 'HELLO');
    expect(back.nodes.length, doc.nodes.length);
  });

  test('文本比 .lmp 短很多', () {
    final doc = sample();
    final code = encodePresetCode(doc);
    // 去掉默认值这一步至少能把体积压到原来的一半以下。
    expect(code.length, lessThan(700));
  });

  test('关掉图片标识时只丢图片数据，保留位置和比例', () {
    final doc = sample(withImage: true);
    final without = decodePresetCode(encodePresetCode(doc));
    final node = without.nodes.firstWhere((n) => n.type == 'image');
    expect(node.image.data, isEmpty);
    expect(node.image.ratio, 1.5);
    expect(node.image.width, 200);

    final with_ = decodePresetCode(
        encodePresetCode(doc, includeImages: true));
    expect(with_.nodes.firstWhere((n) => n.type == 'image').image.data,
        isNotEmpty);
  });

  test('带图片标识的代码远超二维码容量，不带才装得下', () {
    // 真实图片约 100 KB，压缩后仍有几十 KB。这里用随机字节模拟：
    // 重复字节会被 gzip 压到极小，测不出真实情况。
    final doc = sample();
    final node = StyleNode(type: 'image');
    // True random bytes: a repeating pattern compresses to almost nothing.
    final random = Random(7);
    node.image.data =
        base64Encode(List<int>.generate(120 * 1024, (_) => random.nextInt(256)));
    doc.nodes.add(node);
    doc.order.add(node.id);
    expect(presetCodeTooLarge(encodePresetCode(doc, includeImages: true)),
        isTrue, reason: '真实大小的图片不可能装进二维码');
    expect(presetCodeTooLarge(encodePresetCode(doc)), isFalse,
        reason: '去掉图片后应能装进二维码');
  });

  test('截断或改动的文本会被校验码拦下', () {
    final code = encodePresetCode(sample());
    final cut = code.substring(0, code.length - 5);
    expect(() => decodePresetCode(cut), throwsFormatException);
    final swapped = code.replaceRange(code.length - 3, code.length - 2, 'Z');
    expect(() => decodePresetCode(swapped), throwsFormatException);
  });

  test('不是预设代码的文本给出明确提示', () {
    expect(() => decodePresetCode('随便一段话'), throwsFormatException);
    expect(() => decodePresetCode(''), throwsFormatException);
    expect(() => decodePresetCode('LC1:'), throwsFormatException);
  });

  test('常见预设都在二维码容量内', () {
    for (final entry in {
      '极简黑框': () => StyleDocument.template()..name = '极简黑框',
      '复杂': () {
        final doc = StyleDocument.template()..name = '复杂';
        doc.borders['top'] = 40;
        doc.borders['bottom'] = 40;
        doc.borders['left'] = 40;
        doc.borders['right'] = 40;
        doc.fill.mode = 'texture';
        doc.stamp.enabled = true;
        return doc;
      },
    }.entries) {
      final code = encodePresetCode(entry.value());
      expect(presetCodeTooLarge(code), isFalse,
          reason: '${entry.key} 应能装进二维码，实际 ${presetCodeBytes(code)} 字节');
    }
  });
}
