import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Serves the map page over http://127.0.0.1 so the Amap script can load.
///
/// Amap rejects pages opened from file:// when a domain whitelist is set, so
/// the page has to come from a real http origin. Serving it on the loopback
/// address means the whitelist entry "127.0.0.1" matches, and ports are
/// ignored by the whitelist, so the port can change freely.
class MapPageServer {
  HttpServer? _server;
  int? _port;
  String _page = '';
  String _path = '/';

  int? get port => _port;
  bool get running => _server != null;

  /// Starts listening and serves [page] at [path].
  ///
  /// The page is given up front because it carries the user's key; rebuilding
  /// it per request would mean reading settings inside the server.
  Future<int?> start(String page, {String path = '/'}) async {
    if (_server != null) {
      _page = page;
      _path = path;
      return _port;
    }
    _page = page;
    _path = path;
    for (var attempt = 0; attempt < 8; attempt++) {
      final candidate = 20000 + (DateTime.now().microsecondsSinceEpoch % 20000);
      try {
        final server =
            await HttpServer.bind(InternetAddress.loopbackIPv4, candidate);
        _server = server;
        _port = candidate;
        _serve(server);
        return candidate;
      } on SocketException {
        // Port taken; try another. The whitelist ignores ports, so this is
        // transparent to the user.
        continue;
      }
    }
    return null;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
  }

  void _serve(HttpServer server) {
    server.listen((request) async {
      final response = request.response;
      // Only the served page is exposed; nothing else is reachable.
      if (request.uri.path != _path &&
          !(request.uri.path == '/index.html' && _path == '/')) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      response.headers.contentType =
          ContentType('text', 'html', charset: 'utf-8');
      // No caching: a changed key must take effect on reload.
      response.headers.set('Cache-Control', 'no-store');
      response.write(_page);
      await response.close();
    }, onError: (Object error) {
      debugPrint('map page server error: $error');
    });
  }
}

/// Page that shows a map, offers a search box, and reports the chosen place.
///
/// Notes that cost real debugging time:
///  * The script is loaded dynamically and the map is built inside a timer: a
///    stall inside AMap otherwise takes the whole script down, timers included,
///    so nothing can report what happened.
///  * AMap 1.4 is used rather than 2.0, which needs WebGL. Inside a webview
///    composited as a texture the GPU context can fail and the constructor then
///    never returns.
///  * Clicks are read from both the map's own event and a native DOM listener:
///    only one of them proves reliable here, and both give the same answer.
String buildMapPage({required String key, required String secret}) => '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>map</title>
<style>
  html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden;
               font-family: "Microsoft YaHei UI", "Microsoft YaHei", sans-serif; }
  /* No bottom bar in the page: the dialog draws the only footer, so the two
     bars that used to show the same text are gone. The map fills everything. */
  #map { position: absolute; top: 0; left: 0; right: 0; bottom: 0; background: #f2f2f2; }
  #search { position: absolute; top: 12px; left: 12px; right: 12px; z-index: 20;
            display: flex; gap: 8px; }
  #q { flex: 1; height: 38px; box-sizing: border-box; padding: 0 12px; font-size: 13px;
       border: 1px solid #ddd; border-radius: 6px; background: #fff; color: #333;
       box-shadow: 0 2px 8px rgba(0,0,0,.12); outline: none; }
  #go { height: 38px; padding: 0 16px; border-radius: 6px; border: none; cursor: pointer;
        background: #dfa653; color: #2a1d0d; font-size: 13px; font-weight: 500;
        box-shadow: 0 2px 8px rgba(0,0,0,.12); }
  #results { position: absolute; top: 56px; left: 12px; right: 12px; z-index: 21;
             background: #fff; border-radius: 6px; box-shadow: 0 4px 16px rgba(0,0,0,.18);
             overflow: hidden; display: none; max-height: 220px; overflow-y: auto; }
  .item { padding: 10px 12px; font-size: 13px; color: #333; cursor: pointer;
          border-bottom: 1px solid #f0f0f0; line-height: 1.4; }
  .item:hover { background: #f7f4ef; }
</style>
</head>
<body>
<div id="map"></div>
<div id="search">
  <input id="q" type="text" placeholder="搜索地点，例如：西湖" spellcheck="false">
  <button id="go">搜索</button>
</div>
<div id="results"></div>
<script>
(function () {
  var inputEl = document.getElementById('q');
  var resultsEl = document.getElementById('results');

  var map = null, marker = null, geocoder = null, placeSearch = null;
  var chosen = null;   // { lng, lat, address }

  // The dialog owns the only footer, so progress and results travel through the
  // document title: "STATE:<text>" for progress, "PICK:<counter>|<address>|
  // <lng>,<lat>" once a point is chosen. A counter keeps repeated picks of the
  // same place distinguishable, since an unchanged title raises no event.
  var seq = 0;
  function state(text) { document.title = 'STATE:' + text; }
  function report(lng, lat, address) {
    seq = seq + 1;
    document.title = 'PICK:' + seq + '|' + address + '|'
        + lng.toFixed(6) + ',' + lat.toFixed(6);
  }

  state('正在请求地图脚本…');

  window._AMapSecurityConfig = { securityJsCode: __SECRET__ };
  var script = document.createElement('script');
  script.src = 'https://webapi.amap.com/maps?v=1.4.15&key=' + __KEY__;
  script.onload = function () {
    if (!window.AMap) { state('脚本已返回，但地图组件未创建，请检查 Key'); return; }
    state('地图脚本已加载，正在创建地图…');
    // Plugins are loaded explicitly. Passing them in the URL alone did not
    // reliably register them, and a missing AMap.PlaceSearch threw inside
    // createMap — which aborted the rest of the setup, so the search box and
    // the map click ended up with no handlers at all while the map still drew.
    try {
      AMap.plugin(['AMap.Geocoder', 'AMap.PlaceSearch'], function () {
        setTimeout(createMap, 50);
      });
    } catch (e) {
      state('加载地图组件失败：' + (e && e.message ? e.message : e));
    }
  };
  script.onerror = function () { state('地图脚本请求失败，请检查网络'); };
  document.head.appendChild(script);

  var settled = false;
  setTimeout(function () {
    if (settled) return;
    var box = document.getElementById('map');
    if (box.querySelector('canvas, img, .amap-layer, .amap-tile')) {
      settled = true;
      state('地图已加载，可以搜索或点击选点');
      return;
    }
    state('⚠ 15 秒内地图没有出现');
  }, 15000);

  function createMap() {
    var box = document.getElementById('map');
    var w = box.clientWidth, h = box.clientHeight;
    if (w < 10 || h < 10) { setTimeout(createMap, 400); return; }
    // Everything below is wrapped: an exception halfway through used to leave
    // the map drawn but with no search and no click handler, and nothing said
    // why. Now the failing step is named on screen.
    try {
      map = new AMap.Map('map', {
        zoom: 12,
        center: [116.397428, 39.90923],
        resizeEnable: true
      });
      geocoder = new AMap.Geocoder({ radius: 1000, extensions: 'base' });
      placeSearch = new AMap.PlaceSearch({ pageSize: 8, extensions: 'base' });

      map.on('click', function (e) {
        choose(e.lnglat.getLng(), e.lnglat.getLat());
      });
      box.addEventListener('click', function (ev) {
        var rect = box.getBoundingClientRect();
        var px = new AMap.Pixel(ev.clientX - rect.left, ev.clientY - rect.top);
        var ll = map.containerToLngLat(px);
        if (ll) choose(ll.getLng(), ll.getLat());
      });

      document.getElementById('go').onclick = search;
      inputEl.onkeydown = function (e) { if (e.key === 'Enter') search(); };

      setTimeout(function () { try { map.resize(); } catch (e) {} }, 300);

      var polls = 0;
      var watch = setInterval(function () {
        if (settled) { clearInterval(watch); return; }
        if (box.querySelector('canvas, img, .amap-layer, .amap-tile')) {
          clearInterval(watch); settled = true;
          state('地图已加载，可以搜索或点击选点');
          return;
        }
        if (++polls > 36) { clearInterval(watch); state('地图对象在，但画面没出来'); }
      }, 250);
    } catch (e) {
      state('初始化失败：' + (e && e.message ? e.message : e));
    }
  }

  function search() {
    var text = inputEl.value.trim();
    if (!text) { state('请先输入要搜索的地点'); return; }
    if (!placeSearch) { state('搜索组件还没准备好，请稍等再试'); return; }
    resultsEl.style.display = 'none';
    resultsEl.innerHTML = '';
    state('正在搜索「' + text + '」…');
    placeSearch.search(text, function (status, result) {
      if (status !== 'complete' || !result.poiList ||
          !result.poiList.pois || !result.poiList.pois.length) {
        resultsEl.innerHTML = '<div class="item">没有找到「' + text
            + '」，换个词试试</div>';
        resultsEl.style.display = 'block';
        state('没有搜到结果，换个词试试');
        return;
      }
      var pois = result.poiList.pois;
      pois.forEach(function (poi) {
        var d = document.createElement('div');
        d.className = 'item';
        d.textContent = poi.name + (poi.address ? '（' + poi.address + '）' : '');
        d.onclick = function () {
          resultsEl.style.display = 'none';
          map.setZoomAndCenter(15, [poi.location.lng, poi.location.lat]);
          choose(poi.location.lng, poi.location.lat);
        };
        resultsEl.appendChild(d);
      });
      resultsEl.style.display = 'block';
      state('找到 ' + pois.length + ' 个结果，点一个试试');
    });
  }

  function choose(lng, lat) {
    if (!map) return;
    if (!marker) {
      marker = new AMap.Marker({ position: [lng, lat], map: map });
    } else {
      marker.setPosition([lng, lat]);
    }
    map.setCenter([lng, lat]);
    state('正在查询地址…');
    geocoder.getAddress([lng, lat], function (status, result) {
      var address = '';
      if (status === 'complete' && result.regeocode) {
        address = shortAddress(result.regeocode);
      }
      if (address) {
        chosen = { lng: lng, lat: lat, address: address };
        // The point is reported as soon as it resolves: the dialog shows it in
        // its footer and decides what to do with it. Waiting for a button press
        // inside the page would have needed a second footer here.
        report(lng, lat, address);
      } else {
        chosen = null;
        state('这个位置查不到地址，请换个地方');
      }
    });
  }

  /// Shortens an address to "市 + 区 + 具体地点".
  ///
  /// The full address includes the province, sub-district and street number,
  /// which pushes the place text past what a preset component can show. The
  /// component usually sits in a caption line, so a short, recognisable name
  /// reads better: city, district, then the place itself.
  ///
  /// Built from the structured parts rather than by trimming the formatted
  /// string, because the order and separators of the full string vary.
  __SHORT_ADDRESS__
})();
</script>
</body>
</html>
'''
    .replaceAll('__KEY__', "'${Uri.encodeQueryComponent(key.trim())}'")
    .replaceAll('__SECRET__',
        "'${secret.trim().replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'")
    .replaceAll('__SHORT_ADDRESS__', _shortAddressJs);

/// Shortens an address to "市 + 区 + 具体地点".
///
/// The full address includes the province, sub-district and street number,
/// which pushes the place text past what a preset component can show. The
/// component usually sits in a caption line, so a short, recognisable name
/// reads better: city, district, then the place itself.
///
/// Built from the structured parts rather than by trimming the formatted
/// string, because the order and separators of the full string vary.
///
/// Shared by both pages as a snippet so the two cannot drift apart.
const _shortAddressJs = r'''
function shortAddress(regeo) {
  var c = regeo.addressComponent || {};
  function pick(v) {
    if (!v) return '';
    // Amap returns an empty array for some fields instead of an empty string.
    if (Object.prototype.toString.call(v) === '[object Array]') v = v[0] || '';
    return ('' + v).trim();
  }
  var city = pick(c.city) || pick(c.province);
  var district = pick(c.district);
  var town = pick(c.township);
  // The specific place: a business area, a building, or the street.
  var spot = '';
  if (c.building) spot = pick(c.building.name);
  if (!spot && c.neighborhood) spot = pick(c.neighborhood.name);
  if (!spot) {
    var sn = c.streetNumber || {};
    spot = pick(sn.street);
  }
  var parts = [];
  if (city) parts.push(city);
  if (district && district !== city) parts.push(district);
  if (spot && spot !== district) parts.push(spot);
  // Fall back to the sub-district when no spot was found.
  if (parts.length < 3 && town && town !== district && town !== spot)
    parts.push(town);
  var text = parts.join(' · ');
  // Nothing usable in the structured parts: keep the full string rather than
  // return an empty place.
  if (!text) return (regeo.formattedAddress || '').trim();
  return text;
}
''';

/// Page that answers "what is at this coordinate" for a background lookup.
///
/// No map is drawn: only the geocoder is loaded, which keeps an automatic
/// lookup cheap. Answers go back as a JSON message.
String buildGeocodePage({required String key, required String secret}) => '''
<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>geocode</title></head>
<body>
<script>
(function () {
  function post(payload) {
    try { window.chrome.webview.postMessage(JSON.stringify(payload)); } catch (e) {}
  }
  __SHORT_ADDRESS__
  window._AMapSecurityConfig = { securityJsCode: __SECRET__ };
  var script = document.createElement('script');
  // 1.4 for the same reason as the map page: no WebGL requirement.
  script.src = 'https://webapi.amap.com/maps?v=1.4.15&key=' + __KEY__;
  script.onload = function () {
    if (!window.AMap) { post({ error: '地图脚本返回了，但 AMap 未创建，请检查 Key' }); return; }
    var geocoder = new AMap.Geocoder({ radius: 1000, extensions: 'base' });
    window.__geocode = function (lon, lat) {
      geocoder.getAddress([lon, lat], function (status, result) {
        if (status === 'complete' && result.regeocode &&
            result.regeocode.formattedAddress) {
          post({ ok: shortAddress(result.regeocode) });
        } else if (status === 'no_data') {
          post({ error: '这个位置附近没有可用的地址' });
        } else if (status === 'error') {
          post({ error: '高德拒绝了这次查询，请检查 Key 是否为 Web端(JS API) 类型' });
        } else {
          post({ error: '查询失败，请稍后重试' });
        }
      });
    };
  };
  script.onerror = function () {
    post({ error: '地图脚本请求失败，请检查网络能否访问 webapi.amap.com' });
  };
  document.head.appendChild(script);
})();
</script>
</body></html>
'''
    .replaceAll('__KEY__', "'${Uri.encodeQueryComponent(key.trim())}'")
    .replaceAll('__SECRET__',
        "'${secret.trim().replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'")
    .replaceAll('__SHORT_ADDRESS__', _shortAddressJs);

/// Page that reports, visibly, what happens while loading the map script.
///
/// Built for diagnosis: a blank window said nothing about whether the script
/// request was blocked, slow or rejected, so this page prints each step and any
/// failure straight into the document.
String buildDiagnosticPage({required String key, required String secret}) => '''
<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>diagnose</title>
<style>
  body { font-family: "Microsoft YaHei UI", "Microsoft YaHei", sans-serif;
         margin: 0; padding: 18px; background: #fff; color: #333; font-size: 13px; }
  h3 { margin: 0 0 12px; font-size: 15px; }
  .row { padding: 5px 0; border-bottom: 1px solid #eee; line-height: 1.55; }
  .ok { color: #1a7f37; } .bad { color: #c62828; } .wait { color: #9a6a00; }
  code { background: #f4f4f4; padding: 1px 4px; border-radius: 3px; word-break: break-all; }
</style></head>
<body>
<h3>地图连接诊断</h3>
<div id="log"></div>
<script>
var log = document.getElementById('log');
function line(text, cls) {
  var d = document.createElement('div');
  d.className = 'row ' + (cls || '');
  d.innerHTML = text;
  log.appendChild(d);
}
line('1. 页面已加载（本地页面正常）', 'ok');
line('2. 正在请求高德脚本…', 'wait');

window._AMapSecurityConfig = { securityJsCode: __SECRET__ };

var s = document.createElement('script');
s.src = 'https://webapi.amap.com/maps?v=1.4.15&key=' + __KEY__;
s.onload = function () {
  if (window.AMap) {
    line('3. 高德脚本加载成功，AMap 对象已创建', 'ok');
    line('4. 结论：Key、白名单、网络都正常', 'ok');
    document.title = 'DIAG_OK';
  } else {
    line('3. 脚本返回了，但 AMap 没有创建', 'bad');
    line('   多半是 Key 无效或被拒绝，请核对 Key 是否完整。', 'bad');
    document.title = 'DIAG_FAIL';
  }
};
s.onerror = function () {
  line('3. 脚本请求失败（网络层）', 'bad');
  line('   可能是网络无法访问 webapi.amap.com，或被代理拦截。', 'bad');
  document.title = 'DIAG_FAIL';
};
document.head.appendChild(s);

setTimeout(function () {
  if (!window.AMap) {
    line('3. 等了 12 秒仍没有结果（脚本请求像是被挂起了）', 'bad');
    line('   若上面没有第 3 条，常见原因：代理软件拦截、防火墙、DNS 解析失败。', 'bad');
    document.title = 'DIAG_FAIL';
  }
}, 12000);
</script>
</body></html>
'''
    .replaceAll('__KEY__', "'${Uri.encodeQueryComponent(key.trim())}'")
    .replaceAll('__SECRET__',
        "'${secret.trim().replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'");
