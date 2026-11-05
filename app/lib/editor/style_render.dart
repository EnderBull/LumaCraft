import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../render.dart';
import '../fonts/font_catalog.dart';
import 'style_document.dart';
import '../ui/editor/mode_transition.dart';
import 'photo_palette.dart';
import 'palette_render.dart';
import 'shape_render.dart';
import 'shape_style.dart';
import 'image_mark.dart';
import 'background_render.dart';
import '../export/export_options.dart';

class StyleScene {
  final StyleDocument document;
  final ui.Image photo;
  final Map<String, String> fields;
  final String? hiddenId;
  final double? ratioOverride;
  late final geometry =
      StyleGeometry(document, ratioOverride ?? photo.width / photo.height);
  final bounds = <String, Rect>{};
  final painters = <String, TextPainter>{};
  final marks = <String, ui.Image>{};
  StyleScene(StyleDocument source, this.photo, this.fields,
      {this.hiddenId,
      this.ratioOverride,
      bool resolveLayout = true,
      bool showMissingInfo = false})
      : document = resolveLayout
            ? source.forRatio(ratioOverride ?? photo.width / photo.height)
            : source {
    for (final n in document.painted) {
      if (!document.visible(n.id)) continue;
      if (n.type == 'image') {
        final image = imageMarkClone(n.image.data);
        if (image != null) marks[n.id] = image;
        bounds[n.id] = Rect.fromCenter(
            center: geometry.point(n),
            width: n.image.width,
            height: n.image.width / n.image.ratio);
        continue;
      }
      if (n.type == 'shape') {
        bounds[n.id] = shapeBounds(geometry.point(n), n.shape);
        continue;
      }
      if (n.type == 'palette') {
        final size = paletteSize(n.palette), point = geometry.point(n);
        bounds[n.id] = Rect.fromCenter(
            center: point, width: size.width, height: size.height);
        continue;
      }
      var text = n.content(fields);
      if (showMissingInfo &&
          text.trim().isEmpty &&
          !['text', 'image', 'palette'].contains(n.type))
        text = '缺少${componentNames[n.type] ?? '拍摄'}信息';
      if (text.isEmpty) continue;
      final painter = TextPainter(
          text: TextSpan(
              text: text,
              style: artworkTextStyle(n.font).copyWith(
                  fontSize: n.fontSize,
                  letterSpacing: n.spacing,
                  color: Color(n.color).withValues(alpha: n.opacity / 100),
                  height: 1.4)),
          textDirection: TextDirection.ltr,
          textAlign: n.align == 'left'
              ? TextAlign.left
              : n.align == 'right'
                  ? TextAlign.right
                  : TextAlign.center)
        ..layout();
      final point = geometry.point(n),
          offset = Offset(
              point.dx -
                  (n.align == 'left'
                      ? 0
                      : n.align == 'right'
                          ? painter.width
                          : painter.width / 2),
              point.dy - painter.height / 2);
      painters[n.id] = painter;
      bounds[n.id] = offset & Size(painter.width, painter.height);
    }
  }
  void paint(Canvas canvas) {
    paintStyleBackground(canvas, document, geometry, photo);
    paintPhotoShadow(canvas, document, geometry);
    final sourceRatio = photo.width / photo.height,
        targetRatio = geometry.photoWidth / geometry.photoHeight;
    final cropWidth = sourceRatio > targetRatio
            ? photo.height * targetRatio
            : photo.width.toDouble(),
        cropHeight = sourceRatio > targetRatio
            ? photo.height.toDouble()
            : photo.width / targetRatio;
    canvas.drawImageRect(
        photo,
        Rect.fromLTWH((photo.width - cropWidth) / 2,
            (photo.height - cropHeight) / 2, cropWidth, cropHeight),
        geometry.photo,
        Paint()..filterQuality = FilterQuality.medium);
    paintFilm(canvas, document, geometry);
    for (final n in document.painted) {
      if (n.type == 'image' && marks[n.id] != null && n.id != hiddenId) {
        final image = marks[n.id]!;
        canvas.drawImageRect(
            image,
            Rect.fromLTWH(
                0, 0, image.width.toDouble(), image.height.toDouble()),
            bounds[n.id]!,
            Paint()
              ..filterQuality = FilterQuality.high
              ..color = Colors.white.withValues(alpha: n.opacity / 100));
        continue;
      }
      if (n.type == 'palette' && document.visible(n.id) && n.id != hiddenId) {
        paintPalette(canvas, bounds[n.id]!, n.palette,
            paletteFromFields(fields), n.opacity);
        continue;
      }
      if (n.type == 'shape' && bounds[n.id] != null && n.id != hiddenId) {
        paintShape(canvas, geometry.point(n), n.shape, n.opacity);
        continue;
      }
      final p = painters[n.id], r = bounds[n.id];
      if (p != null && r != null && n.id != hiddenId)
        p.paint(canvas, r.topLeft);
    }
  }

  Rect? objectBounds(String id) {
    Rect? out;
    for (final key in document.leaves(id)) {
      final r = bounds[key];
      if (r != null) out = out == null ? r : out.expandToInclude(r);
    }
    return out;
  }

  void dispose() {
    for (final image in marks.values) {
      image.dispose();
    }
    for (final p in painters.values) {
      p.dispose();
    }
  }
}

class StylePreview extends StatefulWidget {
  final ui.Image photo;
  final StyleDocument document;
  final Map<String, String> fields;
  final bool workspaceCanvas;
  final String? photoPath;
  final bool imagesPrepared;
  const StylePreview(
      {super.key,
      required this.photo,
      required this.document,
      this.fields = const {},
      this.workspaceCanvas = false,
      this.photoPath,
      this.imagesPrepared = false});
  @override
  State<StylePreview> createState() => _StylePreviewState();
}

class _StylePreviewState extends State<StylePreview> {
  Set<String> resident = {};
  Future<void>? preparation;
  @override
  void dispose() {
    releaseImageMarks(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document,
        photo = widget.photo,
        fields = widget.fields,
        workspaceCanvas = widget.workspaceCanvas,
        photoPath = widget.photoPath;
    final images = document.nodes
        .where((n) => n.type == 'image')
        .map((n) => n.image)
        .toList();
    final keys = images.map((m) => m.data).toSet();
    if (!setEquals(keys, resident)) {
      resident = keys;
      preparation = null;
    }
    pinImageMarks(this, images);
    if (!widget.imagesPrepared && images.any((m) => !imageMarkReady(m.data))) {
      return FutureBuilder<void>(
          future: preparation ??= prepareImageMarks(images),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Center(child: Text('图片标识加载失败，请替换素材后重试'));
            if (snapshot.connectionState != ConnectionState.done)
              return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2));
            return StylePreview(
                photo: photo,
                document: document,
                fields: fields,
                workspaceCanvas: workspaceCanvas,
                photoPath: photoPath,
                imagesPrepared: true);
          });
    }
    if (photoPath != null &&
        document.nodes.any((n) => n.type == 'palette') &&
        paletteFromFields(fields).length != 6) {
      return FutureBuilder<List<int>>(
          key: ValueKey(photoPath),
          future: photoPaletteForFile(photoPath),
          builder: (context, snapshot) => snapshot.hasError
              ? const Center(child: Text('照片提色失败，请重新选择照片'))
              : snapshot.hasData
                  ? StylePreview(
                      photo: photo,
                      document: document,
                      fields: {
                        ...fields,
                        photoPaletteField: snapshot.data!.join(',')
                      },
                      workspaceCanvas: workspaceCanvas)
                  : const Center(
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))));
    }
    final resolved = document.forRatio(photo.width / photo.height);
    final g = StyleGeometry(resolved, photo.width / photo.height);
    final artwork = SizedBox(
        width: g.size.width,
        height: g.size.height,
        child: CustomPaint(painter: StylePainter(document, photo, fields)));
    return FittedBox(
        child: workspaceCanvas ? WorkspaceCanvas(child: artwork) : artwork);
  }
}

class StylePainter extends CustomPainter {
  final bool resolveLayout, showMissingInfo;
  final StyleDocument document;
  final ui.Image photo;
  final Map<String, String> fields;
  final String? hiddenId;
  final double? ratioOverride;
  StylePainter(this.document, this.photo, this.fields,
      {this.hiddenId,
      this.ratioOverride,
      this.resolveLayout = true,
      this.showMissingInfo = false});
  @override
  void paint(Canvas canvas, Size size) {
    final scene = StyleScene(document, photo, fields,
        hiddenId: hiddenId,
        ratioOverride: ratioOverride,
        resolveLayout: resolveLayout,
        showMissingInfo: showMissingInfo);
    scene.paint(canvas);
    scene.dispose();
  }

  @override
  bool shouldRepaint(covariant StylePainter oldDelegate) => true;
}

Future<Uint8List> renderStyledPhoto(
    String path, StyleDocument style, Map<String, String> fields, bool png,
    {ExportOptions? options,
    ui.Image? managedPhoto,
    Uint8List? srgbProfile}) async {
  late ui.Image photo;
  if (managedPhoto != null) {
    photo = managedPhoto.clone();
  } else {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    final codec = await ui.instantiateImageCodecFromBuffer(buffer);
    try {
      photo = (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }
  ui.Image? rendered;
  ui.Picture? picture;
  StyleScene? scene;
  final lease = Object();
  pinImageMarks(
      lease, style.nodes.where((n) => n.type == 'image').map((n) => n.image));
  try {
    if (style.nodes.any((n) => n.type == 'palette')) {
      fields = {
        ...fields,
        photoPaletteField: (await photoPaletteForFile(path)).join(',')
      };
    }
    await prepareImageMarks(
        style.nodes.where((n) => n.type == 'image').map((n) => n.image));
    if (style.nodes.any((n) => n.type == 'image' && n.image.data.isEmpty))
      throw StateError('图片标识缺少素材，请替换后导出');
    scene = StyleScene(style, photo, fields);
    final g = scene.geometry;
    var scale = math.min(photo.width, photo.height) / 1000;
    if (options?.edgePixels != null) {
      scale = options!.edgePixels! /
          (options.sizeEdge == 'long'
              ? math.max(g.size.width, g.size.height)
              : math.min(g.size.width, g.size.height));
    }
    if (options != null)
      validateExportSize(
          (g.size.width * scale).round(), (g.size.height * scale).round());
    final recorder = ui.PictureRecorder(),
        canvas = Canvas(recorder)..scale(scale);
    scene.paint(canvas);
    picture = recorder.endRecording();
    rendered = await picture.toImage(
        (g.size.width * scale).round(), (g.size.height * scale).round());
    final data =
        await rendered.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if (data == null) throw StateError('导出像素读取失败');
    if (options != null) {
      if (srgbProfile == null) throw StateError('导出缺少 sRGB ICC');
      return await compute(encodeExportPixels, (
        Uint8List.sublistView(data),
        rendered.width,
        rendered.height,
        path,
        fields,
        options,
        srgbProfile
      ));
    }
    return await compute(encodeStyledPixels, (
      Uint8List.sublistView(data),
      rendered.width,
      rendered.height,
      path,
      fields,
      png
    ));
  } finally {
    scene?.dispose();
    releaseImageMarks(lease);
    rendered?.dispose();
    picture?.dispose();
    photo.dispose();
  }
}
