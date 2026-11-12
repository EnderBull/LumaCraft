import '../usage_data.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Settings that are not part of the workspace layout.
///
/// Kept separate from [WorkspaceSettings] because these are things the user
/// configures once about the app itself, not how the window is arranged. Also
/// because the map key must not sit in the same file that gets reset by the
/// "clear usage records" button.
class AppSettings extends ChangeNotifier {
  final File file;
  AppSettings(this.file);

  /// Amap key and security code, stored obfuscated (not plain text).
  ///
  /// This only stops someone from reading the file by accident. It is not
  /// strong protection: the key has to be usable by this program, so the
  /// program can always recover it.
  String amapKey = '';
  String amapSecret = '';

  /// Whether a photo's coordinates are used to fill the place field.
  bool autoFillPlace = true;
  String androidAppearance = 'system';

  Timer? _timer;
  Future<void> _pending = Future.value();
  String? saveError;

  static const _schemeVersion = 1;

  Future<void> load() async {
    if (!await file.exists()) return;
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return;
      amapKey = _decode(json['amapKey']);
      amapSecret = _decode(json['amapSecret']);
      autoFillPlace = json['autoFillPlace'] != false;
      final appearance = json['androidAppearance'];
      if (appearance == 'light' || appearance == 'dark') {
        androidAppearance = appearance as String;
      }
    } catch (_) {
      // A broken settings file must not stop the app from starting.
    }
  }

  /// Both values present is what the map needs; one alone is useless.
  bool get hasAmapCredentials =>
      amapKey.trim().isNotEmpty && amapSecret.trim().isNotEmpty;

  void changed() {
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () {
      save();
    });
  }

  Future<void> save() {
    _timer?.cancel();
    final data = jsonEncode({
      'version': _schemeVersion,
      'amapKey': _encode(amapKey),
      'amapSecret': _encode(amapSecret),
      'autoFillPlace': autoFillPlace,
      if (androidAppearance != 'system') 'androidAppearance': androidAppearance,
    });
    _pending = _pending.then((_) async {
      await UsageData.writeStringAtomic(file, data);
      saveError = null;
    }).catchError((Object e) {
      saveError = '设置保存失败：$e';
    });
    return _pending;
  }

  @override
  void dispose() {
    // A pending debounce means the last change never reached the disk. Flush
    // it here: closing the app right after editing a key would otherwise lose
    // the edit. The write is fire-and-forget because dispose cannot await.
    final pending = _timer?.isActive ?? false;
    _timer?.cancel();
    if (pending) unawaited(save());
    super.dispose();
  }

  /// Writes any pending change immediately and clears the timer.
  ///
  /// Used by the settings panel's save button, and by tests that need the
  /// timer gone before the widget is disposed.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    await save();
  }
}

/// Reversible obfuscation: every byte is XORed with a fixed pattern, then
/// base64'd. Deliberately not called encryption — anyone reading this source
/// can undo it. It keeps the key from being visible at a glance in the file.
String _encode(String value) {
  if (value.isEmpty) return '';
  final bytes = utf8.encode(value);
  final out = Uint8List(bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    out[i] = bytes[i] ^ _mask[i % _mask.length];
  }
  return base64UrlEncode(out);
}

String _decode(Object? value) {
  if (value is! String || value.isEmpty) return '';
  try {
    final bytes = base64Url.decode(base64Url.normalize(value));
    final out = Uint8List(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      out[i] = bytes[i] ^ _mask[i % _mask.length];
    }
    return utf8.decode(out);
  } catch (_) {
    return '';
  }
}

/// Fixed byte pattern for the obfuscation. Length is coprime with typical key
/// lengths so the pattern does not repeat in an obvious way.
final _mask = List<int>.generate(
    31, (i) => (0x5a + i * 37 + (i * i) % 11) & 0xff);

/// The random port a local map page will listen on. Kept here so the whitelist
/// hint and the server agree.
int pickLocalPort() {
  final random = Random();
  // A high, rarely used port; the exact number does not matter because the
  // Amap whitelist ignores ports.
  return 20000 + random.nextInt(20000);
}
