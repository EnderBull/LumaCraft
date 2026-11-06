import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart';
import 'package:lumacraft/editor/preset_code.dart';
import 'package:lumacraft/editor/style_document.dart';

/// 分享面板把文本代码画成二维码。这里验证二维码库能吃下真实预设的代码，
/// 并确认超出容量时报错而不是画出错码。
void main() {
  test('真实预设的代码都能生成二维码', () {
    final doc = StyleDocument.template()..name = '画廊签名';
    doc.borders['top'] = 30;
    doc.borders['bottom'] = 30;
    doc.fill.mode = 'texture';
    final code = encodePresetCode(doc);
    expect(presetCodeTooLarge(code), isFalse);
    final qr = QrImage(QrCode(
        payload: QrPayload.fromString(code),
        errorCorrectLevel: QrErrorCorrectLevel.medium));
    expect(qr.moduleCount, greaterThan(20));
    expect(qr.isDark(0, 0), isTrue, reason: '左上角应有定位图案');
  });

  test('接近容量上限的代码仍能生成', () {
    final filler = StringBuffer('LC1:test:');
    while (filler.length < presetCodeQrLimit - 4) {
      filler.write('abcdefghij');
    }
    final data = filler.toString();
    expect(presetCodeBytes(data), lessThanOrEqualTo(presetCodeQrLimit));
    final qr = QrImage(QrCode(
        payload: QrPayload.fromString(data),
        errorCorrectLevel: QrErrorCorrectLevel.medium));
    expect(qr.moduleCount, lessThanOrEqualTo(177));
  });

  test('超过上限时判定为装不下（不试图生成）', () {
    final data = 'x' * (presetCodeQrLimit + 10);
    expect(presetCodeTooLarge(data), isTrue);
    // 这一条是给界面用的判断：超限就不能画二维码，否则库会直接抛错。
    expect(
        () => QrImage(QrCode(
            payload: QrPayload.fromString(data),
            errorCorrectLevel: QrErrorCorrectLevel.medium)),
        throwsA(isA<Object>()));
  });
}
