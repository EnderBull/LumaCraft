import 'package:flutter/material.dart';

import '../../photo_state.dart';
import '../../settings/android_map_preview.dart';
import '../../settings/place_lookup.dart';
import '../amap_key_tutorial.dart';
import 'alpha_workspace.dart';
import 'mobile_fields.dart';

class MobilePhotoInfoPage extends StatefulWidget {
  final AlphaWorkspace workspace;
  const MobilePhotoInfoPage(this.workspace, {super.key});

  @override
  State<MobilePhotoInfoPage> createState() => _MobilePhotoInfoPageState();
}

class _MobilePhotoInfoPageState extends State<MobilePhotoInfoPage> {
  AlphaWorkspace get workspace => widget.workspace;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: workspace,
        builder: (context, _) {
          return Scaffold(
            appBar: AppBar(title: const Text('照片信息'), actions: [
              IconButton(
                  tooltip: '撤销',
                  onPressed: workspace.canUndo ? workspace.undo : null,
                  icon: const Icon(Icons.undo)),
              IconButton(
                  tooltip: '重做',
                  onPressed: workspace.canRedo ? workspace.redo : null,
                  icon: const Icon(Icons.redo)),
            ]),
            body: SafeArea(
                child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(workspace.current?.source.name ?? '当前照片',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('修改仅应用到当前照片。留空可恢复原始信息。'),
                const SizedBox(height: 10),
                if (gpsDiagnosticsEnabled && workspace.preview != null) ...[
                  Text(
                    gpsDiagnosticText(workspace.preview!.fields,
                        queryStatus: workspace.placeDiagnostic),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],
                MobileCaptureFields(
                  workspace: workspace,
                  keys: infoFields.keys.toList(),
                ),
              ],
            )),
          );
        },
      );
}

class MobileCaptureFields extends StatelessWidget {
  const MobileCaptureFields({
    super.key,
    required this.workspace,
    required this.keys,
  });

  final AlphaWorkspace workspace;
  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final path = workspace.current?.source.path;
    final original = workspace.preview?.fields;
    if (path == null || original == null) return const SizedBox.shrink();
    final effective = workspace.fields;

    Widget field(String key) {
      if (key == 'place') {
        return MobilePlaceField(workspace: workspace);
      }
      if (const {'focal', 'aperture', 'iso'}.contains(key)) {
        final defaultValue = double.tryParse(original[key] ?? '');
        return MobileNumberField(
          label: infoFields[key]!,
          value: double.tryParse(effective[key] ?? ''),
          defaultValue: defaultValue,
          hint: '未填写',
          min: key == 'iso' ? 1 : .01,
          max: key == 'iso' ? 65535 : double.infinity,
          integer: key == 'iso',
          step: switch (key) {
            'iso' => 1,
            'aperture' => .1,
            _ => .5,
          },
          onChanged: (value) {
            final text = value == null || value == defaultValue
                ? null
                : key == 'iso'
                    ? value.toInt().toString()
                    : value.toString();
            workspace.editCapture(key, text, photoPath: path);
          },
        );
      }
      return MobileField(
        label: infoFields[key]!,
        value: effective[key] ?? '',
        onCommit: (text) {
          final value = text.trim();
          final error = validateInfo(key, value);
          if (error != null) return error;
          workspace.editCapture(
            key,
            value.isEmpty || value == original[key] ? null : value,
            photoPath: path,
          );
          return null;
        },
      );
    }

    Widget pair(String left, String right) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: field(left)),
            const SizedBox(width: 8),
            Expanded(child: field(right)),
          ],
        );

    return Column(
      key: ValueKey(path),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final key in keys)
          switch (key) {
            'focal' when keys.contains('aperture') => pair(key, 'aperture'),
            'shutter' when keys.contains('iso') => pair(key, 'iso'),
            'aperture' when keys.contains('focal') => const SizedBox.shrink(),
            'iso' when keys.contains('shutter') => const SizedBox.shrink(),
            _ => field(key),
          },
      ],
    );
  }
}

class MobilePlaceField extends StatefulWidget {
  const MobilePlaceField({super.key, required this.workspace});

  final AlphaWorkspace workspace;

  @override
  State<MobilePlaceField> createState() => _MobilePlaceFieldState();
}

class _MobilePlaceFieldState extends State<MobilePlaceField> {
  AlphaWorkspace get workspace => widget.workspace;
  bool _picking = false;

  Future<void> _choosePlace() async {
    final path = workspace.current?.source.path;
    if (path == null || _picking) return;
    final dark = Theme.of(context).brightness == Brightness.dark;
    FocusScope.of(context).unfocus();
    setState(() => _picking = true);
    try {
      final settings = await loadAndroidSettings();
      try {
        if (!mounted) return;
        if (!settings.hasAmapCredentials) {
          final configured = await showMobileMapSettings(context);
          if (!configured || !mounted) return;
        }
      } finally {
        settings.dispose();
      }
      final saved = await loadAndroidSettings();
      try {
        final place =
            await pickAndroidPlace(saved.amapKey, saved.amapSecret, dark: dark);
        if (place != null && mounted) {
          workspace.editCapture('place', place, photoPath: path);
        }
      } finally {
        saved.dispose();
      }
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('地图选点失败 · $error')),
        );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MobileField(
            key: ValueKey(workspace.current?.source.path),
            label: '地点',
            value: workspace.fields['place'] ?? '',
            onCommit: (text) {
              final value = text.trim();
              final original = workspace.preview?.fields['place'];
              workspace.editCapture(
                  'place', value.isEmpty || value == original ? null : value);
              return null;
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _picking ? null : _choosePlace,
              icon: const Icon(Icons.place_outlined),
              label: const Text('从地图选点'),
            ),
          ),
        ],
      );
}

Future<bool> showMobileMapSettings(BuildContext context) async {
  try {
    final settings = await loadAndroidSettings();
    try {
      if (!context.mounted) return false;
      final values = await showDialog<(String, String)>(
        context: context,
        builder: (_) =>
            _MapSettingsDialog(settings.amapKey, settings.amapSecret),
      );
      if (values == null) return false;
      settings.amapKey = values.$1;
      settings.amapSecret = values.$2;
      await settings.flush();
      if (settings.saveError != null) throw StateError(settings.saveError!);
      return settings.hasAmapCredentials;
    } finally {
      settings.dispose();
    }
  } on Object {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法读取或保存高德设置。')),
      );
    return false;
  }
}

class MobileAmapSettingsPane extends StatefulWidget {
  const MobileAmapSettingsPane({super.key});

  @override
  State<MobileAmapSettingsPane> createState() => _MobileAmapSettingsPaneState();
}

class _MobileAmapSettingsPaneState extends State<MobileAmapSettingsPane> {
  late final _initial = _read();

  Future<(String, String, bool)> _read() async {
    final settings = await loadAndroidSettings();
    try {
      return (
        settings.amapKey,
        settings.amapSecret,
        settings.androidAutoFillPlace
      );
    } finally {
      settings.dispose();
    }
  }

  Future<void> _save((String, String, bool) values) async {
    final settings = await loadAndroidSettings();
    try {
      settings.amapKey = values.$1;
      settings.amapSecret = values.$2;
      settings.androidAutoFillPlace = values.$3;
      await settings.flush();
      if (settings.saveError != null) throw StateError(settings.saveError!);
    } finally {
      settings.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(String, String, bool)>(
        future: _initial,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Text('无法读取高德设置。');
          final values = snapshot.data;
          if (values == null)
            return const Center(child: CircularProgressIndicator());
          return _MapSettingsDialog(values.$1, values.$2,
              autoFillPlace: values.$3, saveInline: _save);
        },
      );
}

class _MapSettingsDialog extends StatefulWidget {
  final String keyValue, secret;
  const _MapSettingsDialog(this.keyValue, this.secret,
      {this.autoFillPlace = false, this.saveInline});
  final bool autoFillPlace;
  final Future<void> Function((String, String, bool))? saveInline;

  @override
  State<_MapSettingsDialog> createState() => _MapSettingsDialogState();
}

class _MapSettingsDialogState extends State<_MapSettingsDialog> {
  late final _key = TextEditingController(text: widget.keyValue);
  late final _secret = TextEditingController(text: widget.secret);
  late bool _autoFillPlace = widget.autoFillPlace;
  String? _error, _connectionStatus;
  bool _testing = false;
  bool _saving = false;
  bool _showKey = false, _showSecret = false;
  bool get _busy => _testing || _saving;
  bool _connectionOk = false;
  bool _tutorialOpen = false;

  Future<void> _testConnection() async {
    if (_testing) return;
    final key = _key.text.trim(), secret = _secret.text.trim();
    if (key.isEmpty || secret.isEmpty) {
      setState(() {
        _connectionStatus = null;
        _error = '请先填写 Key 和安全密钥';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    final dark = Theme.of(context).brightness == Brightness.dark;
    setState(() {
      _testing = true;
      _error = null;
      _connectionStatus = null;
    });
    try {
      final message = await testAndroidMapConnection(key, secret, dark: dark);
      if (!mounted) return;
      setState(() {
        _connectionStatus = message;
        _connectionOk = message != null;
      });
    } on FormatException catch (error) {
      if (mounted)
        setState(() {
          _connectionStatus = error.message.toString();
          _connectionOk = false;
        });
    } on Object {
      if (mounted)
        setState(() {
          _connectionStatus = '无法启动本机地图测试，请重试。';
          _connectionOk = false;
        });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _clearStatus(String _) {
    if (_connectionStatus == null && _error == null) return;
    setState(() {
      _connectionStatus = null;
      _error = null;
    });
  }

  @override
  void dispose() {
    _key.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final key = _key.text.trim(), secret = _secret.text.trim();
    final valid = RegExp(r'^[a-zA-Z0-9_-]*$');
    if (key.isEmpty != secret.isEmpty ||
        !valid.hasMatch(key) ||
        !valid.hasMatch(secret)) {
      setState(() => _error = '请同时填写两项，或同时留空');
      return;
    }
    final save = widget.saveInline;
    if (save == null) {
      Navigator.pop(context, (key, secret));
      return;
    }
    setState(() => _saving = true);
    try {
      await save((key, secret, _autoFillPlace));
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已保存高德设置')));
    } on Object {
      if (mounted) setState(() => _error = '无法保存高德设置，请重试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(BuildContext context, String label,
          TextEditingController controller, bool show, VoidCallback toggle,
          {String? error}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            enabled: !_busy,
            onChanged: _clearStatus,
            obscureText: !show,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              errorText: error,
              suffixIcon: IconButton(
                onPressed: _busy ? null : toggle,
                tooltip: show ? '隐藏' : '显示',
                icon: Icon(show
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
              ),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final inline = widget.saveInline != null;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inline) ...[
          const Text('在高德开放平台申请 Web 端（JS API）的 Key 和安全密钥。'),
          const SizedBox(height: 18),
        ],
        _field(context, '高德地图 Key', _key, _showKey,
            () => setState(() => _showKey = !_showKey)),
        const SizedBox(height: 14),
        _field(context, '安全密钥', _secret, _showSecret,
            () => setState(() => _showSecret = !_showSecret),
            error: _error),
        if (inline) ...[
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('有坐标时自动填地点'),
            subtitle: const Text('预设显示地点时，将照片坐标发送给高德查询。相册未提供坐标时，可试用「从文件选择」。'),
            value: _autoFillPlace,
            onChanged: _busy
                ? null
                : (value) => setState(() => _autoFillPlace = value),
          ),
        ],
        if (_connectionStatus case final status?)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Semantics(
              liveRegion: true,
              child: Text(status,
                  style: TextStyle(
                      color: _connectionOk
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.error)),
            ),
          ),
      ],
    );
    final actions = [
      if (inline)
        TextButton.icon(
          onPressed: () => setState(() => _tutorialOpen = !_tutorialOpen),
          icon: Icon(_tutorialOpen ? Icons.expand_less : Icons.expand_more),
          label: const Text('获取教程'),
        ),
      TextButton(
        onPressed: _busy ? null : _testConnection,
        child: Text(_testing ? '测试中…' : '测试连接'),
      ),
      if (!inline)
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      FilledButton(onPressed: _busy ? null : _submit, child: const Text('保存')),
    ];
    if (inline) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        content,
        const SizedBox(height: 16),
        OverflowBar(
            alignment: MainAxisAlignment.end, spacing: 8, children: actions),
        if (_tutorialOpen) ...[
          const SizedBox(height: 16),
          const AmapKeyTutorial(),
        ],
      ]);
    }
    return AlertDialog(
        title: const Text('高德地图设置'),
        scrollable: true,
        content: content,
        actions: actions);
  }
}
