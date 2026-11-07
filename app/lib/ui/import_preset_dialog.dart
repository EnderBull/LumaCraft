import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../editor/preset_code.dart';
import '../editor/qr_scan.dart';
import '../editor/style_document.dart';
import 'editor/prototype_controls.dart';
import 'workspace_dialog.dart';

/// How a preset arrived.
enum ImportSource { lmpFile, code, image }

/// What the import panel produced: either a decoded preset, or a file the
/// caller still has to read (a `.lmp` may hold several presets, so its
/// parsing stays with the existing import flow).
class ImportedPreset {
  final StyleDocument? style;
  final String? filePath;
  final ImportSource source;
  const ImportedPreset.preset(this.style, this.source) : filePath = null;
  const ImportedPreset.file(this.filePath) : style = null, source = ImportSource.lmpFile;
}

Future<ImportedPreset?> showImportPresetDialog(BuildContext context) =>
    showDialog<ImportedPreset>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const _ImportPresetDialog());

class _ImportPresetDialog extends StatefulWidget {
  const _ImportPresetDialog();
  @override
  State<_ImportPresetDialog> createState() => _ImportPresetDialogState();
}

class _ImportPresetDialogState extends State<_ImportPresetDialog> {
  static const panelWidth = 560.0;

  final input = TextEditingController();
  String? error;
  bool busy = false;

  bool get dark => Theme.of(context).brightness == Brightness.dark;

  /// Same quiet fill used elsewhere in the panel set, for the code field.
  Color get softFill => Theme.of(context)
      .colorScheme
      .onSurface
      .withValues(alpha: dark ? .055 : .045);

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void _fail(String message) {
    if (mounted) setState(() {
      error = message;
      busy = false;
    });
  }

  void _done(StyleDocument style, ImportSource source) {
    if (mounted) Navigator.pop(context, ImportedPreset.preset(style, source));
  }

  /// Reads a `.lmp` file. The heavy parsing stays in the caller so this panel
  /// only reports what happened.
  Future<void> _pickFile() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final file = await openFile(acceptedTypeGroups: [
        const XTypeGroup(label: 'LumaCraft 预设', extensions: ['lmp'])
      ]);
      if (file == null) {
        if (mounted) setState(() => busy = false);
        return;
      }
      if (mounted)
        Navigator.pop(context, ImportedPreset.file(file.path));
    } catch (e) {
      _fail('读取文件失败：$e');
    }
  }

  /// Picks a shared picture and looks for the QR code inside it.
  Future<void> _pickImage() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final file = await openFile(acceptedTypeGroups: [
        XTypeGroup(label: '分享图片', extensions: ['png', 'jpg', 'jpeg'])
      ]);
      if (file == null) {
        if (mounted) setState(() => busy = false);
        return;
      }
      if (await File(file.path).length() > qrImageMaxBytes) {
        _fail('图片文件过大，请换一张分享图');
        return;
      }
      final bytes = await File(file.path).readAsBytes();
      if (!mounted) return;
      final text = await scanQrCodeAsync(bytes);
      if (!mounted) return;
      if (text == null) {
        _fail('这张图片里没有找到可以识别的二维码，请确认是分享出来的图片');
        return;
      }
      await _applyCode(text, fromImage: true);
    } on FormatException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('读取图片失败：$e');
    }
  }

  void _submitCode() {
    setState(() {
      busy = true;
      error = null;
    });
    _applyCode(input.text);
  }

  Future<void> _applyCode(String text, {bool fromImage = false}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _fail('请先粘贴文本代码');
      return;
    }
    try {
      _done(await decodePresetCodeAsync(trimmed),
          fromImage ? ImportSource.image : ImportSource.code);
    } catch (e) {
      _fail(e is FormatException ? e.message : '这段代码无法识别：$e');
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _fail('剪贴板里没有文字');
      return;
    }
    setState(() {
      input.text = text;
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
        backgroundColor: scheme.surface,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
                width: panelWidth,
                child: DefaultTextStyle(
                    style: dialogBodyStyle.copyWith(color: scheme.onSurface),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      _header(),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(28, 4, 28, 26),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _fileActions(),
                                const SizedBox(height: 20),
                                _orDivider(),
                                const SizedBox(height: 20),
                                _codeSection()
                              ])),
                      _actions()
                    ])))));
  }

  Widget _header() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.fromLTRB(28, 22, 22, 6),
        child: Row(children: [
          Text('导入预设',
              style: dialogTitleStyle.copyWith(
                  fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.2)),
          const Spacer(),
          SizedBox(
              width: 30,
              height: 30,
              child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded,
                      size: 18,
                      color: scheme.onSurface.withValues(alpha: .62))))
        ]));
  }

  /// Two source cards across the top, then the code field below: the two
  /// "hand me something" actions sit together, and pasting stays separate.
  Widget _fileActions() => Row(children: [
        Expanded(
            child: _sourceCard(
                icon: 'importFile',
                title: '从文件导入',
                detail: '选择 .lmp 预设文件',
                onTap: busy ? null : _pickFile)),
        const SizedBox(width: 12),
        Expanded(
            child: _sourceCard(
                icon: 'importQr',
                title: '从图片导入',
                detail: '自动读取图中的二维码',
                onTap: busy ? null : _pickImage))
      ]);

  Widget _sourceCard(
      {required String icon,
      required String title,
      required String detail,
      VoidCallback? onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
        color: softFill,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drawn in the same stroke family as the rest of the
                      // app's icons, with one warm detail picking out the
                      // action.
                      PrototypeIcon(icon, ui: true, size: 26),
                      const SizedBox(height: 11),
                      Text(title,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .1,
                              color: scheme.onSurface)),
                      const SizedBox(height: 4),
                      Text(detail,
                          style: EditorTypography.hint(context)
                              .copyWith(fontSize: 11.5, height: 1.5))
                    ]))));
  }

  /// Quiet rule with a word in the middle, matching the share panel's habit of
  /// fading its dividers at both ends.
  Widget _orDivider() {
    final scheme = Theme.of(context).colorScheme;
    final line = scheme.onSurface.withValues(alpha: dark ? .10 : .12);
    Widget rule() => Expanded(
            child: Container(
                height: 1,
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                  line.withValues(alpha: 0),
                  line,
                  line,
                  line.withValues(alpha: 0)
                ], stops: const [0, .2, .8, 1]))));
    return Row(children: [
      rule(),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('或者粘贴文本代码',
              style: EditorTypography.hint(context)
                  .copyWith(fontSize: 11.5, letterSpacing: .2))),
      rule()
    ]);
  }

  Widget _codeSection() {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('文本代码',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: .3,
                color: scheme.onSurface)),
        const Spacer(),
        SizedBox(
            height: 26,
            child: TextButton.icon(
                onPressed: busy ? null : _paste,
                icon: const Icon(Icons.content_paste_rounded, size: 13),
                label: const Text('粘贴', style: TextStyle(fontSize: 11.5)),
                style: TextButton.styleFrom(
                    foregroundColor: scheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 26),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)))))
      ]),
      const SizedBox(height: 8),
      TextField(
          controller: input,
          minLines: 3,
          maxLines: 3,
          autofocus: true,
          style: TextStyle(
              fontFamily: 'Consolas',
              fontFamilyFallback: const ['Courier New', 'monospace'],
              fontSize: 12,
              height: 1.5,
              letterSpacing: .2,
              color: scheme.onSurface),
          decoration: InputDecoration(
              hintText: 'LC1:...',
              hintStyle: TextStyle(
                  fontFamily: 'Consolas',
                  fontFamilyFallback: const ['Courier New', 'monospace'],
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: .32)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11)),
          onSubmitted: (_) => _submitCode())
    ]);
  }

  Widget _actions() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
        padding: const EdgeInsets.fromLTRB(28, 14, 28, 18),
        decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .26 : .07),
                  blurRadius: 18,
                  offset: const Offset(0, -4))
            ]),
        child: Row(children: [
          Expanded(
              child: Text(error ?? '',
                  maxLines: 2,
                  style: EditorTypography.hint(context).copyWith(
                      fontSize: 11.5,
                      height: 1.5,
                      color: error == null
                          ? Colors.transparent
                          : scheme.error))),
          const SizedBox(width: 12),
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
                  onPressed: busy ? null : _submitCode,
                  child: const Text('导入')))
        ]));
  }
}

Future<ImportedPreset?> importPresetPanel(BuildContext context) =>
    showImportPresetDialog(context);
