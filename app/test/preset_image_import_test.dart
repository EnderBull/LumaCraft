import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/editor/preset_code.dart';
import 'package:lumacraft/editor/qr_scan.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:qr/qr.dart';

/// 从分享图片里读回预设，这是「从图片导入」的核心。
void main() {
  /// 把代码画成二维码，模拟分享面板保存出来的图片。
  Uint8List renderPng(String text, {int scale = 8, int quiet = 4}) {
    final qr = QrImage(QrCode(
        payload: QrPayload.fromString(text),
        errorCorrectLevel: QrErrorCorrectLevel.medium));
    final count = qr.moduleCount;
    final side = (count + quiet * 2) * scale;
    final picture = img.Image(width: side, height: side);
    img.fill(picture, color: img.ColorRgb8(255, 255, 255));
    for (var y = 0; y < count; y++) {
      for (var x = 0; x < count; x++) {
        if (!qr.isDark(y, x)) continue;
        for (var dy = 0; dy < scale; dy++) {
          for (var dx = 0; dx < scale; dx++) {
            picture.setPixelRgb((x + quiet) * scale + dx,
                (y + quiet) * scale + dy, 0, 0, 0);
          }
        }
      }
    }
    return Uint8List.fromList(img.encodePng(picture));
  }

  /// 模拟完整的分享图：浅色底 + 中间二维码，四周留白。
  Uint8List shareCard(String text, {int cardWidth = 1000}) {
    final code = img.decodePng(renderPng(text))!;
    final card = img.Image(width: cardWidth, height: cardWidth);
    img.fill(card, color: img.ColorRgb8(43, 42, 39));
    img.compositeImage(card, code,
        dstX: (cardWidth - code.width) ~/ 2,
        dstY: (cardWidth - code.height) ~/ 2);
    return Uint8List.fromList(img.encodePng(card));
  }

  test('从分享图片识别二维码并还原预设', () {
    final doc = StyleDocument.template()..name = '城市街景';
    doc.borders['top'] = 32;
    doc.borders['bottom'] = 32;
    doc.fill.mode = 'gradient';
    final source = encodePresetCode(doc);

    final png = shareCard(source);
    final scanned = scanQrCode(png);
    expect(scanned, isNotNull, reason: '应能从分享图片里读到二维码');
    expect(scanned, source);

    final restored = decodePresetCode(scanned!);
    expect(restored.name, '城市街景');
    expect(restored.borders['top'], 32);
    expect(restored.fill.mode, 'gradient');
  });

  test('图片里没有二维码时返回 null，不报错', () {
    final blank = img.Image(width: 600, height: 400);
    img.fill(blank, color: img.ColorRgb8(120, 130, 140));
    expect(scanQrCode(Uint8List.fromList(img.encodePng(blank))), isNull);
  });

  test('不是图片的数据返回 null', () {
    expect(scanQrCode(Uint8List.fromList([1, 2, 3, 4, 5])), isNull);
  });

  test('二维码只占画面一小部分也能识别', () {
    final doc = StyleDocument.template()..name = '小码测试';
    final source = encodePresetCode(doc);
    final code = img.decodePng(renderPng(source, scale: 6))!;
    // 放进一张大图里，二维码只占中间一小块，模拟截图后裁剪的情况。
    final big = img.Image(width: 1600, height: 1200);
    img.fill(big, color: img.ColorRgb8(240, 238, 232));
    img.compositeImage(big, code,
        dstX: 500, dstY: 400);
    final scanned = scanQrCode(Uint8List.fromList(img.encodePng(big)));
    // ignore: avoid_print
    print('SCAN 小面积二维码: ${scanned == source ? "成功" : "失败"}');
    expect(scanned, source);
  });

  /// 真实分享图是深色面板 + 白色二维码卡片 + 旁边一张彩色照片。
  /// 之前只测纯黑白图，颜色通道写错也能过，这里用带颜色的场景再验一遍。
  test('深色面板 + 彩色照片的真实分享图也能识别', () {
    final doc = StyleDocument.template()..name = '真实场景';
    final source = encodePresetCode(doc);
    final code = img.decodePng(renderPng(source, scale: 6))!;

    // 深色面板背景
    final panel = img.Image(width: 1090, height: 732);
    img.fill(panel, color: img.ColorRgb8(43, 42, 39));
    // 左边一块彩色"照片"：蓝天、绿色地面，正是会暴露通道错误的情况
    for (var y = 80; y < 660; y++) {
      for (var x = 40; x < 640; x++) {
        final sky = y < 420;
        panel.setPixelRgb(x, y, sky ? 150 : 96, sky ? 205 : 148,
            sky ? 235 : 106);
      }
    }
    // 右边白色二维码卡片
    for (var y = 60; y < 60 + code.height + 28; y++) {
      for (var x = 680; x < 680 + code.width + 28; x++) {
        if (x < panel.width && y < panel.height)
          panel.setPixelRgb(x, y, 255, 255, 255);
      }
    }
    img.compositeImage(panel, code, dstX: 694, dstY: 74);

    final scanned = scanQrCode(Uint8List.fromList(img.encodePng(panel)));
    // ignore: avoid_print
    print('SCAN 真实分享图: ${scanned == source ? "成功" : "失败"}');
    expect(scanned, source, reason: '带彩色照片的分享图应能识别');
  });

  test('二维码印在彩色底上也能识别', () {
    final doc = StyleDocument.template()..name = '彩底';
    final source = encodePresetCode(doc);
    // 白底黑码是标准形态；这里把白底换成浅米色，验证不会因色偏失效。
    final qr = QrImage(QrCode(
        payload: QrPayload.fromString(source),
        errorCorrectLevel: QrErrorCorrectLevel.medium));
    const scale = 6, quiet = 4;
    final side = (qr.moduleCount + quiet * 2) * scale;
    final picture = img.Image(width: side, height: side);
    img.fill(picture, color: img.ColorRgb8(250, 247, 240));
    for (var y = 0; y < qr.moduleCount; y++) {
      for (var x = 0; x < qr.moduleCount; x++) {
        if (!qr.isDark(y, x)) continue;
        for (var dy = 0; dy < scale; dy++) {
          for (var dx = 0; dx < scale; dx++) {
            picture.setPixelRgb((x + quiet) * scale + dx,
                (y + quiet) * scale + dy, 20, 17, 13);
          }
        }
      }
    }
    expect(scanQrCode(Uint8List.fromList(img.encodePng(picture))), source);
  });

  test('声明为超大尺寸的图片在解码前被拒绝', () {
    final png = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));
    // IHDR 宽高在第 16～23 字节；改成 1 万 × 1 万，文件本身仍只有几十字节。
    final data = ByteData.sublistView(png);
    data.setUint32(16, 10000);
    data.setUint32(20, 10000);
    expect(png.length, lessThan(200));
    expect(() => scanQrCode(png), throwsFormatException);
  });

  test('过大的图片文件被拒绝', () {
    expect(() => scanQrCode(Uint8List(qrImageMaxBytes + 1)),
        throwsFormatException);
  });}
