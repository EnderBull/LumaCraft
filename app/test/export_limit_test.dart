import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/export/color_management.dart';
import 'package:lumacraft/export/export_options.dart';
import 'package:lumacraft/export/export_recovery.dart';
import 'package:lumacraft/render.dart';

void main() {
  test('成片可以顶到最长边和总像素上限，再大就要求缩小', () {
    expect(exportMaxPixels, 134217728);
    validateExportSize(16384, 8192);
    expect(exceedsExportLimit(16384, 8192), isFalse);
    expect(() => validateExportSize(16384, 8193),
        throwsA(isA<ExportSizeException>()));
    expect(() => validateExportSize(16385, 100),
        throwsA(isA<ExportSizeException>()));
    expect(const ExportSizeException().toString(), contains('请缩小尺寸'));
    expect(exportSafeLongEdge(4000), 4000);
    final edge = exportSafeLongEdge(16384);
    expect(edge * edge, lessThanOrEqualTo(exportMaxPixels));
    expect((edge + 1) * (edge + 1), greaterThan(exportMaxPixels));
    expect(
        explainDecodeFailure('Windows color conversion failed: 0x8007000E',
            heif: false),
        contains('请缩小尺寸'));
    final missing = explainDecodeFailure(
        'Windows color conversion failed: 0x80040154',
        heif: true);
    expect(asksForHeifCodec(missing), isTrue);
    expect(asksForHeifCodec('照片解码或色彩转换失败，未生成文件。'), isFalse);
    expect(heifStoreProductId, '9PMMSR1CGPWG');
    expect(hevcStoreProductId, '9N4WGH0Z6VHQ');
  });

  test('导出没做完的记录会保留，主动关闭和崩溃都会说明原因', () async {
    final dir = Directory('build/export-ui-check-0150-limit');
    await dir.create(recursive: true);
    final store = ExportRecoveryStore(File('${dir.path}/export-recovery.json'));
    await store.write(const ExportRecovery('大图.jpg', width: 6144, height: 8192));
    final crash = await store.readInterrupted();
    expect(crash?.fileName, '大图.jpg');
    expect(crash?.pixels, 6144 * 8192);
    final message = exportRecoveryMessage(crash!);
    expect(message, contains('不会恢复导出'));
    expect(message, contains('不是正常关闭'));
    expect(exportRecoveryMessage(crash, closedByUser: true),
        contains('被关闭了'));

    // 上次是自己关的窗口：仍然报告，只是措辞不同。
    await store.write(const ExportRecovery('大图.jpg', width: 6144, height: 8192));
    await store.dismissedFile.writeAsString('');
    expect(await store.closedByUser(), isTrue);
    expect(await store.readInterrupted(), isNotNull);
    // 标记被消费掉，不会一直挂着。
    expect(await store.dismissedFile.exists(), isFalse);
  });
}
