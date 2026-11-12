import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../editor/qr_scan.dart';
import '../../editor/preset_code.dart';
import '../../editor/style_document.dart';

const _camera = MethodChannel('lumacraft/qr_camera');

class MobileQrCamera extends StatefulWidget {
  const MobileQrCamera({super.key});

  @override
  State<MobileQrCamera> createState() => _MobileQrCameraState();
}

class _MobileQrCameraState extends State<MobileQrCamera>
    with WidgetsBindingObserver {
  Map<String, int>? _preview;
  String? _error, _scanMessage;
  int _generation = 0;
  bool _starting = false;
  bool _returned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_returned) return;
    if (state == AppLifecycleState.paused && _preview != null) {
      setState(() => _preview = null);
      unawaited(_stop());
    } else if (state == AppLifecycleState.resumed &&
        _preview == null &&
        _error == null) {
      unawaited(_start());
    }
  }

  @override
  void didChangeMetrics() {
    if (_preview != null) unawaited(_refreshPreviewGeometry());
  }

  Future<void> _refreshPreviewGeometry() async {
    final generation = _generation;
    try {
      final geometry =
          await _camera.invokeMapMethod<String, int>('previewGeometry');
      if (mounted &&
          generation == _generation &&
          geometry != null &&
          !mapEquals(geometry, _preview)) {
        setState(() => _preview = geometry);
      }
    } on PlatformException {
      // A closing camera has no geometry to update.
    }
  }

  Future<void> _start() async {
    if (_starting || _returned) return;
    _starting = true;
    final generation = ++_generation;
    try {
      final preview = await _camera.invokeMapMethod<String, int>('start');
      if (!mounted || generation != _generation) return;
      if (preview == null) {
        setState(() => _error = '相机未能启动。');
        return;
      }
      setState(() {
        _preview = preview;
        _error = null;
      });
      unawaited(_readFrames(generation));
    } on PlatformException catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.message ?? '相机未能启动。');
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> _readFrames(int generation) async {
    while (mounted && generation == _generation && !_returned) {
      try {
        final frame = await _camera.invokeMapMethod<String, Object?>('frame');
        if (frame != null && mounted && generation == _generation) {
          final code = await compute(scanQrCameraFrame, (
            bytes: frame['bytes']! as Uint8List,
            width: frame['width']! as int,
            height: frame['height']! as int,
          ));
          if (code != null && mounted && generation == _generation) {
            // Ignore unrelated codes and keep the camera open.
            final StyleDocument style;
            try {
              style = await decodePresetCodeAsync(code);
            } on FormatException {
              if (mounted &&
                  generation == _generation &&
                  _scanMessage == null) {
                setState(() => _scanMessage = '这不是可导入的框印工坊预设二维码。');
              }
              await Future<void>.delayed(const Duration(milliseconds: 550));
              continue;
            }
            if (!mounted || generation != _generation) return;
            _returned = true;
            Navigator.pop(context, style);
            return;
          }
        }
      } on PlatformException catch (error) {
        if (mounted && generation == _generation) {
          setState(() {
            _preview = null;
            _error = error.message ?? '相机连接已中断。';
          });
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 140));
    }
  }

  Future<void> _stop() async {
    ++_generation;
    try {
      await _camera.invokeMethod<void>('stop');
    } on PlatformException {
      // The activity also releases the camera when it is destroyed.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('扫描二维码')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: preview == null
                ? _error == null
                    ? const CircularProgressIndicator()
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            setState(() => _error = null);
                            unawaited(_start());
                          },
                          child: const Text('重试'),
                        ),
                      ])
                : Column(children: [
                    Expanded(
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: RotatedBox(
                              quarterTurns: preview['turns']!,
                              child: SizedBox(
                                width: preview['width']!.toDouble(),
                                height: preview['height']!.toDouble(),
                                child: Texture(textureId: preview['texture']!),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_scanMessage ?? '将预设二维码放在取景画面中',
                        textAlign: TextAlign.center),
                  ]),
          ),
        ),
      ),
    );
  }
}
