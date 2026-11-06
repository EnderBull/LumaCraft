import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Reads a QR code out of a picture.
///
/// Used for "import from a shared image": the panel draws a QR code into the
/// saved PNG, so the receiving side only has to pick that picture. No camera
/// is involved, which suits a desktop where the picture arrived by chat.
///
/// Returns null when nothing readable is found — a picture cropped too tight,
/// one with no code, or one too blurred. Callers turn that into a plain
/// message rather than an error.
///
/// Why the preprocessing matters: a saved panel is ~2200 px wide, the code
/// sits on a rounded white card, and a long preset makes the code very dense
/// (100+ modules). Scanning that picture as-is fails, even though a phone reads
/// the same code instantly. Measured on a real 1086-character code:
///   whole picture as-is              → not found
///   bright area only                 → not found
///   code trimmed + white border + resize → found, every time
/// So the picture is reduced to the code itself, given a clean quiet zone and
/// an integer module grid, which is what the decoder needs.
String? scanQrCode(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  // The code's dark modules sit inside a light card. Their bounding box is the
  // code, without the rounded card corners that confuse the locator.
  final body = _cropToCode(decoded);
  if (body == null) return null;

  // A clean quiet zone: the card's rounded corners leave dark wedges that the
  // locator mistakes for part of the pattern.
  for (final padding in [16, 32, 8, 64]) {
    final padded = _padWhite(body, padding);
    // Resizing changes the module grid; a whole-pixel grid decodes far more
    // reliably than fractional module edges, so several sizes are tried.
    for (final target in _sizeLadder(padded)) {
      final picture = target == padded.width
          ? padded
          : img.copyResize(padded,
              width: target,
              height: target,
              interpolation: target > padded.width
                  ? img.Interpolation.nearest
                  : img.Interpolation.average);
      final text = _read(picture);
      if (text != null) return text;
    }
  }
  return null;
}

/// Widths worth trying, from the natural size down. 734 is the value that
/// worked on the real capture; the others cover other card sizes.
List<int> _sizeLadder(img.Image padded) {
  final base = padded.width;
  final sizes = <int>{
    base,
    (base * .68).round(),
    734,
    (base * .5).round(),
    (base * 1.5).round(),
  };
  return [
    for (final size in sizes)
      if (size >= 200 && size <= 4000) size
  ];
}

/// Bounding box of the dark modules.
///
/// Every pixel is examined, not a sample: a sampled scan misses the outermost
/// dark modules and the box comes out a few pixels small, which shifts the
/// module grid and stops the decoder from reading it.
///
/// Two passes, because a share panel puts the code on the right while a plain
/// crop of one puts it anywhere:
///  1. the right-hand half, which avoids the photo on the left of a panel;
///  2. the whole picture, for a picture that holds only the code.
img.Image? _cropToCode(img.Image source) {
  // Skip a thin border: the panel's own edge is dark.
  final insetX = (source.width * .04).round();
  final insetY = (source.height * .06).round();
  for (final fromX in [source.width ~/ 2, 0]) {
    final box = _darkBounds(source, fromX, source.width - insetX,
        insetY, source.height - insetY);
    if (box != null) return box;
  }
  return null;
}

/// Tightest box around pixels darker than the panel, or null when the box does
/// not look like a single square code.
img.Image? _darkBounds(
    img.Image source, int fromX, int toX, int fromY, int toY) {
  const threshold = 100;
  var minX = toX, minY = toY, maxX = -1, maxY = -1;
  for (var y = fromY; y < toY; y++) {
    for (var x = fromX; x < toX; x++) {
      if (_luma(source.getPixel(x, y)) > threshold) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX <= minX || maxY <= minY) return null;
  final width = maxX - minX + 1, height = maxY - minY + 1;
  if (width < 40 || height < 40) return null;
  // A code is square. Anything far from that is not a single code — for
  // example a photo, or a dark panel edge picked up by the threshold.
  final ratio = width / height;
  if (ratio < .75 || ratio > 1.33) return null;
  return img.copyCrop(source, x: minX, y: minY, width: width, height: height);
}

img.Image _padWhite(img.Image src, int pad) {
  final out = img.Image(
      width: src.width + pad * 2, height: src.height + pad * 2);
  img.fill(out, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(out, src, dstX: pad, dstY: pad);
  return out;
}

int _luma(img.Pixel pixel) =>
    (pixel.r.toInt() * 299 + pixel.g.toInt() * 587 + pixel.b.toInt() * 114) ~/
    1000;

/// Tries both binarizers. The hybrid one handles the low-contrast or uneven
/// edges that a rescaled capture produces; the histogram one is faster and
/// succeeds on clean pictures.
String? _read(img.Image picture) {
  final pixels = Int32List(picture.width * picture.height);
  var i = 0;
  for (final pixel in picture) {
    pixels[i++] =
        (pixel.r.toInt() << 16) | (pixel.g.toInt() << 8) | pixel.b.toInt();
  }
  for (final hybrid in [true, false]) {
    try {
      final source =
          RGBLuminanceSource(picture.width, picture.height, pixels);
      final binarizer =
          hybrid ? HybridBinarizer(source) : GlobalHistogramBinarizer(source);
      final text = QRCodeReader().decode(BinaryBitmap(binarizer)).text;
      if (text.isNotEmpty) return text;
    } catch (_) {
      // Not found is the normal outcome; try the next setting.
    }
  }
  return null;
}
