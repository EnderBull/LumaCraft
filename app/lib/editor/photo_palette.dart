import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show compute;
import '../export/color_management.dart';

const photoPaletteField = '__photoPalette';
final _paletteCache = <String, Future<List<int>>>{};

/// Fixed source sampling makes editor previews and full-size exports agree.
Future<List<int>> photoPaletteForFile(String path) async {
  final stat = await File(path).stat();
  final key = '$path:${stat.size}:${stat.modified.microsecondsSinceEpoch}';
  final cached = _paletteCache[key];
  if (cached != null) return cached;
  while (_paletteCache.length >= 48) {
    _paletteCache.remove(_paletteCache.keys.first);
  }
  final future = _readPalette(path);
  _paletteCache[key] = future;
  try {
    return await future;
  } catch (_) {
    if (identical(_paletteCache[key], future)) _paletteCache.remove(key);
    rethrow;
  }
}

Future<List<int>> _readPalette(String path) async {
  final image = await decodePhotoImage(path, maxEdge: 96);
  try {
    final data =
        await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if (data == null) throw StateError('照片提色失败');
    return await compute(extractPhotoColors, Uint8List.sublistView(data));
  } finally {
    image.dispose();
  }
}

List<int> paletteFromFields(Map<String, String> fields) =>
    (fields[photoPaletteField] ?? '')
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .take(6)
        .toList();

/// Occupancy-weighted farthest-point seeds followed by medoid refinement.
/// Every representative is an observed source sample, never an invented hue.
List<int> extractPhotoColors(Uint8List rgba) {
  final bins = <int, (int, int)>{};
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    if (rgba[i + 3] < 128) continue;
    final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
    final key = (r >> 3) << 10 | (g >> 3) << 5 | b >> 3;
    final old = bins[key];
    bins[key] =
        ((old?.$1 ?? 0) + 1, old?.$2 ?? (0xff000000 | r << 16 | g << 8 | b));
  }
  if (bins.isEmpty) throw StateError('照片中没有可提取的颜色');
  final candidates = bins.values.toList()..sort((a, b) => b.$1.compareTo(a.$1));
  double distance(int a, int b) {
    final dr = (a >> 16 & 255) - (b >> 16 & 255),
        dg = (a >> 8 & 255) - (b >> 8 & 255),
        db = (a & 255) - (b & 255);
    return 2.0 * dr * dr + 4.0 * dg * dg + 3.0 * db * db;
  }

  var centers = <int>[candidates.first.$2];
  while (centers.length < 6) {
    var score = 0.0, chosen = centers.first;
    for (final entry in candidates) {
      final nearest =
          centers.map((c) => distance(c, entry.$2)).reduce(math.min);
      final weighted = nearest * math.sqrt(entry.$1);
      if (weighted > score) {
        score = weighted;
        chosen = entry.$2;
      }
    }
    if (score == 0) break;
    centers.add(chosen);
  }
  for (var iteration = 0; iteration < 6; iteration++) {
    final groups = List.generate(centers.length, (_) => <(int, int)>[]);
    for (final entry in candidates) {
      var best = 0, nearest = double.infinity;
      for (var i = 0; i < centers.length; i++) {
        final d = distance(entry.$2, centers[i]);
        if (d < nearest) {
          nearest = d;
          best = i;
        }
      }
      groups[best].add(entry);
    }
    centers = [
      for (var i = 0; i < groups.length; i++)
        (() {
          final group = groups[i];
          if (group.isEmpty) return centers[i];
          var r = 0, g = 0, b = 0, count = 0;
          for (final e in group) {
            count += e.$1;
            r += (e.$2 >> 16 & 255) * e.$1;
            g += (e.$2 >> 8 & 255) * e.$1;
            b += (e.$2 & 255) * e.$1;
          }
          final mean =
              0xff000000 | (r ~/ count) << 16 | (g ~/ count) << 8 | b ~/ count;
          return (group.toList()
                ..sort((a, b) =>
                    distance(a.$2, mean).compareTo(distance(b.$2, mean))))
              .first
              .$2;
        })()
    ];
  }
  final unique = centers.toSet().toList();
  while (centers.length < 6) {
    centers.add(unique[centers.length % unique.length]);
  }
  double light(int c) =>
      .2126 * (c >> 16 & 255) + .7152 * (c >> 8 & 255) + .0722 * (c & 255);
  centers.sort((a, b) => light(a).compareTo(light(b)));
  return centers;
}
