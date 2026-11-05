import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/builtin_library.dart';
import 'package:lumacraft/editor/preset_package.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const phoneIds = [
    'phone-bar-white',
    'phone-bar-black',
    'phone-overlay',
    'phone-center',
    'phone-signature',
    'phone-minimal'
  ];

  test('手机经典 6 款：命名不含品牌、横竖适配、只带占位图不带品牌 Logo', () async {
    final library = BuiltinLibrary.decode(
        await File('assets/builtins/library.json').readAsString());
    final phone = library.entries.where((e) => e.folder == 'phone').toList();
    expect(phone.map((e) => e.id).toList(), phoneIds);
    expect(phone.map((e) => e.style.name).toList(), [
      '底栏参数条·白',
      '底栏参数条·黑',
      '透明叠加·左下角',
      '居中双行',
      '签名边框',
      '极简单行'
    ]);
    const brands = [
      '小米', '徕卡', '华为', '荣耀', 'OPPO', 'oppo', 'vivo', '蔡司', '哈苏',
      '苹果', 'iPhone', 'Apple', 'Leica', 'ZEISS', 'Zeiss', 'Hasselblad',
      'Xiaomi', 'Huawei', 'Samsung', '三星', '一加', 'OnePlus'
    ];
    for (final e in phone) {
      final s = e.style;
      expect(s.adaptive, true, reason: e.id);
      expect(s.layouts.keys.toSet(), {'landscape', 'portrait'}, reason: e.id);
      final words = [s.name, ...s.nodes.map((n) => '${n.name}${n.text}')];
      for (final w in words) {
        for (final b in brands) {
          expect(w.contains(b), false, reason: '${e.id} 含品牌名 $b：$w');
        }
      }
      for (final n in s.nodes.where((n) => n.type == 'image')) {
        expect(n.image.filename, 'logo-placeholder.png', reason: e.id);
        expect(n.image.ratio, 1);
        final bytes = base64Decode(n.image.data);
        expect(bytes.length, lessThan(20 * 1024), reason: '占位图应很小');
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect([frame.image.width, frame.image.height], [256, 256]);
        frame.image.dispose();
        codec.dispose();
      }
    }
    // 含 Logo 位的 4 款都带占位图；居中双行与签名边框没有 Logo 位。
    int logos(String id) => phone
        .firstWhere((e) => e.id == id)
        .style
        .nodes
        .where((n) => n.type == 'image')
        .length;
    expect([for (final id in phoneIds) logos(id)], [1, 1, 1, 0, 0, 1]);
    // 分隔线必须是形状组件，而不是字符。
    for (final id in ['phone-bar-white', 'phone-bar-black', 'phone-center']) {
      final rule = phone
          .firstWhere((e) => e.id == id)
          .style
          .nodes
          .firstWhere((n) => n.id == 'rule');
      expect(rule.type, 'shape', reason: id);
      expect(rule.shape.kind, 'line');
    }
    // 竖图底边框比横图高，且已单独覆盖。
    final white = phone.first.style;
    expect(white.forRatio(1.5).borders['bottom'], 12.8);
    expect(white.forRatio(2 / 3).borders['bottom'], 15);
  });

  test('手机经典可作为 .lmp 分享并重新导入，包含 shapeV1 与素材校验', () async {
    final library = BuiltinLibrary.decode(
        await File('assets/builtins/library.json').readAsString());
    final phone = library.entries.where((e) => e.folder == 'phone').toList();
    final text = encodeLmp([for (final e in phone) SharedPreset(e.style)]);
    final json = jsonDecode(text) as Map;
    expect(json['requires'], contains('shapeV1'));
    final back = decodeLmp(text);
    await validateLmpAssets(back);
    expect(back.map((p) => p.style.name).toList(),
        phone.map((e) => e.style.name).toList());
  });
}
