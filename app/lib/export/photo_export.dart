import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../editor/style_document.dart';
import '../editor/style_render.dart';
import '../render.dart';
import 'color_management.dart';
import 'export_options.dart';

/// Encodes a color-managed source. The caller owns the image and decides where
/// to publish the result, after its platform-specific cancellation checks.
Future<Uint8List> encodeStyledExport({
  required String sourcePath,
  required StyleDocument style,
  required Map<String, String> fields,
  required ExportOptions options,
  required ui.Image photo,
  required Uint8List profile,
  String? palettePhotoPath,
}) =>
    renderStyledPhoto(sourcePath, style, fields, options.format == 'png',
        options: options,
        managedPhoto: photo,
        srgbProfile: profile,
        palettePhotoPath: palettePhotoPath);

Future<Uint8List> encodeWindowsExport({
  required String sourcePath,
  required StyleDocument? style,
  required bool film,
  required Map<String, String> fields,
  required ExportOptions options,
  required ManagedPhoto managed,
}) async {
  if (style == null) {
    return compute(renderLegacyExport, (
      managed.rgba,
      managed.width,
      managed.height,
      film,
      sourcePath,
      fields,
      options,
      managed.profile
    ));
  }
  final photo = await managed.image();
  try {
    return await encodeStyledExport(
      sourcePath: sourcePath,
      style: style,
      fields: fields,
      options: options,
      photo: photo,
      profile: managed.profile,
    );
  } finally {
    photo.dispose();
  }
}
