import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:qr/qr.dart';
import 'package:lumacraft/editor/preset_code.dart';
import 'package:lumacraft/editor/qr_scan.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/ui/android/preset_qr_card.dart';

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
    expect(scanQrCode(encodePresetQrPng(data)), data);
  });

  test('相机灰度帧能识别预设二维码并交给同一校验器', () async {
    final code = encodePresetCode(StyleDocument.template()..name = '相机预设');
    final qr = image.decodePng(encodePresetQrPng(code))!;
    final frame = (
      bytes: Uint8List.fromList([for (final pixel in qr) pixel.r.toInt()]),
      width: qr.width,
      height: qr.height,
    );
    final decoded = scanQrCameraFrame(frame);
    expect(decoded, code);
    expect((await decodePresetCodeAsync(decoded!)).name, '相机预设');
    expect(
        scanQrCameraFrame((bytes: Uint8List(3), width: 4, height: 4)), isNull);
  });

  testWidgets('带底栏的二维码图片可回读原始码和近容量上限的码', (tester) async {
    await tester.runAsync(() async {
      final regular = encodePresetCode(StyleDocument.template());
      final dense = List.generate(presetCodeQrLimit,
          (i) => 'abcdefghijklmnopqrstuvwxyz0123456789'[i % 36]).join();
      for (final code in [regular, dense]) {
        final bytes = await renderPresetQrCard(code, '画廊签名');
        final card = image.decodePng(bytes)!;
        expect(card.height, greaterThan(card.width));
        expect(card.getPixel(0, 0).r, 255);
        expect(card.getPixel(0, card.height - 1).r, 40);
        expect(scanQrCode(bytes), code);
      }
    });
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
