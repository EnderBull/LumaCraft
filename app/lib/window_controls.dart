import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class DesktopWindow {
  static final maximized = ValueNotifier<bool>(false);
  static const channel = MethodChannel('lumacraft/window');
  static Future<bool> wheelAltPressed() async {
    if (Platform.isWindows) {
      try {
        return await channel.invokeMethod<bool>('altPressed') == true;
      } on MissingPluginException {
        // Widget tests have no native window channel.
      }
    }
    return HardwareKeyboard.instance.isAltPressed;
  }

  static Future<void> action(String method, [String? edge]) async {
    if (Platform.isWindows) await channel.invokeMethod<void>(method, edge);
  }
}
