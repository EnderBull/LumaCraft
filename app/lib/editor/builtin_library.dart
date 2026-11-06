import 'dart:convert';
import 'style_document.dart';
import 'preset_package.dart';

const bundledBuiltinAsset = String.fromEnvironment('LUMACRAFT_BUILTIN_ASSET',
    defaultValue: 'assets/builtins/library.json');

const builtinAuthoring =
    bool.fromEnvironment('LUMACRAFT_AUTHORING', defaultValue: false);

class BuiltinFolder {
  final String id, name;
  const BuiltinFolder(this.id, this.name);
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class BuiltinEntry {
  final String id, folder;
  final StyleDocument style;
  BuiltinEntry(this.id, this.style, {this.folder = 'simple'});
  Map<String, dynamic> toJson() =>
      {'id': id, 'folder': folder, 'style': style.toJson()};
}

class BuiltinLibrary {
  final List<BuiltinFolder> folders;
  final List<BuiltinEntry> entries;
  BuiltinLibrary(this.folders, this.entries);
  factory BuiltinLibrary.seed() => BuiltinLibrary([
        const BuiltinFolder('simple', '简约'),
        const BuiltinFolder('phone', '手机水印')
      ], [
        BuiltinEntry('gallery', StyleDocument.template()),
        BuiltinEntry('film', StyleDocument.template(true))
      ]);
  String encode() => const JsonEncoder.withIndent('  ').convert({
        'format': 'LumaCraftBuiltinLibrary',
        'version': 1,
        'folders': [for (final f in folders) f.toJson()],
        'presets': [for (final p in entries) p.toJson()]
      });
  factory BuiltinLibrary.decode(String data) {
    if (utf8.encode(data).length > lmpLimit)
      throw const FormatException('内置库超过64MB');
    final j = jsonDecode(data);
    if (j is! Map ||
        j['format'] != 'LumaCraftBuiltinLibrary' ||
        j['version'] != 1 ||
        j['folders'] is! List ||
        j['presets'] is! List) throw const FormatException('不是支持的内置预设库');
    final folders = <BuiltinFolder>[],
        folderIds = <String>{},
        names = <String>{};
    for (final f in j['folders']) {
      if (f is! Map ||
          f['id'] is! String ||
          !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(f['id']) ||
          f['name'] is! String ||
          f['name'].trim().isEmpty ||
          f['name'].length > 100 ||
          !folderIds.add(f['id']) ||
          !names.add(f['name'])) throw const FormatException('内置分组名称或标识无效');
      folders.add(BuiltinFolder(f['id'], f['name']));
    }
    final items = j['presets'] as List;
    if (items.isEmpty || items.length > 200)
      throw const FormatException('内置库需要1～200个预设');
    final ids = <String>{}, presetNames = <String>{};
    for (final p in items) {
      if (p is! Map ||
          p['id'] is! String ||
          !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(p['id']) ||
          !ids.add(p['id']) ||
          !folderIds.contains(p['folder']))
        throw const FormatException('内置预设标识或分组无效');
      if (p['style'] is! Map ||
          !presetNames.add(p['style']['name']?.toString() ?? ''))
        throw const FormatException('内置预设名称重复或无效');
    }
    final checked = decodeLmp(jsonEncode({
      'format': 'LumaCraftPreset',
      'version': 1,
      'requires': ['bundledFontsV1', 'adaptiveLayout'],
      'presets': [
        for (final p in items) {'folder': p['folder'], 'style': p['style']}
      ]
    }));
    return BuiltinLibrary(folders, [
      for (var i = 0; i < items.length; i++)
        BuiltinEntry(items[i]['id'], checked[i].style,
            folder: items[i]['folder'])
    ]);
  }
}
