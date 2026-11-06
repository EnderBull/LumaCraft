import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/photo_relink.dart';
import 'package:lumacraft/photo_state.dart';

/// 模拟真实流程：在 A 文件夹用过一张照片，记录里存了拍摄时间；
/// 把照片挪到 B 文件夹后，重新打开 B，检查是否按名字加时间接回。
void main() {
  test('照片换文件夹后按名字和拍摄时间接回记录', () async {
    final root = Directory('build/export-ui-check-0150-relink/e2e');
    if (await root.exists()) await root.delete(recursive: true);
    final a = Directory('${root.path}/A')..createSync(recursive: true);
    final b = Directory('${root.path}/B')..createSync(recursive: true);
    final picture = img.Image(width: 80, height: 60);
    img.fill(picture, color: img.ColorRgb8(90, 120, 150));
    picture.exif.exifIfd[0x9003] = '2024:03:04 05:06:07';
    final bytes = img.encodeJpg(picture);
    final oldPath = '${a.path}/IMG_0001.jpg';
    File(oldPath).writeAsBytesSync(bytes);
    final newPath = '${b.path}/IMG_0001.jpg';
    File(newPath).writeAsBytesSync(bytes);

    final store = PhotoStore(File('${root.path}/photo-state.json'));
    final state = store.state(oldPath)
      ..captureTime = '2024:03:04 05:06:07'
      ..edited = true;
    state.fields['place'] = '湖边';
    await store.save();
    await store.load();
    expect(store.state(oldPath).fields['place'], '湖边');

    // 打开 A 时原照片还在，不该出现待关联。
      expect(
        pendingRecords(records: store.photos, currentPaths: {oldPath}).length,
        0);

    // 打开 B：A 里的记录找不到照片，B 里有一张同名同时间的照片。
    final pending =
        pendingRecords(records: store.photos, currentPaths: {newPath});
    expect(pending.length, 1);
    final info = readCapture(newPath);
    expect(info['time'], '2024:03:04 05:06:07');
    final match = findRelinkedPath(
        record: pending.single, timesByPath: {newPath: info['time']!});
    expect(match, newPath);
    expect(store.relink(pending.single.oldPath, match!), isTrue);
    expect(store.state(newPath).fields['place'], '湖边');
    expect(store.state(newPath).edited, isTrue);
    await store.save();

    // 再接一次不会重复，也不该再有待关联。
    final reloaded = PhotoStore(File('${root.path}/photo-state.json'));
    await reloaded.load();
    expect(reloaded.photos.keys.toList(), [newPath]);
      expect(
        pendingRecords(records: reloaded.photos, currentPaths: {newPath}).length,
        0);
  });

  test('同名但拍摄时间不同不会接错', () async {
    final root = Directory('build/export-ui-check-0150-relink/e2e2')
      ..createSync(recursive: true);
    final picture = img.Image(width: 40, height: 30);
    img.fill(picture, color: img.ColorRgb8(10, 20, 30));
    picture.exif.exifIfd[0x9003] = '2025:09:09 09:09:09';
    final other = '${root.path}/IMG_0001.jpg';
    File(other).writeAsBytesSync(img.encodeJpg(picture));
    final store = PhotoStore(File('${root.path}/photo-state.json'));
    store.state('${root.path}/old/IMG_0001.jpg').captureTime =
        '2024:03:04 05:06:07';
    final pending =
        pendingRecords(records: store.photos, currentPaths: {other});
    expect(pending.length, 1);
    final match = findRelinkedPath(
        record: pending.single,
        timesByPath: {other: readCapture(other)['time']!});
    expect(match, isNull);
  });
}
