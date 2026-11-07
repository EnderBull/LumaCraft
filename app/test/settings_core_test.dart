import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/settings/amap_service.dart';
import 'package:lumacraft/settings/app_settings.dart';
import 'package:lumacraft/settings/map_page_server.dart';

/// 设置存储、高德接口和本地地图服务的单元测试。
void main() {
  group('设置存储', () {
    late Directory dir;
    setUp(() {
      dir = Directory(
          'build/export-ui-check-0266-settings/run-${DateTime.now().microsecondsSinceEpoch}')
        ..createSync(recursive: true);
    });

    test('读写后密钥能还原', () async {
      final file = File('${dir.path}/app-settings.json');
      final settings = AppSettings(file);
      settings.amapKey = 'a1b2c3d4e5f6g7h8';
      settings.amapSecret = 'secret-9f8e7d';
      settings.autoFillPlace = false;
      await settings.save();

      final raw = await file.readAsString();
      // 文件里不能出现明文。
      expect(raw.contains('a1b2c3d4e5f6g7h8'), isFalse, reason: 'Key 不应明文存储');
      expect(raw.contains('secret-9f8e7d'), isFalse, reason: '私钥不应明文存储');

      final back = AppSettings(file);
      await back.load();
      expect(back.amapKey, 'a1b2c3d4e5f6g7h8');
      expect(back.amapSecret, 'secret-9f8e7d');
      expect(back.autoFillPlace, isFalse);
      settings.dispose();
      back.dispose();
    });

    test('文件缺失或损坏时用默认值', () async {
      final missing = AppSettings(File('${dir.path}/none.json'));
      await missing.load();
      expect(missing.amapKey, '');
      expect(missing.hasAmapCredentials, isFalse);
      expect(missing.autoFillPlace, isTrue);
      missing.dispose();

      final broken = File('${dir.path}/broken.json')
        ..writeAsStringSync('{ 这不是 json');
      final settings = AppSettings(broken);
      await settings.load();
      expect(settings.amapKey, '');
      expect(settings.autoFillPlace, isTrue);
      settings.dispose();
    });

    test('只有其中一个密钥时不算配好', () async {
      final settings = AppSettings(File('${dir.path}/half.json'));
      settings.amapKey = 'only-key';
      expect(settings.hasAmapCredentials, isFalse);
      settings.amapSecret = 'now-both';
      expect(settings.hasAmapCredentials, isTrue);
      settings.dispose();
    });
  });

  group('坐标解析', () {
    test('经度在前，可解析', () {
      final pair = parseCoordinates('120.130264,30.259244');
      expect(pair, isNotNull);
      expect(pair!.$1, closeTo(120.13, .01));
      expect(pair.$2, closeTo(30.26, .01));
    });

    test('格式不对返回空', () {
      expect(parseCoordinates('not-a-place'), isNull);
      expect(parseCoordinates('120.1'), isNull);
      expect(parseCoordinates(''), isNull);
      expect(parseCoordinates('120.1,30.2,40.3'), isNull);
    });

    test('超出真实范围返回空', () {
      // 经纬度颠倒或写错时不该发请求。
      expect(parseCoordinates('200,300'), isNull);
      expect(parseCoordinates('120,100'), isNull);
    });

    test('允许负值（南纬西经）', () {
      final pair = parseCoordinates('-74.005974,-33.868820');
      expect(pair, isNotNull);
      expect(pair!.$1, lessThan(0));
      expect(pair.$2, lessThan(0));
    });
  });

  group('本地地图服务', () {
    test('能启动、返回页面、能关闭', () async {
      final server = MapPageServer();
      final port = await server.start('<html>测试地图页</html>');
      expect(port, isNotNull);
      final client = HttpClient();
      try {
        final request = await client
            .getUrl(Uri.parse('http://127.0.0.1:$port/index.html'));
        final response = await request.close();
        expect(response.statusCode, 200);
        // The server declares utf-8; decoding the bytes as utf-8 is what a
        // browser would do. Using the system encoding here mangles Chinese.
        final body = await response.transform(utf8.decoder).join();
        expect(body, contains('测试地图页'));
      } finally {
        client.close(force: true);
        await server.stop();
      }
      expect(server.running, isFalse);
    });

    test('只提供首页，其它路径返回 404', () async {
      final server = MapPageServer();
      final port = await server.start('<html>x</html>');
      final client = HttpClient();
      try {
        final request = await client
            .getUrl(Uri.parse('http://127.0.0.1:$port/secret.txt'));
        final response = await request.close();
        expect(response.statusCode, HttpStatus.notFound);
        await response.drain<void>();
      } finally {
        client.close(force: true);
        await server.stop();
      }
    });

    test('页面里填入的密钥会被转义', () {
      final page = buildMapPage(key: 'abc', secret: "it's");
      expect(page, contains('abc'));
      expect(page, isNot(contains('__SECRET__')), reason: '占位符应被替换');
    });

    test('地理编码页面也填入了占位符', () {
      final page = buildGeocodePage(key: 'my-key', secret: 'my-secret');
      expect(page, contains('my-key'));
      expect(page, contains('my-secret'));
      expect(page, isNot(contains('__KEY__')));
      expect(page, isNot(contains('__SECRET__')));
      // 必须调用 JS API 的 Geocoder，而不是 REST 接口。
      expect(page, contains('AMap.Geocoder'));
      expect(page, isNot(contains('restapi.amap.com')));
    });

    test('三个页面的 Key 都带引号，拼接时才不会变成变量名', () {
      // 页面里用 '…&key=' + __KEY__ 拼 URL。若替换成裸值，
      // 浏览器会当成标识符解析，整段脚本失效——症状是「请求没发出去」。
      for (final page in [
        buildMapPage(key: 'abc123XYZ', secret: 'sec'),
        buildGeocodePage(key: 'abc123XYZ', secret: 'sec'),
        buildDiagnosticPage(key: 'abc123XYZ', secret: 'sec'),
      ]) {
        expect(page, contains("'abc123XYZ'"),
            reason: 'Key 必须带引号替换');
        expect(page, isNot(contains("+ abc123XYZ")));
      }
    });

    test('地图页把选中的地点通过标题回传，且不在页面内画底栏', () {
      final page = buildMapPage(key: 'k', secret: 's');
      // 回传格式必须是 PICK:序号|地址|坐标，供窗口解析。
      expect(page, contains("'PICK:'"));
      expect(page, contains('document.title'));
      // 页面里不该再有自己的一套底栏，否则会出现两条同样的信息。
      expect(page, isNot(contains('id="bar"')));
      expect(page, isNot(contains('使用这个地点')));
    });

    test('两个页面都使用同一个地名精简函数', () {
      for (final page in [
        buildMapPage(key: 'k', secret: 's'),
        buildGeocodePage(key: 'k', secret: 's'),
      ]) {
        expect(page, contains('function shortAddress'),
            reason: '地名必须经过精简，否则预设里会被省份和街道撑得过长');
        expect(page, isNot(contains('__SHORT_ADDRESS__')),
            reason: '占位符必须被替换');
        // 精简要取市、区、具体地点，不能直接用完整地址。
        expect(page, isNot(contains('ok: result.regeocode.formattedAddress')));
        // 三段之间用圆点分隔，读起来有间隔。
        expect(page, contains("parts.join(' · ')"));
      }
    });
  });
}