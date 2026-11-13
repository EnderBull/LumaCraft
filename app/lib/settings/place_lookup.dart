import 'package:flutter/foundation.dart';

import '../photo_state.dart';
import 'amap_service.dart';
import 'app_settings.dart';
import 'webview_geocoder.dart';

const gpsDiagnosticsEnabled = bool.fromEnvironment('LUMACRAFT_GPS_DIAGNOSTICS');

String gpsDiagnosticText(Map<String, String> info, {String? queryStatus}) {
  final value = info[gpsField];
  if (value == null || parseCoordinates(value) == null) return '未读到 GPS';
  return queryStatus == null ? '已读到 GPS' : '已读到 GPS · $queryStatus';
}

/// Fills a photo's place from its coordinates, when that is worth doing.
///
/// Only queries the map service when the style actually shows a place. A
/// preset without a location node gets nothing from a lookup, and every call
/// counts against the user's daily allowance, so the check comes first.
///
/// Results are cached for the session keyed by coordinates: moving between
/// photos taken at the same spot should not re-query.
class PlaceLookup {
  PlaceLookup({required this.settings, Geocoder? geocoder})
      : _geocoder = geocoder;

  final AppSettings settings;
  Geocoder? _geocoder;
  (String, String)? _credentials;

  /// One webview for the whole session, rebuilt only when the key changes.
  static WebviewGeocoder? _webview;
  static String _webviewKey = '';

  static Geocoder _shared(AppSettings settings) {
    final signature = '${settings.amapKey}\u0000${settings.amapSecret}';
    if (_webview == null || _webviewKey != signature) {
      final old = _webview;
      _webviewKey = signature;
      _webview =
          WebviewGeocoder(key: settings.amapKey, secret: settings.amapSecret);
      if (old != null) old.dispose();
    }
    return _webview!;
  }

  final _cache = <String, String>{};
  final _inFlight = <String, Future<String?>>{};
  Future<void> _lookupTail = Future.value();

  /// True when [nodeTypes] contains the location field.
  static bool styleUsesPlace(Iterable<String> nodeTypes) =>
      nodeTypes.contains('place');

  /// Returns a place name for [info], or null when there is nothing to do.
  ///
  /// [existing] is the current place value: a manual entry is never replaced.
  /// [nodeTypes] are the component types of the style applied to the photo.
  Future<String?> fill({
    required Map<String, String> info,
    required Iterable<String> nodeTypes,
    required String existing,
    VoidCallback? onQuery,
  }) async {
    if (!settings.autoFillPlace) return null;
    if (!settings.hasAmapCredentials) return null;
    if (existing.trim().isNotEmpty || (info['place'] ?? '').trim().isNotEmpty) {
      return null;
    }
    if (!styleUsesPlace(nodeTypes)) return null;
    final coordinates = info[gpsField];
    if (coordinates == null || parseCoordinates(coordinates) == null) {
      return null;
    }
    final credentials = (settings.amapKey, settings.amapSecret);
    if (_credentials != credentials) {
      _credentials = credentials;
      _cache.clear();
      _inFlight.clear();
    }
    if (_cache.containsKey(coordinates)) return _cache[coordinates];

    onQuery?.call();
    // One request per coordinate even if the screen asks twice while waiting.
    final pending = _inFlight[coordinates];
    if (pending != null) return pending;
    final future = _lookupTail.then((_) {
      if (_credentials != credentials ||
          !settings.autoFillPlace ||
          credentials != (settings.amapKey, settings.amapSecret)) {
        return null;
      }
      return _request(coordinates);
    });
    _lookupTail =
        future.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _inFlight[coordinates] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[coordinates], future)) {
        _inFlight.remove(coordinates);
      }
    }
  }

  Future<String?> _request(String coordinates) async {
    try {
      final credentials = _credentials;
      final result = await (_geocoder ?? _shared(settings)).lookup(coordinates);
      if (_credentials != credentials ||
          credentials != (settings.amapKey, settings.amapSecret)) {
        return null;
      }
      final address = result.address.trim();
      if (address.isEmpty) return null;
      _cache[coordinates] = address;
      return address;
    } on AmapException catch (e) {
      // A failed lookup must not disturb editing; the user can still type a
      // place by hand, and the reason is logged for diagnosis.
      debugPrint('place lookup failed: ${e.message}');
      return null;
    }
  }

  /// Swaps in a different geocoder; used by tests.
  @visibleForTesting
  void useGeocoder(Geocoder geocoder) => _geocoder = geocoder;

  /// Clears remembered answers, e.g. after the key changes.
  void forget() => _cache.clear();

  /// Releases the shared webview; called when the app closes.
  static Future<void> disposeShared() async {
    await _webview?.dispose();
    _webview = null;
    _webviewKey = '';
  }
}
