import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'style_document.dart';
import 'shape_style.dart';
import '../fonts/font_catalog.dart';
import 'preset_store.dart';

class SharedPreset {
  final StyleDocument style;
  final String folder;
  SharedPreset(this.style, {this.folder = ''});
}

const lmpLimit = 64 * 1024 * 1024;
const _features = [
  'text',
  'groups',
  'palette',
  'image',
  'gradient',
  'blur',
  'film',
  'shadow',
  'radialGradient',
  'bundledFontsV1',
  'adaptiveLayout',
  'shapeV1'
];
String encodeLmp(List<SharedPreset> presets) {
  if (presets.isEmpty || presets.length > 200)
    throw const FormatException('一次可分享 1～200 个预设');
  final data = jsonEncode({
    'format': 'LumaCraftPreset',
    'version': 1,
    'requires': _features
        .where((f) => f == 'bundledFontsV1'
            ? presets.any((p) =>
                p.style.nodes.any((n) => !legacyFontNames.containsKey(n.font)))
            : f == 'shapeV1'
                ? presets.any((p) => p.style.nodes.any((n) => n.type == 'shape'))
                : f == 'adaptiveLayout'
                ? presets
                    .any((p) => p.style.adaptive || p.style.layouts.isNotEmpty)
                : f != 'radialGradient' ||
                    presets.any((p) =>
                        p.style.fill.mode == 'gradient' &&
                        p.style.fill.gradientType == 'radial'))
        .toList(),
    'presets': [
      for (final p in presets)
        {'folder': p.folder, 'style': _exportStyle(p.style)}
    ]
  });
  if (utf8.encode(data).length > lmpLimit)
    throw const FormatException('分享文件超过 64 MB，请减少预设数量');
  // Exports obey the same contract as imports.
  decodeLmp(data);
  return data;
}

Future<List<SharedPreset>> readLmp(File file) async {
  if (await file.length() > lmpLimit)
    throw const FormatException('预设文件超过 64 MB');
  final presets = await compute(decodeLmp, await file.readAsString());
  await validateLmpAssets(presets);
  return presets;
}

List<SharedPreset> decodeLmp(String data) {
  try {
    if (utf8.encode(data).length > lmpLimit)
      throw const FormatException('预设文件超过 64 MB');
    final j = jsonDecode(data);
    if (j is! Map || j['format'] != 'LumaCraftPreset' || j['version'] != 1)
      throw const FormatException('不是支持的 LumaCraft 预设文件，或版本过新');
    if (j['requires'] is! List ||
        (j['requires'] as List).any((v) => !_features.contains(v)))
      throw const FormatException('预设包含当前版本不支持的功能');
    final list = j['presets'];
    if (list is! List || list.isEmpty || list.length > 200)
      throw const FormatException('预设数量无效');
    return [for (final item in list) _readPreset(item)];
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('预设文件结构损坏');
  }
}

SharedPreset _readPreset(dynamic item) {
  if (item is! Map || item['style'] is! Map)
    throw const FormatException('缺少样式内容');
  final j = Map<String, dynamic>.from(item['style']);
  if (j['version'] != 1) throw const FormatException('不支持的样式版本');
  final name = j['name'];
  if (name is! String || name.trim().isEmpty || name.length > 200)
    throw const FormatException('预设名称无效');
  if (item['folder'] != null &&
      (item['folder'] is! String || (item['folder'] as String).length > 100))
    throw const FormatException('分组名称无效');
  void numbers(dynamic v, [int depth = 0]) {
    if (depth > 32) throw const FormatException('参数结构过深');
    if (v is num && !v.isFinite) throw const FormatException('参数不是有效数值');
    if (v is Map) {
      for (final value in v.values) {
        numbers(value, depth + 1);
      }
    }
    if (v is List) {
      for (final value in v) {
        numbers(value, depth + 1);
      }
    }
  }

  numbers(j);
  final borders = j['borders'];
  if (borders is! Map ||
      ['top', 'bottom', 'left', 'right']
          .any((k) => borders[k] is! num || borders[k] < 0 || borders[k] > 40))
    throw const FormatException('边框参数无效');
  final nodes = j['nodes'], groups = j['groups'] ?? [], order = j['order'];
  if (nodes is! List ||
      nodes.length > 500 ||
      groups is! List ||
      groups.length > 200 ||
      order is! List) throw const FormatException('图层数量或结构无效');
  // 已移除的“作者签名”与自由文字一致：旧 .lmp 导入时自动当作自由文字。
  for (final n in nodes) {
    if (n is Map && n['type'] == 'author') n['type'] = 'text';
  }
  final ids = <String>{};
  for (final obj in [...nodes, ...groups]) {
    if (obj is! Map || obj['id'] is! String || !ids.add(obj['id']))
      throw const FormatException('图层标识无效或重复');
  }
  for (final n in nodes) {
    if (!componentNames.containsKey(n['type']) ||
        !['bottom', 'photo', 'canvas'].contains(n['anchor']) ||
        !isKnownArtworkFont(n['font']?.toString() ?? '') ||
        !['left', 'center', 'right'].contains(n['align']))
      throw const FormatException('包含不支持的组件属性');
    for (final key in ['x', 'y', 'fontSize', 'spacing', 'opacity']) {
      if (n[key] is! num) throw const FormatException('组件参数无效');
    }
    if (n['fontSize'] <= 0 || n['opacity'] < 0 || n['opacity'] > 100)
      throw const FormatException('组件尺寸或不透明度无效');
    if (n['text'] is! String || (n['text'] as String).length > 100000)
      throw const FormatException('文字内容过长或无效');
    if (n['type'] == 'image') {
      final image = n['image'];
      if (image is! Map ||
          image['data'] is! String ||
          (image['data'] as String).length > 24 * 1024 * 1024)
        throw const FormatException('图片素材无效或过大');
      final bytes = base64Decode(image['data']);
      if (bytes.length < 8 ||
          !(bytes[0] == 0x89 &&
                  bytes[1] == 0x50 &&
                  bytes[2] == 0x4e &&
                  bytes[3] == 0x47 ||
              bytes[0] == 0xff && bytes[1] == 0xd8))
        throw const FormatException('图片素材不是 PNG/JPG');
      if (image['width'] is! num ||
          image['ratio'] is! num ||
          image['width'] < 4 ||
          image['width'] > 2000 ||
          image['ratio'] <= 0) throw const FormatException('图片尺寸无效');
      // Only the filename is transferable, never a local file path.
      image['filename'] =
          (image['filename']?.toString() ?? '').split(RegExp(r'[/\\]')).last;
    }
  }
  final children = <String, List<String>>{};
  for (final g in groups) {
    if (g['children'] is! List ||
        (g['children'] as List).any((id) => id is! String || !ids.contains(id)))
      throw const FormatException('分组引用无效');
    children[g['id']] = List<String>.from(g['children']);
  }
  final visited = <String>{};
  void walk(String id, int depth, Set<String> path) {
    if (depth > 20 || path.contains(id) || !visited.add(id))
      throw const FormatException('图层分组循环或重复引用');
    for (final child in children[id] ?? <String>[]) {
      walk(child, depth + 1, {...path, id});
    }
  }

  for (final id in order) {
    if (id is! String || !ids.contains(id))
      throw const FormatException('图层顺序引用无效');
    walk(id, 0, {});
  }
  if (visited.length != ids.length) throw const FormatException('存在未归属的图层');
  if (j['fill'] is Map &&
      !['solid', 'gradient', 'blur'].contains(j['fill']['mode']))
    throw const FormatException('不支持的背景类型');
  if (j['film'] is Map &&
      !['vertical', 'horizontal'].contains(j['film']['orientation']))
    throw const FormatException('不支持的胶片排列');
  if (j['fill'] is Map &&
      j['fill']['gradientType'] != null &&
      !['linear', 'radial'].contains(j['fill']['gradientType']))
    throw const FormatException('不支持的渐变类型');
  for (final n in nodes.where((n) => n['type'] == 'palette')) {
    final p = n['palette'];
    if (p is! Map ||
        !['blocks', 'strip'].contains(p['mode']) ||
        !['circle', 'roundedRect', 'hexagon'].contains(p['shape']))
      throw const FormatException('不支持的色卡类型');
  }
  for (final n in nodes.where((n) => n['type'] == 'shape')) {
    final s = n['shape'];
    if (s is! Map || !shapeKindNames.containsKey(s['kind']))
      throw const FormatException('不支持的形状类型');
  }
  final document = StyleDocument.fromJson(j)..name = name.trim();
  _validateLayouts(j, document);
  return SharedPreset(document, folder: (item['folder'] ?? '').trim());
}

void _validateLayouts(Map<String, dynamic> j, StyleDocument document) {
  if (j['adaptive'] != null && j['adaptive'] is! bool ||
      j['suitability'] != null &&
          !StyleDocument.suitabilityNames.containsKey(j['suitability']))
    throw const FormatException('布局适配参数无效');
  final layouts = j['layouts'] ?? {};
  if (layouts is! Map || layouts.length > 2)
    throw const FormatException('布局配置无效');
  for (final entry in layouts.entries) {
    final layout = entry.value;
    if (!['landscape', 'portrait'].contains(entry.key) ||
        layout is! Map ||
        layout.keys.any((k) =>
            !['borders', 'linked', 'nodes', 'groups', '_copied'].contains(k)))
      throw const FormatException('包含不支持的布局属性');
    if (layout['linked'] != null && layout['linked'] is! bool ||
        layout['_copied'] != null && layout['_copied'] is! bool)
      throw const FormatException('布局开关无效');
    final borders = layout['borders'] ?? {};
    if (borders is! Map ||
        borders.entries.any((e) =>
            !['top', 'bottom', 'left', 'right'].contains(e.key) ||
            e.value is! num ||
            e.value < 0 ||
            e.value > 40)) throw const FormatException('布局边框无效');
    final nodes = layout['nodes'] ?? {}, groups = layout['groups'] ?? {};
    if (nodes is! Map ||
        groups is! Map ||
        nodes.length > 500 ||
        groups.length > 200) throw const FormatException('布局组件无效');
    for (final e in groups.entries) {
      if (document.group(e.key) == null || e.value is! bool)
        throw const FormatException('布局分组无效');
    }
    for (final e in nodes.entries) {
      final node = document.node(e.key), patch = e.value;
      if (node == null ||
          patch is! Map ||
          patch.keys.any((k) => !StyleDocument.nodeLayout(node).containsKey(k)))
        throw const FormatException('布局引用或属性无效');
      for (final v in patch.entries) {
        if (['x', 'y', 'fontSize', 'spacing'].contains(v.key) &&
                v.value is! num ||
            v.key == 'visible' && v.value is! bool)
          throw const FormatException('布局数值无效');
        if (v.key == 'image' || v.key == 'palette' || v.key == 'shape') {
          final allowed = (StyleDocument.nodeLayout(node)[v.key] as Map).keys;
          if (v.value is! Map ||
              (v.value as Map).entries.any((p) =>
                  !allowed.contains(p.key) || p.value is! num || p.value < 0))
            throw const FormatException('布局尺寸无效');
          final dimensions = v.value as Map;
          final Map<String, (num, num)> limits = v.key == 'image'
              ? {'width': (4, 2000)}
              : v.key == 'shape'
              ? shapeLimits
              : {
                  'size': (4, 300),
                  'height': (4, 300),
                  'gap': (0, 100),
                  'radius': (0, 150),
                  'scale': (.1, 6)
                };
          for (final p in dimensions.entries) {
            final limit = limits[p.key]!;
            if (p.value < limit.$1 || p.value > limit.$2)
              throw const FormatException('布局尺寸超出范围');
          }
        }
      }
    }
    // Validate the effective layout with exactly the same rules as the base.
    final flat = document.forRatio(entry.key == 'landscape' ? 1.5 : 2 / 3);
    // Disabled layouts must still be checked before a later enable action.
    if (!flat.adaptive) {
      flat.setAdaptive(true);
      flat.switchLayout(entry.key);
    }
    flat.editingLayout = 'general';
    flat.adaptive = false;
    flat.layouts.clear();
    _readPreset({'style': flat.toJson()..remove('layouts')});
  }
}

String uniquePresetName(String name, Iterable<String> names) {
  final taken = names.toSet();
  final base = name.length > 200 ? name.substring(0, 200) : name;
  if (!taken.contains(base)) return base;
  for (var i = 2;; i++) {
    final suffix = ' ($i)';
    final prefix = base.length > 200 - suffix.length
        ? base.substring(0, 200 - suffix.length)
        : base;
    final next = '$prefix$suffix';
    if (!taken.contains(next)) return next;
  }
}

class PresetImportResult {
  final List<UserPreset> presets;
  final List<PresetFolder> folders;
  final int count;
  PresetImportResult(this.presets, this.folders, this.count);
}

PresetImportResult mergeLmp(
    PresetStore store, List<SharedPreset> incoming, Map<int, String> choices) {
  final presets = [...store.presets], folders = [...store.folders];
  var count = 0;
  for (var i = 0; i < incoming.length; i++) {
    final p = incoming[i], choice = choices[i] ?? 'copy';
    if (choice == 'skip') continue;
    final match = presets.indexWhere((v) => v.style.name == p.style.name);
    if (choice == 'replace' && match >= 0) {
      final old = presets[match];
      presets[match] = UserPreset(old.id, p.style.copy(), folder: old.folder);
    } else {
      var folder = '';
      if (p.folder.isNotEmpty) {
        final matches = folders.where((f) => f.name == p.folder);
        if (matches.isNotEmpty) {
          folder = matches.first.id;
        } else {
          folder = newObjectId();
          folders.add(PresetFolder(folder, p.folder));
        }
      }
      final style = p.style.copy()
        ..name =
            uniquePresetName(p.style.name, presets.map((v) => v.style.name));
      presets.add(UserPreset(newObjectId(), style, folder: folder));
    }
    count++;
  }
  return PresetImportResult(presets, folders, count);
}

Map<String, dynamic> _exportStyle(StyleDocument style) {
  final j = style.toJson();
  for (final n in j['nodes']) {
    if (n['type'] != 'text') n['text'] = '';
    if (n['type'] == 'image') {
      final image = n['image'];
      image['filename'] =
          (image['filename'] ?? '').toString().split(RegExp(r'[/\\]')).last;
      image['data'] =
          base64Encode(_withoutMetadata(base64Decode(image['data'])));
    }
  }
  return j;
}

Uint8List _withoutMetadata(Uint8List bytes) {
  final out = BytesBuilder(copy: false);
  if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50) {
    out.add(bytes.sublist(0, 8));
    var offset = 8;
    while (offset + 12 <= bytes.length) {
      final length =
          ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
      final end = offset + 12 + length;
      if (end > bytes.length) throw const FormatException('PNG 素材损坏');
      final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
      if (!['eXIf', 'tEXt', 'zTXt', 'iTXt'].contains(type))
        out.add(bytes.sublist(offset, end));
      offset = end;
    }
  } else if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xd8) {
    out.add(bytes.sublist(0, 2));
    var offset = 2;
    while (offset + 1 < bytes.length) {
      if (bytes[offset] != 0xff) throw const FormatException('JPG 素材损坏');
      final marker = bytes[offset + 1];
      if (marker == 0xda || marker == 0xd9) {
        out.add(bytes.sublist(offset));
        break;
      }
      if (offset + 4 > bytes.length) throw const FormatException('JPG 素材损坏');
      final length = (bytes[offset + 2] << 8) | bytes[offset + 3],
          end = offset + 2 + length;
      if (length < 2 || end > bytes.length)
        throw const FormatException('JPG 素材损坏');
      if (![0xe1, 0xed, 0xfe].contains(marker))
        out.add(bytes.sublist(offset, end));
      offset = end;
    }
  } else {
    throw const FormatException('素材不是 PNG/JPG');
  }
  return out.takeBytes();
}

Future<void> validateLmpAssets(List<SharedPreset> presets) async {
  final checked = <String>{};
  for (final p in presets) {
    for (final n in p.style.nodes.where((n) => n.type == 'image')) {
      if (!checked.add(n.image.data)) continue;
      final buffer =
          await ui.ImmutableBuffer.fromUint8List(base64Decode(n.image.data));
      ui.ImageDescriptor? descriptor;
      ui.Codec? codec;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (descriptor.width > 2048 || descriptor.height > 2048)
          throw const FormatException('素材最长边超过 2048 px');
        codec = await descriptor.instantiateCodec();
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec?.dispose();
        descriptor?.dispose();
        buffer.dispose();
      }
    }
  }
}
