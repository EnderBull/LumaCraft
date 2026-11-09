import 'usage_data.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class WorkspaceSettings extends ChangeNotifier {
  final File file;
  WorkspaceSettings(this.file);
  double left = 216, right = 312, bottom = 154;
  bool sideFirst = false, dark = true, includeChildren = false;
  bool resizing = false;
  String? lastDirectory;
  final favorites = <String>{};
  Timer? _timer;
  Future<void> _pending = Future.value();
  String? saveError;

  Future<void> load() async {
    if (!await file.exists()) return;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (json['version'] != 1) throw const FormatException('不支持的工作台设置版本');
    double size(String key, double fallback, double min, double max) {
      final value = json[key];
      return value is num && value.isFinite
          ? value.toDouble().clamp(min, max)
          : fallback;
    }

    left = size('left', left, 160, 320);
    right = size('right', right, 260, 420);
    bottom = size('bottom', bottom, 132, 300);
    sideFirst = json['sideFirst'] == true;
    dark = json['dark'] != false;
    includeChildren = json['includeChildren'] == true;
    lastDirectory = json['lastDirectory'] as String?;
    if (json['favorites'] is List) {
      favorites
        ..clear()
        ..addAll((json['favorites'] as List).whereType<String>());
    }
  }

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
      'version': 1,
      'left': left,
      'right': right,
      'bottom': bottom,
      'sideFirst': sideFirst,
      'dark': dark,
      'includeChildren': includeChildren,
      'lastDirectory': lastDirectory,
      'favorites': favorites.toList()
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
    _timer?.cancel();
    super.dispose();
  }
}
