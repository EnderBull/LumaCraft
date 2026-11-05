import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../lib/render.dart';
import '../../lib/photo_state.dart';

Future<void> main() async {
  checkInteractions();
  final folder = Directory('output')..createSync(recursive: true);
  final source = File('${folder.path}/input.jpg');
  final pixels = img.Image(width: 2400, height: 1600);
  img.fill(pixels, color: img.ColorRgb8(30, 130, 180));
  pixels.exif.imageIfd[0x0110] = "Core Camera";
  pixels.exif.exifIfd[0x8827] = img.IfdValueShort(400);
  pixels.exif.exifIfd[0x9003] = "2026:10:18 06:42:00";
  pixels.exif.exifIfd[0xa434] = "Test Lens";
  pixels.exif.exifIfd[0x829a] = img.IfdValueRational(1, 250);
  pixels.exif.exifIfd[0x829d] = img.IfdValueRational(28, 10);
  pixels.exif.exifIfd[0x920a] = img.IfdValueRational(35, 1);
  pixels.exif.gpsIfd[1] = img.IfdValueAscii("N");
  source.writeAsBytesSync(img.encodeJpg(pixels));
  final previewTime = Stopwatch()..start();
  render((source.path, false, 1200, false));
  print("preview ${previewTime.elapsedMilliseconds}ms");
  for (final film in [false, true]) {
    final timer = Stopwatch()..start();
    final bytes = render((source.path, film, 0, film));
    print("export film=$film ${timer.elapsedMilliseconds}ms");
    final result = File('${folder.path}/${film ? "film.png" : "gallery.jpg"}');
    result.writeAsBytesSync(bytes);
    final reopened = img.decodeImage(result.readAsBytesSync());
    if (reopened == null ||
        reopened.width <= 2400 ||
        reopened.height <= 1600 ||
        reopened.getPixel(reopened.width ~/ 2, reopened.height ~/ 2).b < 160) {
      throw StateError('输出尺寸或照片内容错误');
    }
    final disk = result.readAsBytesSync();
    final meta = film
        ? img.ExifData.fromInputBuffer(img.InputBuffer(Uint8List.sublistView(
            disk, 41, 41 + ByteData.sublistView(disk).getUint32(33))))
        : img.decodeJpgExif(disk)!;
    for (final tag in [0x8827, 0x9003, 0xa434, 0x829a, 0x829d, 0x920a]) {
      if (meta.exifIfd[tag]?.toString() !=
              pixels.exif.exifIfd[tag]?.toString() ||
          meta.exifIfd[tag] == null) throw StateError('EXIF tag $tag');
    }
    if (meta.imageIfd[0x0110].toString() != 'Core Camera' ||
        !meta.gpsIfd.isEmpty ||
        meta.exifIfd[0xa002]?.toInt() != reopened.width ||
        meta.imageIfd.orientation != 1) {
      throw StateError('EXIF 尺寸、方向、相机或 GPS 错误');
    }
    print('${result.path} ${reopened.width}×${reopened.height}');
  }
  final original = readCapture(source.path);
  final store = PhotoStore(File('output/stage2-state.json'));
  final first = store.state(source.path)
    ..film = false
    ..edited = true;
  final second = store.state('second.jpg')
    ..film = true
    ..edited = true;
  first.supplement(
      original, {'camera': 'should not replace', 'place': '杭州'}, false);
  if (first.fields.containsKey('camera') || first.fields['place'] != '杭州') {
    throw StateError('默认补填覆盖了原始字段');
  }
  second.supplement({}, {'camera': 'Manual Camera', 'iso': '200'}, false);
  await store.save();
  final restored = PhotoStore(store.file);
  await restored.load();
  if (!restored.state('second.jpg').film ||
      restored.state(source.path).fields['place'] != '杭州' ||
      !restored.state(source.path).edited) throw StateError('本地恢复失败');
  final output =
      renderPhoto((source.path, second.film, 0, false, second.fields));
  final result = File('output/stage2-manual.jpg')..writeAsBytesSync(output);
  final meta = img.decodeJpgExif(result.readAsBytesSync())!;
  if (meta.imageIfd[0x0110].toString() != 'Manual Camera' ||
      meta.exifIfd[0x8827]?.toInt() != 200) throw StateError('补填信息未导出');
  first.supplement(original, {'camera': 'Override Camera'}, true);
  if (first.fields['camera'] != 'Override Camera' ||
      validateInfo('iso', 'abc') == null ||
      validateInfo('time', '2026:02:30 12:00:00') == null)
    throw StateError('覆盖或输入校验失败');
  try {
    renderPhoto(('output/missing.jpg', false, 0, false, {}));
    throw StateError('失败未抛出');
  } on FileSystemException {
    print('单张失败可捕获，其他文件已导出');
  }
  print('第二阶段核心流程通过：逐张预设、默认补缺、主动覆盖、本地恢复、信息写入导出');
}

void checkInteractions() {
  final files = ['a', 'b', 'c', 'd', 'e'];
  final selection = PhotoSelection()..reset(files);
  selection.click(files, 1);
  selection.click(files, 3, control: true);
  if (!setEquals(selection.paths, {'b', 'd'}) || selection.current != 3)
    throw StateError('Ctrl 增选失败');
  selection.click(files, 3, control: true);
  if (!setEquals(selection.paths, {'b'}) || selection.current != 1)
    throw StateError('Ctrl 取消后预览范围错误');
  selection.click(files, 4, shift: true);
  if (!setEquals(selection.paths, {'d', 'e'})) throw StateError('Shift 锚点错误');
  selection.click(files, 0);
  if (!setEquals(selection.paths, {'a'}) || selection.current != 0)
    throw StateError('普通点击未清除旧选择');
  selection.click(files, 2, shift: true);
  if (!setEquals(selection.paths, {'a', 'b', 'c'}))
    throw StateError('连续范围选择错误');
  selection.click(files, 4, control: true, shift: true);
  if (selection.paths.length != 5) throw StateError('Ctrl+Shift 追加范围失败');
  selection.click(files, 1, shift: true);
  if (!setEquals(selection.paths, {'a', 'b'})) throw StateError('Shift 缩小范围错误');
  final photos = [
    {'camera': 'A', 'lens': 'L'},
    {'camera': 'B'},
    <String, String>{}
  ];
  final camera = InfoSummary(photos, 'camera');
  final lens = InfoSummary(photos, 'lens');
  final missing = InfoSummary(photos, 'iso');
  if (camera.initial != '' ||
      camera.values.length != 2 ||
      camera.present != 2 ||
      camera.missing != 1 ||
      lens.initial != 'L' ||
      lens.missing != 2 ||
      missing.hint != '缺失') throw StateError('已有、不同值或缺失统计错误');
  print('选择方式及补填字段汇总检查通过');
}

bool setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
