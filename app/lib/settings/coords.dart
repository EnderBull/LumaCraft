import 'dart:math' as math;

/// WGS-84 ↔ GCJ-02 conversion.
///
/// EXIF stores WGS-84, which is what GPS satellites report. Amap draws in
/// GCJ-02, a deliberately offset system used in mainland China. Using one
/// without converting to the other puts a point 300–500 m from where it
/// belongs, so every coordinate crossing between the two has to be converted.
///
/// The forward formula is public and accurate to 1–2 m. There is no closed
/// inverse, so [gcj02ToWgs84] iterates; six passes land under 0.5 m.
const _a = 6378245.0;
const _ee = 0.00669342162296594323;

/// True when the point is outside the offset region, where both systems agree.
bool outsideChina(double lng, double lat) =>
    !(lng > 73.66 && lng < 135.05 && lat > 3.86 && lat < 53.55);

double _transformLat(double x, double y) {
  var ret = -100.0 +
      2.0 * x +
      3.0 * y +
      0.2 * y * y +
      0.1 * x * y +
      0.2 * math.sqrt(x.abs());
  ret += (20.0 * math.sin(6.0 * x * math.pi) +
          20.0 * math.sin(2.0 * x * math.pi)) *
      2.0 /
      3.0;
  ret += (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) *
      2.0 /
      3.0;
  ret += (160.0 * math.sin(y / 12.0 * math.pi) +
          320 * math.sin(y * math.pi / 30.0)) *
      2.0 /
      3.0;
  return ret;
}

double _transformLng(double x, double y) {
  var ret = 300.0 +
      x +
      2.0 * y +
      0.1 * x * x +
      0.1 * x * y +
      0.1 * math.sqrt(x.abs());
  ret += (20.0 * math.sin(6.0 * x * math.pi) +
          20.0 * math.sin(2.0 * x * math.pi)) *
      2.0 /
      3.0;
  ret += (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) *
      2.0 /
      3.0;
  ret += (150.0 * math.sin(x / 12.0 * math.pi) +
          300.0 * math.sin(x / 30.0 * math.pi)) *
      2.0 /
      3.0;
  return ret;
}

/// EXIF coordinates → the ones Amap expects.
(double, double) wgs84ToGcj02(double lng, double lat) {
  if (outsideChina(lng, lat)) return (lng, lat);
  var dlat = _transformLat(lng - 105.0, lat - 35.0);
  var dlng = _transformLng(lng - 105.0, lat - 35.0);
  final radlat = lat / 180.0 * math.pi;
  var magic = math.sin(radlat);
  magic = 1 - _ee * magic * magic;
  final sqrtmagic = math.sqrt(magic);
  dlat = (dlat * 180.0) /
      ((_a * (1 - _ee)) / (magic * sqrtmagic) * math.pi);
  dlng = (dlng * 180.0) / (_a / sqrtmagic * math.cos(radlat) * math.pi);
  return (lng + dlng, lat + dlat);
}

/// Amap coordinates → the ones EXIF expects.
(double, double) gcj02ToWgs84(double lng, double lat) {
  if (outsideChina(lng, lat)) return (lng, lat);
  var wlng = lng, wlat = lat;
  for (var i = 0; i < 6; i++) {
    final (glng, glat) = wgs84ToGcj02(wlng, wlat);
    wlng += lng - glng;
    wlat += lat - glat;
  }
  return (wlng, wlat);
}
