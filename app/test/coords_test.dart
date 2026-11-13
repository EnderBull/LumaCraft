import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/settings/coords.dart';
import 'package:lumacraft/settings/map_page_server.dart';

/// 坐标系转换：EXIF 用 WGS-84，高德用 GCJ-02，不转会偏 300–500 米。
void main() {
  test('生成的查询页面同时回传标题，并能直接查询指定坐标', () {
    final page = buildGeocodePage(
        key: 'test-key', secret: 'test-secret', initial: (120.1, 30.2));
    expect(page, contains("securityJsCode: 'test-secret'"));
    expect(page, contains(" + 'test-key';"));
    expect(page, contains("document.title = payload.ok ? 'GEOCODE:'"));
    expect(page, contains('window.__geocode(120.1, 30.2);'));
    expect(page, isNot(contains('__INITIAL_LOOKUP__')));
    // ignore: avoid_print
    print(page
        .split('\n')
        .where((line) =>
            line.contains('document.title') ||
            line.contains('securityJsCode') ||
            line.contains('script.src') ||
            line.contains('120.1, 30.2'))
        .join('\n'));
  });
  test('天安门：WGS-84 转 GCJ-02 有明显偏移', () {
    // 天安门的 WGS-84 与高德坐标（GCJ-02）实测值。
    const lng = 116.39123, lat = 39.90728;
    final (glng, glat) = wgs84ToGcj02(lng, lat);
    // 偏移量级：经度约 0.0056，纬度约 0.0027。
    expect((glng - lng).abs(), greaterThan(0.003), reason: '不做转换会有数百米偏差');
    expect((glat - lat).abs(), greaterThan(0.001));
  });

  test('往返转换能回到原点', () {
    const lng = 120.130264, lat = 30.259244; // 西湖
    final (glng, glat) = wgs84ToGcj02(lng, lat);
    final (wlng, wlat) = gcj02ToWgs84(glng, glat);
    expect(wlng, closeTo(lng, 0.00002));
    expect(wlat, closeTo(lat, 0.00002));
  });

  test('国外坐标不做偏移', () {
    // 悉尼不在偏移范围内，必须原样返回。
    const lng = 151.209290, lat = -33.868820;
    expect(outsideChina(lng, lat), isTrue);
    final (glng, glat) = wgs84ToGcj02(lng, lat);
    expect(glng, lng);
    expect(glat, lat);
  });

  test('偏移量在合理范围（不超过 1 公里）', () {
    for (final point in [
      [116.39123, 39.90728], // 北京
      [121.4737, 31.2304], // 上海
      [113.2644, 23.1291], // 广州
      [87.6168, 43.8256], // 乌鲁木齐
    ]) {
      final (glng, glat) = wgs84ToGcj02(point[0], point[1]);
      // 1 度纬度约 111 km，0.008 度约 890 米。
      expect((glat - point[1]).abs(), lessThan(0.008));
      expect((glng - point[0]).abs(), lessThan(0.008));
    }
  });
}
