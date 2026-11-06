import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/preset_code.dart';
import 'package:lumacraft/editor/qr_scan.dart';

/// 用用户真实保存的分享图验证识别：这是「从图片导入」的真实场景。
void main() {
  const path = r'C:\Users\nrw01\OneDrive\Desktop\画廊签名-分享.png';

  test('真实分享图能识别出完整代码', () {
    final file = File(path);
    if (!file.existsSync()) {
      // ignore: avoid_print
      print('跳过：测试图片不在');
      return;
    }
    final clock = Stopwatch()..start();
    final scanned = scanQrCode(file.readAsBytesSync());
    clock.stop();
    // ignore: avoid_print
    print('REAL 识别 ${scanned?.length ?? 0} 字符, 耗时 ${clock.elapsedMilliseconds}ms');
    expect(scanned, isNotNull, reason: '真实分享图必须能识别');
    expect(scanned!.startsWith('LC1:'), isTrue);
    // 图上标注 1086 字符，识别结果应与之一致。
    expect(scanned.length, 1086);

    // 识别出来的内容必须能还原成预设。
    final style = decodePresetCode(scanned);
    // ignore: avoid_print
    print('REAL 预设名: ${style.name}');
    expect(style.name, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
