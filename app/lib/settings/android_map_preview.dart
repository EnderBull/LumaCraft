import 'dart:io';

import '../export/android_photo_io.dart';
import 'amap_service.dart';
import 'app_settings.dart';
import 'map_page_server.dart';

Future<AppSettings> loadAndroidSettings() async {
  final path = await androidPlatform.invokeMethod<String>('settingsPath');
  final settings = AppSettings(File(path!));
  await settings.load();
  return settings;
}

Future<String?> showAndroidMap(String key, String secret,
    {bool selectPlace = false,
    bool dark = false,
    bool testConnection = false}) async {
  key = key.trim();
  secret = secret.trim();
  final offline = key.isEmpty && secret.isEmpty;
  if ((selectPlace || testConnection) && offline) {
    throw const FormatException('请先配置高德 Key 和安全密钥。');
  }
  final valid = RegExp(r'^[a-zA-Z0-9_-]+$');
  if (!offline && (!valid.hasMatch(key) || !valid.hasMatch(secret))) {
    throw const FormatException('请同时输入有效的高德 Key 和安全密钥，或将两栏留空。');
  }
  final server = MapPageServer();
  try {
    final page = offline
        ? """<!doctype html><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>STATE:已打开本机验证页</title>
<p>本机 WebView 通信验证</p>
<button onclick="document.title='PICK:1|验证坐标|116.397428,39.909230'">回传测试坐标</button>"""
        : buildMapPage(
            key: key,
            secret: secret,
            mobile: selectPlace || testConnection,
            testConnection: testConnection);
    final port = await server.start(page);
    if (port == null) throw StateError('无法启动本机地图页面');
    return await androidPlatform.invokeMethod<String>('map', {
      'url': 'http://127.0.0.1:$port/',
      'select': selectPlace,
      'testConnection': testConnection,
      'dark': dark,
    });
  } finally {
    await server.stop();
  }
}

Future<String?> testAndroidMapConnection(String key, String secret,
    {bool dark = false}) async {
  final result =
      await showAndroidMap(key, secret, testConnection: true, dark: dark);
  if (result == null) return null;
  if (result.startsWith('TEST_OK:')) return result.substring('TEST_OK:'.length);
  if (result.startsWith('TEST_FAIL:')) {
    throw FormatException(result.substring('TEST_FAIL:'.length));
  }
  throw const FormatException('未收到地图测试结果。');
}

Future<String?> pickAndroidPlace(String key, String secret,
    {bool dark = false}) async {
  final title =
      await showAndroidMap(key, secret, selectPlace: true, dark: dark);
  if (title == null) return null;
  final place = androidPlaceFromTitle(title);
  if (place == null) throw const FormatException('地图返回的地点无效。');
  return place;
}

String? androidPlaceFromTitle(String title) {
  if (!title.startsWith('PICK:') || title.length > 4096) return null;
  final start = title.indexOf('|');
  final end = title.lastIndexOf('|');
  if (start < 0 || end <= start) return null;
  final coordinates = title.substring(end + 1).trim();
  if (parseCoordinates(coordinates) == null) return null;
  final address = title.substring(start + 1, end).trim();
  return address.isEmpty ? coordinates : address;
}
