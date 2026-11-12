import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../editor/qr_scan.dart';

/// Composes the Android share image without resampling the QR modules.
Future<Uint8List> renderPresetQrCard(String code, String presetName) async {
  final qr = await _decodeImage(await compute(encodePresetQrPng, code));
  try {
    final asset =
        await rootBundle.load('assets/branding/lumacraft-icon-1024.png');
    final icon = await _decodeImage(
      asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
      targetWidth: 112,
    );
    try {
      final side = math.max(760, qr.width + 84);
      final unit = side / 760;
      final footerHeight = (82 * unit).round();
      final canvasSize =
          Size(side.toDouble(), (side + footerHeight).toDouble());
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..drawRect(Offset.zero & canvasSize, Paint()..color = Colors.white);
      final qrInset = ((side - qr.width) ~/ 2).toDouble();
      canvas.drawImage(qr, Offset(qrInset, qrInset), Paint());

      canvas
        ..save()
        ..translate(0, side.toDouble())
        ..scale(unit, unit);
      _paintFooter(canvas, icon, presetName);
      canvas.restore();

      final picture = recorder.endRecording();
      try {
        final result = await picture.toImage(side, side + footerHeight);
        try {
          final png = await result.toByteData(format: ui.ImageByteFormat.png);
          if (png == null) throw StateError('无法生成预设二维码图片。');
          return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
        } finally {
          result.dispose();
        }
      } finally {
        picture.dispose();
      }
    } finally {
      icon.dispose();
    }
  } finally {
    qr.dispose();
  }
}

void _paintFooter(Canvas canvas, ui.Image icon, String presetName) {
  canvas.drawRect(const Rect.fromLTWH(0, 0, 760, 83),
      Paint()..color = const Color(0xff282624));
  canvas.drawImageRect(
    icon,
    Rect.fromLTWH(0, 0, icon.width.toDouble(), icon.height.toDouble()),
    const Rect.fromLTWH(28, 19, 44, 44),
    Paint()..filterQuality = FilterQuality.medium,
  );
  _paintLabel(canvas, '框印工坊', const Rect.fromLTWH(85, 0, 124, 82),
      color: const Color(0xfff7f1e7));
  _paintLabel(canvas, presetName, const Rect.fromLTWH(400, 0, 332, 82),
      color: const Color(0xffe5c99c), align: TextAlign.right);
}

void _paintLabel(Canvas canvas, String text, Rect bounds,
    {required Color color, TextAlign align = TextAlign.left}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: 24, fontFamily: 'LCSourceSans'),
    ),
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: 1,
    ellipsis: '…',
  );
  try {
    painter.layout(minWidth: bounds.width, maxWidth: bounds.width);
    painter.paint(
        canvas, Offset(bounds.left, bounds.center.dy - painter.height / 2));
  } finally {
    painter.dispose();
  }
}

Future<ui.Image> _decodeImage(Uint8List bytes, {int? targetWidth}) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}
