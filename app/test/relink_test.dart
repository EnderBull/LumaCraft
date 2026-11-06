import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/photo_relink.dart';
import 'package:lumacraft/photo_state.dart';

PhotoState _record({String? time, bool edited = false}) => PhotoState()
  ..captureTime = time
  ..edited = edited;

void main() {
  test('只列出当前文件夹里、照片已不在原位的记录', () {
    final records = {
      r'D:\A\gone.jpg': _record(time: '2024:01:01 10:00:00'),
      r'D:\A\here.jpg': _record(),
      r'D:\B\moved.jpg': PhotoState(),
      r'D:\Z\unrelated.jpg': _record(time: '2019:01:01 10:00:00'),
    };
    final pending = pendingRecords(
        records: records,
        currentPaths: {r'D:\A\here.jpg', r'D:\B\gone.jpg', r'D:\B\moved.jpg'});
    expect(pending.length, 1);
    expect(pending.single.fileName, 'gone.jpg');
    expect(pending.single.captureTime, '2024:01:01 10:00:00');
  });

  test('改名后照片已有新记录时，旧记录不再提示关联', () {
    // 用户把 a.jpg 改成 b.jpg：旧记录指向 a.jpg，b.jpg 已经有自己的记录。
    final records = {
      r'D:\照片\a.jpg': _record(time: '2024:01:01 10:00:00'),
      r'D:\照片\b.jpg': _record(time: '2024:01:01 10:00:00', edited: true),
    };
    final pending =
        pendingRecords(records: records, currentPaths: {r'D:\照片\b.jpg'});
    expect(pending, isEmpty);
  });

  test('文件夹里没有能对上的照片时，不提示关联', () {
    final records = {
      r'D:\照片\a.jpg': _record(time: '2024:01:01 10:00:00', edited: true),
    };
    final pending = pendingRecords(
        records: records, currentPaths: {r'D:\照片\完全不同的照片.jpg'});
    expect(pending, isEmpty);
  });

  test('文件名和拍摄时间都相同才自动接回', () {
    final record = PendingRecord(
        r'D:\A\IMG_1.jpg', 'IMG_1.jpg', '2024:05:06 07:08:09',
        edited: true);
    expect(
        findRelinkedPath(record: record, timesByPath: {
          r'D:\B\IMG_1.jpg': '2024:05:06 07:08:09',
          r'D:\B\IMG_2.jpg': '2024:05:06 07:08:09'
        }),
        r'D:\B\IMG_1.jpg');
    // 同名但拍摄时间不同：不接
    expect(
        findRelinkedPath(record: record, timesByPath: {
          r'D:\B\IMG_1.jpg': '2025:01:01 00:00:00'
        }),
        isNull);
    // 时间相同但文件名不同：不接
    expect(
        findRelinkedPath(record: record, timesByPath: {
          r'D:\B\IMG_9.jpg': '2024:05:06 07:08:09'
        }),
        isNull);
    // 没有拍摄时间：交给手动
    expect(
        findRelinkedPath(
            record: PendingRecord(r'D:\A\IMG_1.jpg', 'IMG_1.jpg', null,
                edited: false),
            timesByPath: {r'D:\B\IMG_1.jpg': ''}),
        isNull);
  });

  test('两处同名同时间的光标不猜，留给手动选择', () {
    final record = PendingRecord(
        r'D:\A\IMG_1.jpg', 'IMG_1.jpg', '2024:05:06 07:08:09',
        edited: false);
    expect(
        findRelinkedPath(record: record, timesByPath: {
          r'D:\B\IMG_1.jpg': '2024:05:06 07:08:09',
          r'D:\C\IMG_1.jpg': '2024:05:06 07:08:09'
        }),
        isNull);
  });

  test('接回时不覆盖已有内容，空记录可以被接管', () {
    final store = PhotoStore(File(
        'build/export-ui-check-0150-relink/photo-state.json'));
    store.photos[r'D:\A\old.jpg'] = _record(time: '2024:01:01 00:00:00');
    expect(store.relink(r'D:\A\old.jpg', r'D:\B\new.jpg'), isTrue);
    expect(store.photos.containsKey(r'D:\A\old.jpg'), isFalse);
    expect(store.photos[r'D:\B\new.jpg']!.captureTime, '2024:01:01 00:00:00');

    // 打开文件夹时顺手建的空记录，应该让给带内容的旧记录。
    store.photos[r'D:\B\blank.jpg'] = PhotoState();
    expect(store.relink(r'D:\B\new.jpg', r'D:\B\blank.jpg'), isTrue);
    expect(store.photos[r'D:\B\blank.jpg']!.captureTime, '2024:01:01 00:00:00');

    // 已经有真实内容的记录不能被覆盖。
    final taken = store.photos[r'D:\B\blank.jpg']!;
    store.photos[r'D:\B\other.jpg'] = _record(time: '2023:01:01 00:00:00')
      ..fields['place'] = '湖边';
    store.photos[r'D:\B\move.jpg'] = taken;
    expect(store.relink(r'D:\B\move.jpg', r'D:\B\other.jpg'), isFalse);
    expect(store.photos[r'D:\B\other.jpg']!.fields['place'], '湖边');
  });

  test('改名后可以手动接回，不受文件名和拍摄时间限制', () {
    final store = PhotoStore(File(
        'build/export-ui-check-0150-relink/photo-state.json'));
    store.photos[r'D:\A\IMG_2001.jpg'] = _record(time: '2024:07:08 20:21:22')
      ..fields['place'] = '湖边';
    // 手动接了另一张改过名、拍摄时间也不同的照片：仍然允许。
    store.photos[r'D:\B\改名后的照片.jpg'] = PhotoState();
    expect(store.relink(r'D:\A\IMG_2001.jpg', r'D:\B\改名后的照片.jpg'), isTrue);
    expect(store.photos[r'D:\B\改名后的照片.jpg']!.fields['place'], '湖边');
  });

  test('多张照片按拍摄时间自动配对，同时间有歧义就不配', () {
    final records = [
      const PendingRecord(r'D:\A\a.jpg', 'a.jpg', '2024:01:01 10:00:00',
          edited: false),
      const PendingRecord(r'D:\A\b.jpg', 'b.jpg', '2024:01:01 10:00:01',
          edited: false),
      const PendingRecord(r'D:\A\c.jpg', 'c.jpg', '2024:01:01 10:00:02',
          edited: false),
      const PendingRecord(r'D:\A\d.jpg', 'd.jpg', '2024:01:01 10:00:03',
          edited: false),
    ];
    final pairs = suggestPairs(records: records, timesByPath: {
      r'D:\B\x.jpg': '2024:01:01 10:00:00',
      r'D:\B\y.jpg': '2024:01:01 10:00:01',
      // 这两张时间相同：b 之外没有别的记录用这个时间，但照片侧有两张，放弃
      r'D:\B\z.jpg': '2024:01:01 10:00:02',
      r'D:\B\w.jpg': '2024:01:01 10:00:02',
      r'D:\B\v.jpg': '2024:01:01 10:00:03',
      r'D:\B\u.jpg': '2024:01:01 10:00:03',
    });
    // a 唯一同时间，b 唯一同时间；c、d 各有两张候选，不猜。
    expect(pairs.length, 2);
    expect(pairs[0].$1.fileName, 'a.jpg');
    expect(pairs[0].$2, r'D:\B\x.jpg');
    expect(pairs[1].$1.fileName, 'b.jpg');
    expect(pairs[1].$2, r'D:\B\y.jpg');
  });

  test('两条记录时间相同也不会自动配', () {
    const same = '2024:01:01 10:00:00';
    final records = [
      const PendingRecord(r'D:\A\a.jpg', 'a.jpg', same, edited: false),
      const PendingRecord(r'D:\A\b.jpg', 'b.jpg', same, edited: false),
    ];
    final pairs = suggestPairs(
        records: records, timesByPath: {r'D:\B\x.jpg': same});
    expect(pairs, isEmpty);
  });

  test('对调两个文件名后，记录跟着照片内容走，预设不会跟着对调', () {
    final store = PhotoStore(File(
        'build/export-ui-check-0150-relink/photo-state.json'));
    // 两张照片，各用不同样式。
    store.photos[r'D:\照片\A.jpg'] = _record(time: '2024:01:01 10:00:00')
      ..fields['place'] = '湖边'
      ..fingerprint = 'f-A';
    store.photos[r'D:\照片\B.jpg'] = _record(time: '2024:02:02 11:00:00')
      ..fields['place'] = '山上'
      ..fingerprint = 'f-B';
    // 用户把两个文件的名字对调了：现在 A.jpg 里是 B 的内容。
    final prints = {
      r'D:\照片\A.jpg': 'f-B',
      r'D:\照片\B.jpg': 'f-A',
    };
    final moves =
        followContent(records: store.photos, fingerprintsByPath: prints);
    expect(moves.length, 2);
    expect(applyMoves(store.photos, moves), isTrue);
    expect(store.photos[r'D:\照片\A.jpg']!.fields['place'], '山上');
    expect(store.photos[r'D:\照片\B.jpg']!.fields['place'], '湖边');
  });

  test('指纹对不上时不动记录，交给手动选择', () {
    final store = PhotoStore(File(
        'build/export-ui-check-0150-relink/photo-state.json'));
    store.photos[r'D:\照片\A.jpg'] = _record(time: '2024:01:01 10:00:00')
      ..fingerprint = 'f-A';
    final moves = followContent(
        records: store.photos,
        fingerprintsByPath: {r'D:\照片\A.jpg': 'f-other'});
    expect(moves, isEmpty);
  });

  test('两张照片内容完全相同（同指纹）时不自动挪动', () {
    final store = PhotoStore(File(
        'build/export-ui-check-0150-relink/photo-state.json'));
    store.photos[r'D:\照片\A.jpg'] = _record()..fingerprint = 'same';
    final moves = followContent(records: store.photos, fingerprintsByPath: {
      r'D:\照片\X.jpg': 'same',
      r'D:\照片\Y.jpg': 'same',
    });
    expect(moves, isEmpty);
  });

  test('目标文件已有自己的内容记录时不覆盖', () {
    final store = PhotoStore(File(
        'build/export-ui-check-0150-relink/photo-state.json'));
    store.photos[r'D:\照片\A.jpg'] = _record()..fingerprint = 'f-A';
    store.photos[r'D:\照片\B.jpg'] = _record()..fields['place'] = '别处';
    final moves = followContent(
        records: store.photos,
        fingerprintsByPath: {r'D:\照片\B.jpg': 'f-A'});
    expect(moves, isEmpty);
  });

  test('拍摄时间会随记录保存和读回', () {
    final state = _record(time: '2024:05:06 07:08:09', edited: true);
    final again = PhotoState.fromJson(state.toJson());
    expect(again.captureTime, '2024:05:06 07:08:09');
    expect(again.edited, isTrue);
    final empty = PhotoState.fromJson(PhotoState().toJson());
    expect(empty.captureTime, isNull);
  });

  test('指纹随文件内容变化，同内容得到同指纹', () async {
    final dir = Directory('build/export-ui-check-0150-relink/print')
      ..createSync(recursive: true);
    final one = File('${dir.path}/one.jpg')
      ..writeAsBytesSync(List<int>.generate(5000, (i) => i % 251));
    final same = File('${dir.path}/same.jpg')
      ..writeAsBytesSync(one.readAsBytesSync());
    final other = File('${dir.path}/other.jpg')
      ..writeAsBytesSync(List<int>.generate(5000, (i) => (i + 7) % 251));
    expect(photoFingerprint(one.path), photoFingerprint(same.path));
    expect(photoFingerprint(one.path), isNot(photoFingerprint(other.path)));
    expect(photoFingerprint(one.path), contains('-'));
    final state = PhotoState()..fingerprint = photoFingerprint(one.path);
    expect(PhotoState.fromJson(state.toJson()).fingerprint,
        state.fingerprint);
  });
}
