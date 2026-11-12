import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

const androidPlatform = MethodChannel('lumacraft/android_p1');

// Compact ICC Profiles, sRGB-v2-micro, CC0-1.0.
// https://github.com/saucecontrol/Compact-ICC-Profiles
final androidSrgbProfile = base64Decode(
    'AAAByGxjbXMCEAAAbW50clJHQiBYWVogB+IAAwAUAAkADgAdYWNzcE1TRlQAAAAAc2F3c2N0cmwAAAAAAAAAAAAAAAAAAPbWAAEAAAAA0y1oYW5knZEAPUCAsD1AdCyBnqUijgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJZGVzYwAAAPAAAABfY3BydAAAAQwAAAAMd3RwdAAAARgAAAAUclhZWgAAASwAAAAUZ1hZWgAAAUAAAAAUYlhZWgAAAVQAAAAUclRSQwAAAWgAAABgZ1RSQwAAAWgAAABgYlRSQwAAAWgAAABgZGVzYwAAAAAAAAAFdVJHQgAAAAAAAAAAAAAAAHRleHQAAAAAQ0MwAFhZWiAAAAAAAADzVAABAAAAARbJWFlaIAAAAAAAAG+gAAA48gAAA49YWVogAAAAAAAAYpYAALeJAAAY2lhZWiAAAAAAAAAkoAAAD4UAALbEY3VydgAAAAAAAAAqAAAAfAD4AZwCdQODBMkGTggSChgMYg70Ec8U9hhqHC4gQySsKWoufjPrObM/1kZXTTZUdlwXZB1shnVWfo2ILJI2nKunjLLbvpnKx9dl5Hfx+f//');

class AndroidPhoto {
  final String path, name;
  final String? uri;
  const AndroidPhoto(this.path, this.name, {this.uri});

  factory AndroidPhoto.fromJson(Map<String, dynamic> json) =>
      AndroidPhoto(json['path'] as String, json['name'] as String,
          uri: json['uri'] as String?);

  Map<String, Object?> toJson() => {'path': path, 'name': name, 'uri': uri};

  Future<String> readablePath() async {
    if (uri == null) return path;
    return (await androidPlatform
        .invokeMethod<String>('materializePhoto', {'uri': uri, 'path': path}))!;
  }

  static Future<List<AndroidPhoto>> pickPhotos({required bool album}) async {
    final results = await androidPlatform
        .invokeListMethod<Object?>('pickPhotos', {'album': album});
    return [
      for (final item in results ?? const [])
        AndroidPhoto(
          (item as Map)['path'] as String,
          item['name'] as String,
          uri: item['uri'] as String?,
        ),
    ];
  }

  static Future<AndroidPhoto?> pick({bool preset = false}) async {
    final result = await androidPlatform
        .invokeMapMethod<String, Object?>('pick', {'preset': preset});
    if (result == null) return null;
    return AndroidPhoto(result['path'] as String, result['name'] as String);
  }
}

class AndroidDecodedPhoto {
  final File file;
  final int sourceWidth, sourceHeight, width, height;
  final String? sourceColor, targetColor;

  AndroidDecodedPhoto._(Map<String, Object?> data)
      : file = File(data['path'] as String),
        sourceWidth = data['sourceWidth'] as int,
        sourceHeight = data['sourceHeight'] as int,
        width = data['width'] as int,
        height = data['height'] as int,
        sourceColor = data['sourceColor'] as String?,
        targetColor = data['targetColor'] as String?;

  static Future<AndroidDecodedPhoto> decode(String path, int maxEdge) async {
    final data = await androidPlatform.invokeMapMethod<String, Object?>(
        'decode', {'path': path, 'maxEdge': maxEdge});
    return AndroidDecodedPhoto._(data!);
  }

  String get description =>
      '$sourceWidth×$sourceHeight → $width×$height · $sourceColor → $targetColor';

  Future<ui.Image> openImage() async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
    final codec = await ui.instantiateImageCodecFromBuffer(buffer);
    try {
      final image = (await codec.getNextFrame()).image;
      if (image.width == width && image.height == height) return image;
      final size = '${image.width}×${image.height}';
      image.dispose();
      throw StateError('原尺寸解码需要 $width×$height，渲染器只返回 $size，无法导出。');
    } finally {
      codec.dispose();
    }
  }
}

Future<String> publishToAndroidGallery(
    Uint8List bytes, String filename, String format,
    {bool replace = false}) async {
  final temp = await Directory.systemTemp.createTemp('lumacraft-export-');
  try {
    final output =
        await File('${temp.path}/output.$format').writeAsBytes(bytes);
    return (await androidPlatform.invokeMethod<String>('publish', {
      'path': output.path,
      'name': filename,
      'format': format,
      'replace': replace,
    }))!;
  } finally {
    await temp.delete(recursive: true);
  }
}
