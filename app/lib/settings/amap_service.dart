import 'dart:async';

/// Result of a place lookup.
class PlaceResult {
  final String address;
  const PlaceResult(this.address);
}

/// Failure with a message already written for the user.
class AmapException implements Exception {
  final String message;
  const AmapException(this.message);
  @override
  String toString() => message;
}

/// "longitude,latitude" → a pair, or null when the text is not usable.
///
/// Amap wants longitude first; the map service rejects values outside the real
/// ranges, so those are caught here rather than at the network.
(double, double)? parseCoordinates(String value) {
  final parts = value.split(',');
  if (parts.length != 2) return null;
  final lon = double.tryParse(parts[0].trim());
  final lat = double.tryParse(parts[1].trim());
  if (lon == null || lat == null) return null;
  if (!lon.isFinite || !lat.isFinite) return null;
  if (lon.abs() > 180 || lat.abs() > 90) return null;
  return (lon, lat);
}

/// Turns coordinates into an address.
///
/// Everything goes through the Amap JS API, because a JS API key and a Web
/// service key are different products: the REST reverse geocoding endpoint
/// refuses a JS API key with "platform mismatch", while the map refuses a web
/// service key. One API means the user applies for one key.
///
/// Implementations: [WebviewGeocoder] for the app, [FakeGeocoder] for tests.
abstract class Geocoder {
  Future<PlaceResult> lookup(String location);
  Future<void> dispose() => Future.value();
}

/// Answers lookups from a supplied function; used by tests.
class FakeGeocoder implements Geocoder {
  FakeGeocoder(this.answer, {this.failWith});
  final Future<PlaceResult> Function(String location) answer;

  /// When set, every lookup throws this message instead.
  final String? failWith;

  var calls = 0;
  final queried = <String>[];

  @override
  Future<PlaceResult> lookup(String location) async {
    if (parseCoordinates(location) == null)
      throw const AmapException('照片里的坐标无效，无法查询地点');
    calls++;
    queried.add(location);
    final error = failWith;
    if (error != null) throw AmapException(error);
    return answer(location);
  }

  @override
  Future<void> dispose() async {}
}
