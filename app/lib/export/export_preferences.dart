import '../usage_data.dart';
import 'dart:convert';
import 'dart:io';
import 'export_options.dart';

class ExportPreferences {
  final File file;
  ExportPreferences(this.file);
  Future<(ExportOptions, List<NamingPart>)> load() async {
    final defaults = ExportOptions();
    if (!await file.exists()) return (defaults, defaultNamingTemplate());
    try {
      final j = jsonDecode(await file.readAsString());
      if (j['version'] != 1) return (defaults, defaultNamingTemplate());
      final o = ExportOptions()
        ..directory = j['directory'] ?? ''
        ..format = j['format'] == 'png' ? 'png' : 'jpg'
        ..scope = ['current', 'selected', 'edited'].contains(j['scope'])
            ? j['scope']
            : 'selected'
        ..sizeEdge = j['sizeEdge'] == 'short' ? 'short' : 'long'
        ..quality = (j['quality'] as int? ?? 92).clamp(1, 100)
        ..retainCaptureInfo = j['retainCaptureInfo'] != false
        ..retainGps = j['retainGps'] == true;
      final pixels = j['edgePixels'];
      if (pixels is int && pixels > 0 && pixels <= exportMaxEdge) o.edgePixels = pixels;
      final parts = <NamingPart>[];
      for (final p in j['template'] as List) {
        if (parts.length >= 100 ||
            p['value'] is! String ||
            (p['value'] as String).length > 1000) throw const FormatException();
        if (p['variable'] == true) {
          if (!namingVariables.values
              .any((group) => group.containsKey(p['value'])))
            throw const FormatException();
          parts.add(NamingPart.variable(p['value']));
        } else {
          parts.add(NamingPart.text(p['value']));
        }
      }
      return (o, parts.isEmpty ? defaultNamingTemplate() : parts);
    } catch (_) {
      return (defaults, defaultNamingTemplate());
    }
  }

  Future<void> save(ExportOptions o, List<NamingPart> template) async {
    await file.parent.create(recursive: true);
    if (UsageData.frozen) return;
    final data = jsonEncode({
      'version': 1,
      'directory': o.directory,
      'format': o.format,
      'scope': o.scope,
      'sizeEdge': o.sizeEdge,
      'edgePixels': o.edgePixels,
      'quality': o.quality,
      'retainCaptureInfo': o.retainCaptureInfo,
      'retainGps': o.retainGps,
      'template': [
        for (final part in template)
          {'variable': part.variable, 'value': part.value}
      ]
    });
    await UsageData.writeStringAtomic(file, data);
  }
}
