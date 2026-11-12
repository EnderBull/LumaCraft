import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/editor/builtin_library.dart';
import 'package:lumacraft/fonts/font_catalog.dart';
import 'package:lumacraft/ui/android/preset_demo_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render all Android built-in preset previews', () async {
    for (final font in artworkFonts) {
      await (FontLoader(font.family)..addFont(rootBundle.load(font.asset)))
          .load();
    }
    final library =
        BuiltinLibrary.decode(await rootBundle.loadString(bundledBuiltinAsset));
    final output =
        await Directory(builtinDemoDirectory).create(recursive: true);
    expect(library.entries, isNotEmpty);
    for (final entry in library.entries) {
      final png = await renderPresetDemo(entry.style);
      expect(png, isNotEmpty, reason: entry.id);
      await File('${output.path}/${entry.id}.png').writeAsBytes(png);
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
