import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/photo_relink.dart';
import 'package:lumacraft/photo_state.dart';

/// 真实文件：两张不同照片，记录各带自己的样式；把两个文件名对调后，
/// 检查记录是否跟着照片内容走。
void main() {
  test('真实文件对调名字后，样式跟照片不跟文件名', () async {
    final root = Directory('build/export-ui-check-0152-swap');
    if (await root.exists()) await root.delete(recursive: true);
    root.createSync(recursive: true);
    final a = File('${root.path}/A.jpg');
    final b = File('${root.path}/B.jpg');
    final red = img.Image(width: 120, height: 90);
    img.fill(red, color: img.ColorRgb8(220, 40, 40));
    red.exif.exifIfd[0x9003] = '2024:01:01 10:00:00';
    final blue = img.Image(width: 120, height: 90);
    img.fill(blue, color: img.ColorRgb8(30, 60, 220));
    blue.exif.exifIfd[0x9003] = '2024:02:02 11:00:00';
    a.writeAsBytesSync(img.encodeJpg(red));
    b.writeAsBytesSync(img.encodeJpg(blue));

    final store = PhotoStore(File('${root.path}/photo-state.json'));
    store.state(a.path)
      ..captureTime = '2024:01:01 10:00:00'
      ..fingerprint = photoFingerprint(a.path)
      ..edited = true;
    store.state(a.path).fields['place'] = '红照片';
    store.state(b.path)
      ..captureTime = '2024:02:02 11:00:00'
      ..fingerprint = photoFingerprint(b.path)
      ..edited = true;
    store.state(b.path).fields['place'] = '蓝照片';
    await store.save();

    final printA = photoFingerprint(a.path);
    final printB = photoFingerprint(b.path);
    expect(printA, isNot(printB));

    // 对调：临时文件交换内容。
    final temp = File('${root.path}/tmp.jpg')
      ..writeAsBytesSync(a.readAsBytesSync());
    a.writeAsBytesSync(b.readAsBytesSync());
    b.writeAsBytesSync(temp.readAsBytesSync());
    temp.deleteSync();

    final prints = {
      a.path: photoFingerprint(a.path),
      b.path: photoFingerprint(b.path),
    };
    expect(prints[a.path], printB);
    expect(prints[b.path], printA);

    final moves =
        followContent(records: store.photos, fingerprintsByPath: prints);
    expect(moves.length, 2, reason: '两张都要跟着照片挪位置');
    expect(applyMoves(store.photos, moves), isTrue);

    // A.jpg 里现在是蓝照片，所以它应该拿到蓝照片的补填信息。
    expect(store.photos[a.path]!.fields['place'], '蓝照片');
    expect(store.photos[b.path]!.fields['place'], '红照片');
    expect(store.photos[a.path]!.captureTime, '2024:02:02 11:00:00');
    expect(store.photos[b.path]!.captureTime, '2024:01:01 10:00:00');
  });
}
