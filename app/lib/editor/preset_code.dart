import 'dart:convert';
import 'dart:io';

import 'style_document.dart';

/// Shareable text form of one preset.
///
/// The `.lmp` file keeps every field so an older build can read it. A code
/// that travels by QR or chat has a hard size limit instead, so this drops
/// everything equal to the default and compresses the rest:
///
///   极简黑框  1474 chars as `.lmp` → 424 chars here
///   画廊签名  3761 chars as `.lmp` → 1104 chars here
///
/// Decoding starts from a blank document, so a dropped field comes back as
/// its default — the same value the encoder left out.
const presetCodePrefix = 'LC1:';

/// QR code payload limit for byte mode at error-correction level M.
///
/// 2953 bytes is the figure usually quoted, but that is level L. Level M
/// (the one used here, it survives a smudged print) tops out at 2331 bytes;
/// the qr package enforces that and rejects anything longer.
const presetCodeQrLimit = 2331;

/// Images are the only large part of a preset. Turning them off keeps the
/// placeholder and its size so the layout still looks right after import.
String encodePresetCode(StyleDocument style, {bool includeImages = false}) {
  final body = _encodeBody(style, includeImages: includeImages);
  final bytes = gzip.encode(utf8.encode(body));
  final payload = base64UrlEncode(bytes).replaceAll('=', '');
  return '$presetCodePrefix${_checksum(payload)}:$payload';
}

/// Bytes the code occupies. Used to decide whether a QR code fits.
int presetCodeBytes(String code) => utf8.encode(code).length;

/// True when the code is too large for a QR code, with the excess reported.
bool presetCodeTooLarge(String code) =>
    presetCodeBytes(code) > presetCodeQrLimit;

String _encodeBody(StyleDocument style, {required bool includeImages}) {
  final full = style.toJson();
  if (!includeImages) {
    for (final node in full['nodes'] as List) {
      if (node is Map && node['type'] == 'image' && node['image'] is Map) {
        (node['image'] as Map)['data'] = '';
      }
    }
  }
  // The name travels separately so a long name does not defeat compression.
  final name = style.name;
  full.remove('name');
  final diff = _difference(
      Map<String, dynamic>.from(full),
      Map<String, dynamic>.from(StyleDocument.template().toJson()..remove('name')));
  return jsonEncode({'n': name, 's': diff});
}

/// Keeps only what differs from the default. Maps recurse; anything else is
/// compared as a whole, which is what makes lists of nodes cheap to store.
Map<String, dynamic> _difference(
    Map<String, dynamic> current, Map<String, dynamic> base) {
  final out = <String, dynamic>{};
  for (final entry in current.entries) {
    final other = base[entry.key];
    final value = entry.value;
    if (value is Map && other is Map) {
      final nested = _difference(
          Map<String, dynamic>.from(value), Map<String, dynamic>.from(other));
      if (nested.isNotEmpty) out[entry.key] = nested;
    } else if (value is List && other is List) {
      // Keyed by index: a sparse list would lose which node each entry
      // belongs to, and node order must survive the round trip.
      final trimmed = <String, dynamic>{};
      for (var i = 0; i < value.length; i++) {
        final item = value[i];
        final twin = i < other.length ? other[i] : null;
        if (item is Map && twin is Map) {
          final nested = _difference(
              Map<String, dynamic>.from(item), Map<String, dynamic>.from(twin));
          if (nested.isNotEmpty) trimmed['$i'] = nested;
        } else if (item != twin) {
          trimmed['$i'] = item;
        }
      }
      if (trimmed.isNotEmpty || value.length < other.length)
        out[entry.key] = trimmed;
    } else if (value != other) {
      out[entry.key] = value;
    }
  }
  return out;
}

/// Rebuilds a document by applying a difference onto the blank template.
Map<String, dynamic> _apply(
    Map<String, dynamic> base, Map<String, dynamic> diff) {
  final out = Map<String, dynamic>.from(base);
  for (final entry in diff.entries) {
    final current = out[entry.key];
    final value = entry.value;
    if (value is Map && current is Map) {
      out[entry.key] =
          _apply(Map<String, dynamic>.from(current), Map<String, dynamic>.from(value));
    } else if (value is Map && current is List) {
      // Index-keyed difference against a shorter default list.
      final merged = <dynamic>[];
      final keys = value.keys.map((k) => int.tryParse('$k')).whereType<int>();
      final count = keys.isEmpty ? 0 : keys.reduce((a, b) => a > b ? a : b) + 1;
      for (var i = 0; i < count; i++) {
        final twin = i < current.length ? current[i] : null;
        final item = value['$i'];
        if (item is Map && twin is Map) {
          merged.add(_apply(
              Map<String, dynamic>.from(twin), Map<String, dynamic>.from(item)));
        } else if (item != null) {
          merged.add(item);
        } else if (twin != null) {
          merged.add(twin);
        }
      }
      out[entry.key] = merged;
    } else {
      out[entry.key] = value;
    }
  }
  return out;
}

StyleDocument decodePresetCode(String input) {
  final text = input.trim();
  if (!text.startsWith(presetCodePrefix))
    throw const FormatException('这不是 LumaCraft 预设代码，请检查是否复制完整');
  final rest = text.substring(presetCodePrefix.length);
  final cut = rest.indexOf(':');
  if (cut < 0) throw const FormatException('预设代码不完整，请重新复制');
  final checksum = rest.substring(0, cut), payload = rest.substring(cut + 1);
  if (payload.isEmpty) throw const FormatException('预设代码是空的，请重新复制');
  if (_checksum(payload) != checksum)
    throw const FormatException('预设代码有缺失或改动，请重新复制');
  late List<int> bytes;
  try {
    bytes = base64Url.decode(base64Url.normalize(payload));
  } catch (_) {
    throw const FormatException('预设代码格式不对，请重新复制');
  }
  Map<String, dynamic> body;
  try {
    body = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(gzip.decode(bytes))) as Map);
  } on FormatException {
    throw const FormatException('预设代码已损坏，请重新复制');
  } catch (_) {
    throw const FormatException('预设代码已损坏，请重新复制');
  }
  final name = body['n'];
  if (name is! String || name.trim().isEmpty || name.length > 200)
    throw const FormatException('预设代码里的名称无效');
  if (body['s'] is! Map) throw const FormatException('预设代码缺少样式内容');
  final base = Map<String, dynamic>.from(StyleDocument.template().toJson());
  final merged = _apply(base, Map<String, dynamic>.from(body['s'] as Map));
  merged['name'] = name;
  // Version and shape still go through the normal reader, so a code built by
  // a newer build is rejected with the same wording as a `.lmp` file.
  return StyleDocument.fromJson(merged);
}

/// Short, stable fingerprint of the payload so a truncated paste is caught
/// before it becomes a confusing parse error.
String _checksum(String payload) {
  var hash = 0x811c9dc5;
  for (final unit in utf8.encode(payload)) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(36).padLeft(7, '0');
}

