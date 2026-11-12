import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'editor/builtin_library.dart';
import 'editor/style_document.dart';
import 'export/export_options.dart';
import 'export/export_naming.dart';
import 'export/photo_export.dart';
import 'export/android_photo_io.dart';
import 'photo_state.dart';
import 'settings/android_map_preview.dart';
import 'settings/app_settings.dart';
import 'editor/preset_package.dart';

const _platform = androidPlatform;

void main() => runApp(MaterialApp(
      title: 'LumaCraft Android P2',
      theme: ThemeData.dark(useMaterial3: true),
      home: const _Probe(),
    ));

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  AndroidPhoto? _source;
  String _format = 'jpg';
  File? _preview;
  bool _busy = false;
  String _status = '从系统文件选择器选一张 JPEG 或 HEIC。';
  List<SharedPreset>? _imported;
  AppSettings? _settings;
  final _size = TextEditingController();
  String _edge = 'long';
  bool _retainGps = false;
  final _key = TextEditingController();
  final _secret = TextEditingController();
  late final Future<StyleDocument> _preset = _loadPreset();

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
    _platform.setMethodCallHandler((call) async {
      if (call.method == 'mapTitle' && call.arguments is String) {
        final title = call.arguments as String;
        if (title.startsWith('STATE:') || title.startsWith('PICK:')) {
          _report('地图 ${title.substring(title.indexOf(':') + 1)}');
        }
      }
    });
  }

  @override
  void dispose() {
    _platform.setMethodCallHandler(null);
    _settings?.dispose();
    _size.dispose();
    _key.dispose();
    _secret.dispose();
    super.dispose();
  }

  void _report(String status) {
    debugPrint('LumaCraftP1 $status');
    if (mounted) setState(() => _status = status);
  }

  Future<StyleDocument> _loadPreset() async {
    final library =
        BuiltinLibrary.decode(await rootBundle.loadString(bundledBuiltinAsset));
    return library.entries.firstWhere((item) => item.id == 'gallery').style;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      _report('失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _measure(String stage, Future<void> Function() action) async {
    final clock = Stopwatch()..start();
    final baseline = await _platform.invokeMethod<int>('pss') ?? 0;
    var peak = baseline;
    var reading = false;
    Future<void> sample() async {
      if (reading) return;
      reading = true;
      try {
        final pss = await _platform.invokeMethod<int>('pss') ?? 0;
        if (pss > peak) peak = pss;
      } finally {
        reading = false;
      }
    }

    final sampler = Timer.periodic(
        const Duration(milliseconds: 250), (_) => unawaited(sample()));
    try {
      await action();
    } finally {
      sampler.cancel();
      await sample();
      debugPrint('LumaCraftP1 MEMORY $stage '
          'baselineKiB=$baseline peakKiB=$peak elapsedMs=${clock.elapsedMilliseconds}');
    }
  }

  Future<void> _pick() async {
    final picked = await AndroidPhoto.pick();
    if (picked == null) return;
    final oldSource = _source;
    final oldPreview = _preview;
    _source = picked;
    _preview = null;
    _report('正在解码 ${picked.name}');
    if (oldSource != null) await File(oldSource.path).delete();
    if (oldPreview != null) await oldPreview.delete();
    await _measure('preview', () async {
      final decoded = await AndroidDecodedPhoto.decode(picked.path, 1440);
      _preview = decoded.file;
      final fields = await compute(readCapture, picked.path);
      _report('${picked.name} · ${decoded.description}\n'
          'EXIF ${_captureSummary(fields)}');
    });
  }

  String _captureSummary(Map<String, String> fields) => fields.entries
      .where((entry) => entry.key != gpsField)
      .map((entry) => '${entry.key}=${entry.value}')
      .join(' / ');

  Future<void> _export() async {
    final source = _source!;
    final sizeText = _size.text.trim();
    final edgePixels = sizeText.isEmpty ? null : int.tryParse(sizeText);
    if (sizeText.isNotEmpty &&
        (edgePixels == null || edgePixels < 1 || edgePixels > exportMaxEdge)) {
      throw const FormatException('请输入有效的成片边长，或留空以使用原尺寸。');
    }
    final options = ExportOptions()
      ..format = _format
      ..edgePixels = edgePixels
      ..sizeEdge = _edge
      ..retainGps = _retainGps;
    _report('正在渲染 ${source.name}');
    await _measure('export', () async {
      final style = _imported?.first.style ?? await _preset;
      final decoded = await AndroidDecodedPhoto.decode(source.path, 0);
      try {
        _report('已解码 ${decoded.description}，正在渲染');
        final fields = await compute(readCapture, source.path);
        final photo = await decoded.openImage();
        late final Uint8List data;
        try {
          data = await encodeStyledExport(
            sourcePath: source.path,
            style: style,
            fields: fields,
            options: options,
            photo: photo,
            profile: androidSrgbProfile,
          );
        } finally {
          photo.dispose();
        }
        final size = img.findDecoderForData(data)?.startDecode(data);
        if (size == null) throw StateError('无法读取成片尺寸，未保存到相册。');
        final exif = captureExif(data);
        final name =
            resolveExportName(defaultNamingTemplate(), source.name, fields, 1);
        final uri = await publishToAndroidGallery(
            data, '${name.stem}.${options.format}', options.format);
        _report('已保存到相册 · ${size.width}×${size.height}\n'
            'ICC ${_containsProfile(data) ? '已嵌入' : '缺失'} · '
            'EXIF ${exif?.exifIfd[0x9003] ?? '无拍摄时间'} · '
            'GPS ${exif == null || readGpsCoordinates(exif) == null ? '无' : '有'}\n'
            '$uri');
      } finally {
        await decoded.file.delete();
      }
    });
  }

  bool _containsProfile(Uint8List data) {
    if (_format == 'png') {
      final bytes = ByteData.sublistView(data);
      for (var offset = 8; offset + 12 <= data.length;) {
        final length = bytes.getUint32(offset);
        if (length > data.length - offset - 12) return false;
        final kind = ascii.decode(data.sublist(offset + 4, offset + 8));
        if (kind == 'iCCP') return true;
        if (kind == 'IDAT') return false;
        offset += 12 + length;
      }
      return false;
    }
    // The shared encoder writes the complete micro profile in a single APP2.
    final bytes = ByteData.sublistView(data);
    for (var offset = 2; offset + 4 <= data.length && data[offset] == 0xff;) {
      final marker = data[offset + 1];
      final length = bytes.getUint16(offset + 2);
      final end = offset + 2 + length;
      if (marker == 0xda || length < 2 || end > data.length) break;
      if (marker == 0xe2 &&
          length == 16 + androidSrgbProfile.length &&
          ascii.decode(data.sublist(offset + 4, offset + 16),
                  allowInvalid: true) ==
              'ICC_PROFILE\u0000' &&
          listEquals(data.sublist(offset + 18, end), androidSrgbProfile)) {
        return true;
      }
      offset = end;
    }
    return false;
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await loadAndroidSettings();
      if (!mounted) {
        settings.dispose();
        return;
      }
      _settings = settings;
      if (_key.text.isEmpty && _secret.text.isEmpty) {
        _key.text = settings.amapKey;
        _secret.text = settings.amapSecret;
      }
    } on Object catch (_) {
      if (mounted) _report('读取本机地图设置失败。');
    }
  }

  Future<void> _map() async {
    final key = _key.text.trim(), secret = _secret.text.trim();
    await showAndroidMap(key, secret);
    if (_settings case final settings?) {
      settings.amapKey = key;
      settings.amapSecret = secret;
      await settings.flush();
      if (settings.saveError != null) throw StateError(settings.saveError!);
    }
  }

  Future<void> _importPreset() async {
    final selection = await AndroidPhoto.pick(preset: true);
    if (selection == null) return;
    final file = File(selection.path);
    try {
      if (!selection.name.toLowerCase().endsWith('.lmp')) {
        throw const FormatException('请选择 .lmp 文件。');
      }
      final imported = await readLmp(file);
      _imported = imported;
      _report('已载入 ${imported.length} 个预设，正在使用「${imported.first.style.name}」。');
    } finally {
      await file.delete();
    }
  }

  Future<void> _savePreset() async {
    final presets = _imported ?? [SharedPreset(await _preset)];
    final data = await compute(encodeLmp, presets);
    final work = await Directory.systemTemp.createTemp('lumacraft-preset-');
    try {
      final file =
          await File('${work.path}/LumaCraft-P2.lmp').writeAsString(data);
      final saved = await _platform
          .invokeMethod<String>('savePreset', {'path': file.path});
      if (saved != null) _report('已保存 ${presets.length} 个预设到 .lmp。');
    } finally {
      await work.delete(recursive: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('LumaCraft · Android P2')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilledButton(
                  onPressed: _busy ? null : () => _run(_pick),
                  child: const Text('选择照片')),
              FilledButton(
                  onPressed:
                      _busy || _preview == null ? null : () => _run(_export),
                  child: Text('套用预设并保存 ${_format.toUpperCase()}')),
              DropdownButton<String>(
                value: _format,
                onChanged:
                    _busy ? null : (value) => setState(() => _format = value!),
                items: const [
                  DropdownMenuItem(value: 'jpg', child: Text('JPG')),
                  DropdownMenuItem(value: 'png', child: Text('PNG')),
                ],
              ),
              Row(
                children: [
                  DropdownButton<String>(
                    value: _edge,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _edge = value!),
                    items: const [
                      DropdownMenuItem(value: 'long', child: Text('长边')),
                      DropdownMenuItem(value: 'short', child: Text('短边')),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _size,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          hintText: '原尺寸', suffixText: 'px'),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                title: const Text('保留 GPS'),
                value: _retainGps,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _retainGps = value),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _busy ? null : () => _run(_importPreset),
                    child: const Text('导入 .lmp'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _run(_savePreset),
                    child: const Text('保存 .lmp'),
                  ),
                ],
              ),
              if (_preview case final preview?)
                SizedBox(
                    height: 180,
                    child: Image.file(preview, fit: BoxFit.contain)),
              const SizedBox(height: 12),
              SelectableText(_status),
              const SizedBox(height: 24),
              TextField(
                  controller: _key,
                  decoration:
                      const InputDecoration(labelText: '高德 JS API Key')),
              TextField(
                  controller: _secret,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '高德安全密钥')),
              const SizedBox(height: 8),
              OutlinedButton(
                  onPressed: _busy ? null : () => _run(_map),
                  child: const Text('打开地图验证（留空测试本机通信）')),
            ],
          ),
        ),
      );
}
