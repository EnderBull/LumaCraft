import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/workspace_settings.dart';

void main() {
  test('全新安装：默认不收藏任何预设', () async {
    final dir = Directory.systemTemp.createTempSync('lc-fav');
    addTearDown(() => dir.deleteSync(recursive: true));
    final settings = WorkspaceSettings(File('${dir.path}/workspace.json'));
    await settings.load();
    expect(settings.favorites, isEmpty);
  });

  test('已保存过收藏的用户，收藏保持原样', () async {
    final dir = Directory.systemTemp.createTempSync('lc-fav');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/workspace.json');
    file.writeAsStringSync(jsonEncode({
      'version': 1,
      'favorites': ['gallery']
    }));
    final settings = WorkspaceSettings(file);
    await settings.load();
    expect(settings.favorites, {'gallery'});
  });
}
