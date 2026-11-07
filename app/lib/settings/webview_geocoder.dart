import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import 'amap_service.dart';
import 'coords.dart';
import 'map_page_server.dart';

/// Geocoder that runs Amap's JavaScript in a hidden webview.
///
/// The map script has to be loaded by a browser page. A controller with no
/// [Webview] widget in the tree still runs scripts, so no extra UI is needed —
/// but it must be given a size, because a page does not lay out (and therefore
/// does not run) until it has nonzero bounds.
///
/// One instance is kept for the session: loading the map script costs much more
/// than a lookup, and the settings panel may query repeatedly.
///
/// The answer comes back either as a JSON message from the page or, if
/// messaging is unavailable, from the document title. Both are watched so a
/// missing channel cannot leave the caller waiting for nothing.
class WebviewGeocoder implements Geocoder {
  WebviewGeocoder({required this.key, required this.secret});

  final String key, secret;

  final _server = MapPageServer();
  WebviewController? _controller;
  Future<void>? _starting;
  Completer<PlaceResult>? _pending;

  static const _okPrefix = 'GEOCODE:';
  static const _errorPrefix = 'GEOCODE_ERR:';

  @override
  Future<PlaceResult> lookup(String location) async {
    final coordinates = parseCoordinates(location);
    if (coordinates == null)
      throw const AmapException('照片里的坐标无效，无法查询地点');
    if (_pending != null)
      throw const AmapException('正在查询上一个地点，请稍等');

    await _ensureStarted();
    // EXIF holds WGS-84; Amap answers in its own offset system, so the
    // coordinate handed to the map has to be converted or the address comes
    // back from a spot 300–500 m away.
    final (lng, lat) = wgs84ToGcj02(coordinates.$1, coordinates.$2);
    final completer = Completer<PlaceResult>();
    _pending = completer;
    try {
      await _controller!.executeScript(
          'window.__geocode && window.__geocode($lng, $lat);');
      return await _poll(completer);
    } finally {
      _pending = null;
    }
  }

  /// Confirms the map script loads, which is what the key and whitelist gate.
  ///
  /// This is the same check the reference tool makes: it proves the key, the
  /// whitelist and the network all work, without depending on a lookup
  /// answering within a deadline.
  Future<void> testConnection() async {
    await _ensureStarted();
    final value = await _safeType(_controller!);
    if (!value.contains('function')) {
      throw const AmapException(
          '地图脚本没有加载完成。请确认 Key 是「Web端(JS API)」类型，且域名白名单填了 127.0.0.1');
    }
  }

  /// Waits for the page to answer, checking the title as a fallback.
  Future<PlaceResult> _poll(Completer<PlaceResult> completer) async {
    final clock = Stopwatch()..start();
    while (clock.elapsed < const Duration(seconds: 12)) {
      if (completer.isCompleted) return completer.future;
      // A message may have arrived while we were waiting.
      if (_pending == null) break;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (completer.isCompleted) return completer.future;
      final title = await _readTitle();
      if (title == null) continue;
      if (title.startsWith(_okPrefix)) {
        final address = title.substring(_okPrefix.length).trim();
        if (address.isNotEmpty) return PlaceResult(address);
      } else if (title.startsWith(_errorPrefix)) {
        throw AmapException(title.substring(_errorPrefix.length).trim());
      }
    }
    if (completer.isCompleted) return completer.future;
    throw const AmapException('查询地点超时。请确认网络能访问高德，以及 Key 是「Web端(JS API)」类型');
  }

  Future<String?> _readTitle() async {
    try {
      final value = await _controller?.executeScript('document.title');
      return value?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureStarted() async {
    if (_controller != null) return;
    final starting = _starting;
    if (starting != null) return starting;
    final future = () async {
      final port = await _server.start(
          buildGeocodePage(key: key, secret: secret),
          path: '/geocode.html');
      if (port == null)
        throw const AmapException('本地服务启动失败，请重启软件后重试');
      final controller = WebviewController();
      await controller.initialize();
      // Headless controllers get no bounds from a widget, and a page with no
      // size never lays out — its scripts simply do not run. This is the line
      // whose absence made every lookup time out.
      await controller.setSize(const Size(900, 700));
      controller.webMessage.listen(_onMessage);
      await controller.loadUrl('http://127.0.0.1:$port/geocode.html');

      // Wait until the page has defined its helper; a lookup before that would
      // run against nothing.
      var ready = false;
      for (var i = 0; i < 60 && !ready; i++) {
        final type = await _safeType(controller);
        ready = type.contains('function');
        if (!ready) await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!ready) {
        throw const AmapException(
            '地图脚本没有加载完成。请确认 Key 是「Web端(JS API)」类型，且域名白名单填了 127.0.0.1');
      }
      _controller = controller;
    }();
    _starting = future;
    try {
      await future;
    } finally {
      _starting = null;
    }
  }

  Future<String> _safeType(WebviewController controller) async {
    try {
      final value = await controller.executeScript('typeof window.__geocode');
      return value?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  void _onMessage(dynamic message) {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    Object? decoded;
    try {
      decoded = message is String ? jsonDecode(message) : message;
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    final ok = decoded['ok'];
    if (ok is String && ok.trim().isNotEmpty) {
      pending.complete(PlaceResult(ok.trim()));
      return;
    }
    final error = decoded['error'];
    pending.completeError(AmapException(
        error is String && error.isNotEmpty ? error : '这个位置查不到地址'));
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    await _server.stop();
  }
}
