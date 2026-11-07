import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import '../settings/app_settings.dart';
import '../settings/map_page_server.dart';
import 'editor/prototype_controls.dart';
import 'workspace_dialog.dart';

/// Which page to show.
enum MapPageKind {
  /// Shows a map the user can click to pick a place.
  picker,

  /// Loads the map script without a map, to prove the key works.
  connectionTest,
}

/// Opens the map page and reports back what it could do.
///
/// A visible window is used even for the connection test: the webview must be
/// laid out before its scripts run, and a headless controller has no layout to
/// trigger that — which made the test fail with a timeout and nothing to show.
/// Showing the page also means a failure is visible instead of silent.
Future<String?> showMapPage(BuildContext context,
    {required AppSettings app, required MapPageKind kind}) async {
  final version = await WebviewController.getWebViewVersion();
  if (version == null || version.isEmpty) {
    if (context.mounted) await _showRuntimeMissing(context);
    return null;
  }
  if (app.amapKey.trim().isEmpty) {
    if (context.mounted)
      await showDialog<void>(
          context: context,
          builder: (ctx) => WorkspaceDialog(
                  title: const Text('还没有填高德 Key'),
                  content: const SizedBox(
                      width: 420,
                      child: Text('请先到「设置」→「高德 API」填入你的 Key 和安全密钥。')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('知道了'))
                  ]));
    return null;
  }
  return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _MapDialog(app: app, kind: kind));
}

/// Backwards-compatible entry for picking a place.
Future<String?> showPlacePicker(BuildContext context,
        {required AppSettings app}) =>
    showMapPage(context, app: app, kind: MapPageKind.picker);

Future<void> _showRuntimeMissing(BuildContext context) => showDialog<void>(
    context: context,
    builder: (ctx) => WorkspaceDialog(
            title: const Text('需要先安装一个组件'),
            content: const SizedBox(
                width: 460,
                child: Text('地图功能需要微软的 WebView2 运行时。Windows 11 已经自带；'
                    '如果这台电脑没有，请到微软官网下载安装「WebView2 Runtime」后再试。')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('知道了'))
            ]));

class _MapDialog extends StatefulWidget {
  final AppSettings app;
  final MapPageKind kind;
  const _MapDialog({required this.app, required this.kind});
  @override
  State<_MapDialog> createState() => _MapDialogState();
}

class _MapDialogState extends State<_MapDialog> {
  final server = MapPageServer();
  WebviewController? controller;
  StreamSubscription<String>? titleSub;
  String? error;
  String status = '正在启动…';
  bool loading = true;
  bool tested = false;

  /// The point the page reported, and which the footer shows until confirmed.
  String? chosenAddress, chosenCoords;

  bool get isTest => widget.kind == MapPageKind.connectionTest;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => status = '正在启动本地服务…');
    // The connection test loads the diagnostic page: it prints each step on
    // screen, so a failure explains itself instead of leaving a blank window.
    final page = isTest
        ? buildDiagnosticPage(
            key: widget.app.amapKey, secret: widget.app.amapSecret)
        : buildMapPage(key: widget.app.amapKey, secret: widget.app.amapSecret);
    final path = isTest ? '/diagnose.html' : '/index.html';
    final port = await server.start(page, path: path);
    if (!mounted) return;
    if (port == null) {
      setState(() {
        error = '本地服务启动失败，请重启软件后重试';
        loading = false;
      });
      return;
    }
    final web = WebviewController();
    try {
      await web.initialize();
      controller = web;
      titleSub = web.title.listen((title) {
        // "PICK:<counter>|<address>|<lng>,<lat>" is sent as soon as a point
        // resolves; the dialog shows it in its footer and waits for the user to
        // confirm, so the panel does not vanish on the first click.
        if (title.startsWith('PICK:')) {
          final rest = title.substring('PICK:'.length);
          final parts = rest.split('|');
          if (parts.length < 3 || !mounted) return;
          final address = parts[1].trim();
          final coords = parts[2].trim();
          if (address.isEmpty) return;
          setState(() {
            chosenAddress = address;
            chosenCoords = coords;
            status = '在地图上点一下位置，或搜索地名';
          });
          return;
        }
        if (title.startsWith('STATE:')) {
          final text = title.substring('STATE:'.length).trim();
          if (text.isNotEmpty && mounted) setState(() => status = text);
        }
      });
      await web.loadUrl('http://127.0.0.1:$port$path');
      if (!mounted) return;
      setState(() {
        loading = false;
        status = isTest ? '正在检查地图脚本…' : '准备加载地图…';
      });
      if (isTest) {
        await _checkScript(web);
      } else {
        // Follow the page's own progress. Without this the dialog kept saying
        // "loading" whatever happened inside, which is what made a stuck map
        // look identical to a working one.
        _watchPageState(web);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = '地图加载失败：$e';
        loading = false;
      });
    }
  }

  /// Mirrors the page's own progress into the dialog footer.
  ///
  /// The page puts each step in its title as "STATE:…", so the dialog can show
  /// where it stopped even when the page itself draws nothing.
  Future<void> _watchPageState(WebviewController web) async {
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      String title = '';
      try {
        title = '${await web.executeScript('document.title')}';
      } catch (_) {
        continue;
      }
      if (title.startsWith('STATE:')) {
        final text = title.substring('STATE:'.length).trim();
        if (text.isNotEmpty && mounted) setState(() => status = text);
      }
    }
  }

  /// Reads the diagnostic page's own conclusion.
  ///
  /// The page writes steps into the document and sets its title to DIAG_OK or
  /// DIAG_FAIL, so this only has to report that result — the reasons are on
  /// screen where the user can read them.
  Future<void> _checkScript(WebviewController web) async {
    for (var i = 0; i < 60; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      String title = '';
      try {
        title = '${await web.executeScript('document.title')}';
      } catch (_) {
        // Page still loading.
      }
      if (title.contains('DIAG_OK')) {
        setState(() {
          tested = true;
          status = '连接成功，地图脚本可以正常加载';
        });
        return;
      }
      if (title.contains('DIAG_FAIL')) {
        setState(() {
          tested = false;
          status = '连接失败，具体原因请看窗口里的说明';
        });
        return;
      }
    }
    if (!mounted) return;
    setState(() => status = '没有等到结果，请看窗口里的说明');
  }

  @override
  void dispose() {
    titleSub?.cancel();
    controller?.dispose();
    unawaited(server.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
        backgroundColor: scheme.surface,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
            width: 900,
            height: 680,
            child: DefaultTextStyle(
                style: dialogBodyStyle.copyWith(color: scheme.onSurface),
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 16, 14),
                      child: Row(children: [
                        Text(isTest ? '检查地图连接' : '选择拍照地点',
                            style: dialogTitleStyle.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.2)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(
                                isTest ? '这一步验证 Key、白名单和网络' : '在地图上点一下位置',
                                style: EditorTypography.hint(context)
                                    .copyWith(fontSize: 12))),
                        SizedBox(
                            width: 30,
                            height: 30,
                            child: IconButton(
                                padding: EdgeInsets.zero,
                                tooltip: '关闭',
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(Icons.close_rounded,
                                    size: 18,
                                    color:
                                        scheme.onSurface.withValues(alpha: .62))))
                      ])),
                  Expanded(
                      child: Stack(children: [
                    if (controller != null) Positioned.fill(child: Webview(controller!)),
                    // No loading overlay once the controller exists: it sat on
                    // top of the webview and hid whatever the page drew, so a
                    // working map and a blank one looked the same.
                    if (controller == null && error == null)
                      Positioned.fill(
                          child: ColoredBox(
                              color: scheme.surface,
                              child: const Center(
                                  child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))))),
                    if (error != null)
                      Positioned.fill(
                          child: ColoredBox(
                              color: scheme.surface,
                              child: Center(
                                  child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Text(error!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 13,
                                              height: 1.7,
                                              color: scheme.error))))))
                  ])),
                  _footer(scheme)
                ]))));
  }

  /// The dialog's only footer: place, coordinates and both buttons.
  ///
  /// The page used to draw its own bar as well, so the same text appeared twice
  /// in two different styles. Everything now lives here.
  Widget _footer(ColorScheme scheme) {
    final hasPoint = chosenAddress != null;
    return Container(
        padding: const EdgeInsets.fromLTRB(24, 13, 24, 15),
        decoration: BoxDecoration(
            color: scheme.surface,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(
                      alpha: scheme.brightness == Brightness.dark ? .26 : .07),
                  blurRadius: 18,
                  offset: const Offset(0, -4))
            ]),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                if (hasPoint) ...[
                  // Sized to sit against both lines of text rather than beside
                  // the first one only, and centred on them.
                  Icon(Icons.place_rounded, size: 19, color: scheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(
                          hasPoint
                              ? chosenAddress!
                              : (tested ? status : '在地图上点一下位置，或先搜索地名'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: hasPoint ? 14 : 13.5,
                              height: 1.45,
                              color: hasPoint
                                  ? scheme.onSurface
                                  : EditorTypography.muted(context))),
                      if (hasPoint && chosenCoords != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text('高德坐标 $chosenCoords',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: 'Consolas',
                                    fontFamilyFallback: const [
                                      'Courier New',
                                      'monospace'
                                    ],
                                    fontSize: 12,
                                    letterSpacing: .2,
                                    color: scheme.onSurface.withValues(
                                        alpha: EditorTypography.dimOpacity))))
                    ]))
              ])),
          const SizedBox(width: 16),
          if (isTest)
            WorkspaceActionButton(
                label: '关闭', onPressed: () => Navigator.pop(context))
          else ...[
            WorkspaceActionButton(
                label: '取消', onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 10),
            SizedBox(
                height: 40,
                child: FilledButton(
                    style: FilledButton.styleFrom(
                        textStyle: dialogActionStyle,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6))),
                    onPressed:
                        hasPoint ? () => Navigator.pop(context, chosenAddress) : null,
                    child: const Text('使用这个地点')))
          ]
        ]));
  }
}
