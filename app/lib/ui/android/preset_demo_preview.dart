import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../editor/image_mark.dart';
import '../../editor/photo_palette.dart';
import '../../editor/preset_store.dart';
import '../../editor/style_document.dart';
import '../../editor/style_render.dart';
import '../../editor/texture_render.dart';
import '../../usage_data.dart';

const presetDemoFields = {
  'camera': 'LumaCraft',
  'lens': '35mm F2.8',
  'time': '2026:10:18 06:42:00',
  'focal': '35',
  'aperture': '2.8',
  'shutter': '1/250',
  'iso': '100',
  'place': '山间日出',
  photoPaletteField:
      '4294958230,4290570479,4284666558,4284198846,4284199604,4291280041',
};

const builtinDemoDirectory = 'assets/android_preset_previews';

Future<ui.Image> loadPresetDemoLandscape() async {
  final bytes =
      await rootBundle.load('assets/branding/preset-demo-landscape.png');
  final codec = await ui.instantiateImageCodec(Uint8List.sublistView(bytes));
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

Future<Uint8List> renderPresetDemo(StyleDocument style) async {
  final photo = await loadPresetDemoLandscape();
  final marks = style.nodes
      .where((node) => node.type == 'image')
      .map((node) => node.image)
      .toList();
  final lease = Object();
  StyleScene? scene;
  ui.Picture? picture;
  ui.Image? thumbnail;
  try {
    pinImageMarks(lease, marks);
    await prepareImageMarks(marks);
    await ensureTexture(style.fill.texture);
    scene = StyleScene(style, photo, presetDemoFields);
    final size = scene.geometry.size;
    final scale = math.min(320 / size.width, 232 / size.height);
    final recorder = ui.PictureRecorder();
    scene.paint(ui.Canvas(recorder)..scale(scale));
    picture = recorder.endRecording();
    thumbnail = await picture.toImage(
      math.max(1, (size.width * scale).round()),
      math.max(1, (size.height * scale).round()),
    );
    final bytes = await thumbnail.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('未能生成预设缩略图');
    return Uint8List.sublistView(bytes);
  } finally {
    thumbnail?.dispose();
    picture?.dispose();
    scene?.dispose();
    photo.dispose();
    releaseImageMarks(lease);
  }
}

class PresetDemoCache {
  PresetDemoCache(this.directory);

  final Directory directory;
  final _pending = <(String, StyleDocument), Future<Uint8List?>>{};
  Future<void> _queue = Future.value();
  bool _closed = false;

  void warm(Iterable<PresetEntry> entries) {
    for (final entry in entries) {
      if (!entry.builtIn) unawaited(read(entry));
    }
  }

  Future<Uint8List?> read(PresetEntry entry) {
    if (_closed) return Future.value();
    final key = (entry.id, entry.style);
    return _pending.putIfAbsent(key, () {
      final result = _queue.then((_) => _loadOrRender(entry)).whenComplete(() {
        _pending.remove(key);
      });
      _queue = result.then<void>((_) {});
      return result;
    });
  }

  Future<Uint8List?> _loadOrRender(PresetEntry entry) async {
    if (_closed) return null;
    try {
      final id = base64Url.encode(utf8.encode(entry.id));
      final file = File('${directory.path}/$id.preview');
      final style = entry.style.toJson()..remove('name');
      final revision =
          sha256.convert(utf8.encode(jsonEncode(style))).toString();
      if (await file.exists()) {
        final cached = await file.readAsString();
        if (cached.startsWith('$revision\n')) {
          try {
            final png = base64Decode(cached.substring(revision.length + 1));
            if (png.isNotEmpty) return png;
          } on FormatException {
            // An unreadable entry can be regenerated from the saved preset.
          }
        }
      }
      final png = await SchedulerBinding.instance.scheduleTask(
        () => _closed
            ? Future<Uint8List?>.value()
            : renderPresetDemo(entry.style),
        Priority.idle,
      );
      if (png == null) return null;
      if (!_closed) {
        await UsageData.writeStringAtomic(
          file,
          '$revision\n${base64Encode(png)}',
          gated: false,
        );
      }
      return png;
    } on Object {
      return null;
    }
  }

  void dispose() => _closed = true;
}
