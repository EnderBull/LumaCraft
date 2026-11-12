import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumacraft/editor/image_mark.dart';
import 'package:lumacraft/editor/preset_package.dart';
import 'package:lumacraft/editor/style_document.dart';
import 'package:lumacraft/export/export_options.dart';
import 'package:lumacraft/export/photo_export.dart';
import 'package:lumacraft/photo_state.dart';
import 'package:lumacraft/render.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('可选预设扩展跟随复制和另存，不兼容功能仍被拒绝', () async {
    final style = StyleDocument.template();
    final pixels = img.Image(width: 8, height: 4);
    img.fill(pixels, color: img.ColorRgb8(90, 120, 180));
    final logo = StyleNode(
      type: 'image',
      image: ImageMark(
        data: base64Encode(img.encodePng(pixels)),
        ratio: 2,
        filename: 'p2-logo.png',
      ),
    );
    final group = StyleGroup(children: [logo.id]);
    style.nodes.add(logo);
    style.groups.add(group);
    style.order.add(group.id);
    style.adaptive = true;
    style.switchLayout('portrait');
    style.borders['left'] = 12;
    style.switchLayout('landscape');
    style.borders['left'] = 4;
    style.switchLayout('general');
    final package = jsonDecode(encodeLmp([SharedPreset(style)])) as Map;
    final raw = package['presets'][0]['style'] as Map;
    raw['extensions'] = {
      'p2.sample': [
        1,
        {'mode': 'metadata'}
      ]
    };
    raw['nodes'].last['extensions'] = {'p2.layer': 'keep'};
    raw['groups'].last['extensions'] = {'p2.group': true};

    final read = decodeLmp(jsonEncode(package)).single;
    final edited = read.style.copy()..name = 'P2 往返';
    edited.nodes.last.name = '图片标识';
    final saved = encodeLmp([SharedPreset(edited, folder: read.folder)]);
    final after = decodeLmp(saved).single.style.toJson();
    expect(after['extensions'], raw['extensions']);
    expect(after['nodes'].last['extensions'], {'p2.layer': 'keep'});
    expect(after['groups'].last['extensions'], {'p2.group': true});
    expect(after['nodes'].last['name'], '图片标识');
    expect(after['layouts']['portrait']['borders']['left'], 12);
    expect(after['layouts']['landscape']['borders']['left'], 4);
    expect(after['nodes'].last['image']['data'], isNotEmpty);
    await validateLmpAssets([SharedPreset(edited)]);
    (package['requires'] as List).add('futureRequiredFeature');
    expect(() => decodeLmp(jsonEncode(package)), throwsFormatException);

    final androidSaved = Platform.environment['LUMACRAFT_P2_ANDROID_PRESET'];
    if (androidSaved != null) {
      final returned = (await readLmp(File(androidSaved))).single.style;
      final json = returned.toJson();
      expect(json['extensions'], raw['extensions']);
      expect(json['nodes'].last['extensions'], {'p2.layer': 'keep'});
      expect(json['groups'].last['extensions'], {'p2.group': true});
      expect(json['layouts']['portrait']['borders']['left'], 12);
      expect(json['layouts']['landscape']['borders']['left'], 4);
      expect(json['nodes'].last['image']['data'], isNotEmpty);
    }

    final fixtureDirectory = Platform.environment['LUMACRAFT_P2_FIXTURES'];
    if (fixtureDirectory != null) {
      final dir = await Directory(fixtureDirectory).create(recursive: true);
      await File('${dir.path}/P2-roundtrip.lmp').writeAsString(saved);
      final sample = Platform.environment['LUMACRAFT_P2_COMPARE_PHOTO'];
      if (sample != null) {
        final style =
            (await readLmp(File('${dir.path}/P2-roundtrip.lmp'))).single.style;
        final options = ExportOptions()..format = 'png';
        final bytes = await encodeWindowsExport(
          sourcePath: sample,
          style: style,
          film: false,
          fields: readCapture(sample),
          options: options,
          managed: await openForExport(sample, options),
        );
        await File('${dir.path}/P2-windows-reference.png').writeAsBytes(bytes);
      }
      await File('${dir.path}/P2-unsupported.lmp')
          .writeAsString(jsonEncode(package));
    }
  });
}
