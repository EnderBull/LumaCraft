import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../export/color_management.dart';
import '../photo_state.dart';

/// Thumbnails for both plain JPG and the formats that need Windows colour
/// conversion.
///
/// Files are read into memory and decoded from bytes rather than through
/// Image.file: the framework's file-backed image provider keeps the file open,
/// and on Windows an open handle blocks deleting the photo outside the app.
class _Thumbs {
  static final images = <String, ui.Image>{};
  static final order = <String>[];
  static final pending = <String, Future<ui.Image>>{};
  static final needsTool = <String, bool>{};

  /// A photo on a disconnected drive, or one deleted a moment ago, must not
  /// take the whole list down: treat it as a plain thumbnail in that case.
  static bool usesTool(String path) {
    if (heifPath(path)) return true;
    final known = needsTool[path];
    if (known != null) return known;
    try {
      return needsTool[path] = jpegUsesWideGamut(path);
    } catch (_) {
      return false;
    }
  }

  static Future<ui.Image> load(String path) {
    final ready = images[path];
    if (ready != null) return Future.value(ready);
    return pending[path] ??= () async {
      try {
        final image = usesTool(path)
            ? await decodePhotoImage(path, maxEdge: 240)
            : await _decodeBytes(path, 240);
        order.remove(path);
        order.add(path);
        images[path] = image;
        while (order.length > 80) {
          final oldest = order.removeAt(0);
          if (oldest == path) continue;
          images.remove(oldest)?.dispose();
        }
        return image;
      } finally {
        pending.remove(path);
      }
    }();
  }

  /// Reads the file, decodes a small copy, and closes the handle immediately.
  static Future<ui.Image> _decodeBytes(String path, int maxEdge) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes,
        targetWidth: maxEdge, allowUpscaling: false);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  static void forget(String path) {
    // Only the cache entry is dropped. Disposing the image here would crash a
    // thumbnail still on screen ("Cannot clone a disposed image") right after
    // a photo is deleted; with no references left it is freed anyway.
    images.remove(path);
    order.remove(path);
  }
}

class PhotoThumb extends StatelessWidget {
  final File file;
  const PhotoThumb(this.file, {super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<ui.Image>(
      future: _Thumbs.load(file.path),
      builder: (context, snap) {
        final image = snap.data;
        if (image == null) {
          return Icon(snap.hasError
              ? Icons.broken_image_outlined
              : Icons.image_outlined);
        }
        return RawImage(image: image, fit: BoxFit.contain);
      });
}

/// Frees a cached thumbnail, so a deleted photo stops being held in memory.
void forgetThumbnail(String path) => _Thumbs.forget(path);

/// Drops every cached thumbnail; used when the list is rebuilt.
void clearThumbnails() {
  for (final image in _Thumbs.images.values) {
    image.dispose();
  }
  _Thumbs.images.clear();
  _Thumbs.order.clear();
  _Thumbs.needsTool.clear();
}
