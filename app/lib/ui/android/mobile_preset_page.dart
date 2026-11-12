import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../editor/preset_code.dart';
import '../../editor/preset_package.dart';
import '../../editor/preset_store.dart';
import '../../editor/qr_scan.dart';
import '../../editor/style_document.dart';
import '../../export/android_photo_io.dart';
import '../app_icons.dart';
import 'alpha_workspace.dart';
import 'mobile_qr_camera.dart';
import 'preset_qr_card.dart';
import 'preset_import_confirmation.dart';

String _encodeCode(StyleDocument style) => encodePresetCode(
      StyleDocument.fromJson(
          presetStyleForSharing(style, allowMissingImages: true)),
      includeImages: true,
    );

Future<String?> _saveDocument(String name, String text) async {
  final directory = await Directory.systemTemp.createTemp('lumacraft-share-');
  try {
    final file = await File('${directory.path}/document').writeAsString(text);
    return await androidPlatform.invokeMethod<String>('savePreset', {
      'path': file.path,
      'name': name,
    });
  } finally {
    await directory.delete(recursive: true);
  }
}

Future<void> showMobilePresetImport(
        BuildContext context, AlphaWorkspace workspace) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          MobilePresetPage(workspace, libraryMode: true, importSheet: true),
    );

Future<void> showMobilePresetActions(
        BuildContext context, AlphaWorkspace workspace, PresetEntry entry) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          MobilePresetPage(workspace, libraryMode: true, entry: entry),
    );

class MobilePresetPage extends StatefulWidget {
  final AlphaWorkspace workspace;
  const MobilePresetPage(this.workspace,
      {super.key,
      this.libraryMode = false,
      this.entry,
      this.importSheet = false});

  final bool libraryMode, importSheet;
  final PresetEntry? entry;

  @override
  State<MobilePresetPage> createState() => _MobilePresetPageState();
}

class _MobilePresetPageState extends State<MobilePresetPage> {
  AlphaWorkspace get workspace => widget.workspace;
  bool _busy = false;
  bool get _isActionSheet => widget.libraryMode && widget.entry != null;
  PresetEntry? get _entry {
    final id = widget.entry?.id;
    return id == null
        ? null
        : workspace.presets.where((item) => item.id == id).firstOrNull;
  }

  String? _feedback;

  void _message(String text) {
    if (!mounted) return;
    if (widget.importSheet || _isActionSheet) {
      setState(() => _feedback = text);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      await action();
    } on Object catch (error) {
      _message(error is FormatException ? error.message.toString() : '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final result =
        await showDialog<({String name, String? replace, String folder})>(
      context: context,
      builder: (_) => _SavePresetDialog(workspace),
    );
    if (result == null || !mounted) return;
    final name = await workspace.savePreset(result.name,
        replaceId: result.replace, folder: result.folder);
    _message('已保存预设「$name」');
  }

  Future<void> _importFile() async {
    final source = await AndroidPhoto.pick(preset: true);
    if (source == null) return;
    final file = File(source.path);
    try {
      if (!source.name.toLowerCase().endsWith('.lmp')) {
        throw const FormatException('请选择 .lmp 预设文件。');
      }
      final incoming = await readLmp(file);
      if (!mounted ||
          !await confirmMobilePresetImport(context, incoming) ||
          !mounted) return;
      final count = await workspace.importPresets(incoming,
          activate: !widget.libraryMode);
      _message('已导入 $count 个预设');
    } finally {
      await file.delete();
    }
  }

  Future<void> _exportFile() async {
    final payload =
        await compute(encodeLmp, [workspace.sharePreset(entry: _entry)]);
    if (await _saveDocument('LumaCraft.lmp', payload) != null) {
      _message('已保存 .lmp 预设');
    }
  }

  Future<void> _importCode({bool qr = false}) async {
    String? code;
    if (qr) {
      final image = await AndroidPhoto.pick();
      if (image == null) return;
      final file = File(image.path);
      try {
        if (await file.length() > qrImageMaxBytes) {
          throw const FormatException('二维码图片过大，请换一张图片。');
        }
        code = await scanQrCodeAsync(await file.readAsBytes());
        if (code == null) throw const FormatException('图片中没有可识别的二维码。');
      } finally {
        await file.delete();
      }
    } else {
      final input = await showDialog<String>(
        context: context,
        builder: (_) => const _PasteCodeDialog(),
      );
      if (input == null) return;
      if (input.isNotEmpty) {
        code = input;
      } else {
        final selected = await AndroidPhoto.pick(preset: true);
        if (selected == null) return;
        final file = File(selected.path);
        try {
          if (await file.length() > presetCodeMaxChars) {
            throw const FormatException('预设代码文件过大。');
          }
          code = await file.readAsString();
        } finally {
          await file.delete();
        }
      }
    }
    await _acceptCode(code);
  }

  Future<void> _scan() async {
    final style = await Navigator.of(context).push<StyleDocument>(
      MaterialPageRoute(builder: (_) => const MobileQrCamera()),
    );
    if (style != null && mounted) await _acceptStyle(style);
  }

  Future<void> _acceptCode(String code) async {
    final style = await decodePresetCodeAsync(code);
    if (mounted) await _acceptStyle(style);
  }

  Future<void> _acceptStyle(StyleDocument style) async {
    final incoming = [SharedPreset(style)];
    if (!await confirmMobilePresetImport(context, incoming) || !mounted) return;
    await workspace.importPresets(incoming, activate: !widget.libraryMode);
    _message(style.nodes
            .any((node) => node.type == 'image' && node.image.data.isEmpty)
        ? '已导入预设，请替换其中缺少的图片素材。'
        : '已导入预设「${style.name}」');
  }

  Future<void> _exportCode({bool qr = false}) async {
    final style = (_entry?.style ?? workspace.style).copy();
    final code = await compute(_encodeCode, style);
    if (presetCodeBytes(code) > presetCodeMaxChars) {
      throw const FormatException('预设代码过大，请改用 .lmp。');
    }
    if (qr) {
      if (presetCodeTooLarge(code)) {
        throw const FormatException('此预设超过二维码容量，请用文本代码或 .lmp。');
      }
      final bytes = await renderPresetQrCard(code, style.name);
      await publishToAndroidGallery(bytes, 'LumaCraft-预设二维码.png', 'png');
      _message('已保存二维码到相册');
      return;
    }
    if (!mounted) return;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('分享预设代码'),
        content: Text(presetCodeBytes(code) <= 128 * 1024
            ? '可复制代码，或保存为文本文件。'
            : '代码较长，可保存为文本文件。'),
        actions: [
          if (presetCodeBytes(code) <= 128 * 1024)
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('复制代码')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存文本')),
        ],
      ),
    );
    if (save == true) {
      if (await _saveDocument('LumaCraft-preset.txt', code) != null) {
        _message('已保存预设代码');
      }
    } else if (save == false) {
      await Clipboard.setData(ClipboardData(text: code));
      _message('已复制预设代码');
    }
  }

  Widget _importMenu(BuildContext context) {
    final actions = <(String, WorkspaceIcon, Future<void> Function())>[
      ('导入 .lmp', WorkspaceIcon.presetImport, _importFile),
      ('导入文本代码', WorkspaceIcon.textImport, _importCode),
      ('导入二维码图片', WorkspaceIcon.qrImage, () => _importCode(qr: true)),
      ('扫描二维码', WorkspaceIcon.qrCamera, _scan),
    ];
    return _actionMenu(context, '导入预设', actions,
        columns: 2, footer: '完整的预设编辑功能请使用电脑端');
  }

  Future<String?> _requestName(String title, String label,
          {String initial = ''}) =>
      showDialog<String>(
        context: context,
        builder: (context) => _PresetNameDialog(title, label, initial),
      );

  Future<void> _rename(PresetEntry entry) async {
    final name = await _requestName('重命名预设', '预设名称', initial: entry.style.name);
    if (name == null || !mounted) return;
    await workspace.updateLibraryPreset(entry.id, name: name);
    _message('预设名称已更新');
  }

  Future<void> _move(PresetEntry entry) async {
    final folder = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('移动预设'),
        children: [
          for (final item in [
            PresetFolder('', '未分组'),
            ...workspace.userFolders
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item.id),
              child: Row(children: [
                Expanded(child: Text(item.name)),
                if (entry.folder == item.id) const Icon(Icons.check, size: 18),
              ]),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, '+'),
            child: const Text('新建分组…'),
          ),
        ],
      ),
    );
    if (folder == null || !mounted || folder == entry.folder) return;
    if (folder == '+') {
      final name = await _requestName('新建分组', '分组名称');
      if (name == null || !mounted) return;
      await workspace.updateLibraryPreset(entry.id, newFolder: name);
    } else {
      await workspace.updateLibraryPreset(entry.id, folder: folder);
    }
    _message('预设已移动');
  }

  Future<void> _remove(PresetEntry entry) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除预设？'),
        content: Text('将删除「' + entry.style.name + '」。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除预设'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    await workspace.updateLibraryPreset(entry.id, remove: true);
    if (mounted) Navigator.pop(context);
  }

  Widget _presetActions(BuildContext context, PresetEntry entry) {
    final editable = !entry.builtIn;
    final favorite = workspace.isFavorite(entry.id);
    return _actionMenu(
        context,
        entry.style.name,
        [
          (
            '复制',
            WorkspaceIcon.presetCopy,
            () async {
              final name = await workspace.copyLibraryPreset(entry);
              _message('已复制为「' + name + '」');
            }
          ),
          (
            '移动',
            WorkspaceIcon.presetMove,
            editable ? () => _move(entry) : null
          ),
          (
            '删除',
            WorkspaceIcon.presetDelete,
            editable ? () => _remove(entry) : null
          ),
          (
            '重命名',
            WorkspaceIcon.signature,
            editable ? () => _rename(entry) : null
          ),
          (
            favorite ? '取消收藏' : '收藏',
            WorkspaceIcon.presetFavorite,
            () => workspace.toggleFavorite(entry.id)
          ),
          ('导出 .lmp', WorkspaceIcon.presetMove, _exportFile),
          ('导出文本代码', WorkspaceIcon.textImport, _exportCode),
          ('导出二维码', WorkspaceIcon.qrImage, () => _exportCode(qr: true)),
        ],
        columns: 4);
  }

  Widget _actionMenu(BuildContext context, String title,
      List<(String, WorkspaceIcon, Future<void> Function()?)> actions,
      {required int columns, String? footer}) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
            SizedBox(
              height: 3,
              child: _busy ? const LinearProgressIndicator(minHeight: 2) : null,
            ),
            const SizedBox(height: 8),
            for (var start = 0; start < actions.length; start += columns)
              Padding(
                padding: EdgeInsets.only(bottom: _isActionSheet ? 12 : 8),
                child: Row(
                  spacing: 8,
                  children: [
                    for (final action in actions.skip(start).take(columns))
                      Expanded(
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                _isActionSheet ? Colors.transparent : null,
                            disabledBackgroundColor:
                                _isActionSheet ? Colors.transparent : null,
                            foregroundColor: _isActionSheet
                                ? theme.colorScheme.onSurface
                                : null,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 12),
                            minimumSize: const Size(0, 72),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _busy || action.$3 == null
                              ? null
                              : () => _run(action.$3!),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Opacity(
                                opacity: action.$3 == null || _busy ? .42 : 1,
                                child: AppIcon(action.$2,
                                    size: _isActionSheet ? 29 : 23),
                              ),
                              SizedBox(height: _isActionSheet ? 10 : 6),
                              SizedBox(
                                height: columns == 4 ? 36 : null,
                                child: Align(
                                  alignment: _isActionSheet
                                      ? Alignment.topCenter
                                      : Alignment.center,
                                  child: Text(action.$1,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: columns == 4
                                          ? const TextStyle(
                                              fontSize: 12, height: 1.2)
                                          : null),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (_feedback case final feedback?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(feedback,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium),
                ),
              ),
            if (footer != null) ...[
              const SizedBox(height: 6),
              Text(footer,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.importSheet) return _importMenu(context);
    if (_isActionSheet) {
      final entry = _entry;
      if (entry == null)
        return const Padding(
            padding: EdgeInsets.all(24), child: Text('预设已删除。'));
      return _presetActions(context, entry);
    }
    final sharing = !widget.libraryMode || widget.entry != null;
    final actions = <(String, IconData, Future<void> Function())>[
      if (!widget.libraryMode) ('保存预设', Icons.save_outlined, _save),
      if (!widget.libraryMode)
        (
          '导入预设',
          Icons.file_open_outlined,
          () => showMobilePresetImport(context, workspace)
        ),
      if (sharing) ...[
        ('导出 .lmp', Icons.file_download_outlined, _exportFile),
        ('导出文本代码', Icons.text_snippet_outlined, _exportCode),
        ('保存二维码图片', Icons.qr_code, () => _exportCode(qr: true)),
      ],
    ];
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.entry?.style.name ??
              (widget.libraryMode ? '导入预设' : '预设保存与分享'))),
      body: SafeArea(
        child: Stack(children: [
          ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final action in actions)
                ListTile(
                  key: ValueKey(action.$1),
                  leading: Icon(action.$2),
                  title: Text(action.$1),
                  onTap: _busy ? null : () => _run(action.$3),
                ),
            ],
          ),
          if (_busy)
            const Positioned(
              top: 0,
              left: 12,
              right: 12,
              child:
                  IgnorePointer(child: LinearProgressIndicator(minHeight: 2)),
            ),
        ]),
      ),
    );
  }
}

class _PresetNameDialog extends StatefulWidget {
  const _PresetNameDialog(this.title, this.label, this.initial);
  final String title, label, initial;

  @override
  State<_PresetNameDialog> createState() => _PresetNameDialogState();
}

class _PresetNameDialogState extends State<_PresetNameDialog> {
  late final _text = TextEditingController(text: widget.initial)
    ..selection =
        TextSelection(baseOffset: 0, extentOffset: widget.initial.length);
  bool _missing = false;

  void _submit() {
    final value = _text.text.trim();
    if (value.isEmpty) {
      setState(() => _missing = true);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 7),
            TextField(
              controller: _text,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(errorText: _missing ? '请输入名称' : null),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: _submit, child: const Text('确定')),
        ],
      );
}

class _SavePresetDialog extends StatefulWidget {
  final AlphaWorkspace workspace;
  const _SavePresetDialog(this.workspace);

  @override
  State<_SavePresetDialog> createState() => _SavePresetDialogState();
}

class _SavePresetDialogState extends State<_SavePresetDialog> {
  late final _name = TextEditingController(text: widget.workspace.style.name);
  String? _replace;
  String _folder = '';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('保存预设'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _replace ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: '保存方式'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('新建用户预设')),
                  for (final item in widget.workspace.userPresets)
                    DropdownMenuItem(
                        value: item.id,
                        child: Text('覆盖 · ${item.style.name}',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) => setState(() {
                  _replace = value == '' ? null : value;
                  if (_replace != null) {
                    _name.text = widget.workspace.userPresets
                        .firstWhere((item) => item.id == _replace)
                        .style
                        .name;
                  }
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _name,
                  decoration:
                      InputDecoration(labelText: '预设名称', errorText: _error)),
              if (_replace == null &&
                  widget.workspace.userFolders.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _folder,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '所属分组'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('未分组')),
                    for (final folder in widget.workspace.userFolders)
                      DropdownMenuItem(
                          value: folder.id,
                          child: Text(folder.name,
                              overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (value) => setState(() => _folder = value ?? ''),
                ),
              ],
            ],
          )),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
              onPressed: () {
                final name = _name.text.trim();
                if (name.isEmpty) {
                  setState(() => _error = '请输入预设名称');
                  return;
                }
                Navigator.pop(
                    context, (name: name, replace: _replace, folder: _folder));
              },
              child: Text(_replace == null ? '新建保存' : '覆盖保存')),
        ],
      );
}

class _PasteCodeDialog extends StatefulWidget {
  const _PasteCodeDialog();
  @override
  State<_PasteCodeDialog> createState() => _PasteCodeDialogState();
}

class _PasteCodeDialogState extends State<_PasteCodeDialog> {
  final _text = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('导入文本代码'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 620),
        scrollable: true,
        content: SizedBox(
          width: 620,
          child: TextField(
            controller: _text,
            maxLines: 4,
            decoration: InputDecoration(hintText: '粘贴预设代码', errorText: _error),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('打开文本文件')),
          FilledButton(
              onPressed: () {
                final text = _text.text.trim();
                if (text.isEmpty) {
                  setState(() => _error = '请粘贴代码');
                  return;
                }
                Navigator.pop(context, text);
              },
              child: const Text('导入')),
        ],
      );
}
