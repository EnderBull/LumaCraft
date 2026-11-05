import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../export/export_options.dart';
import '../editor/prototype_controls.dart';
import '../workspace_dialog.dart';
import 'naming_template_editor.dart';
import 'vertical_toggle.dart';
import '../editor/number_drag_input.dart';

class ExportDialog extends StatefulWidget {
  final ExportOptions options;
  final List<NamingPart> template;
  final int selectedCount, editedCount;
  final Future<String?> Function()? chooseDirectory;
  final VoidCallback? onExport, onCancel;
  const ExportDialog(
      {super.key,
      required this.options,
      required this.template,
      this.selectedCount = 0,
      this.editedCount = 0,
      this.chooseDirectory,
      this.onExport,
      this.onCancel});
  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  final scroll = ScrollController();
  final dimensionFocus = FocusNode();
  late final TextEditingController longEdge;
  ExportOptions get settings => widget.options;
  @override
  void initState() {
    super.initState();
    longEdge =
        TextEditingController(text: settings.edgePixels?.toString() ?? '');
  }

  @override
  void dispose() {
    scroll.dispose();
    longEdge.dispose();
    dimensionFocus.dispose();
    super.dispose();
  }

  Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: EditorTypography.label(context)));
  Widget hint(String text) => Text(text,
      style:
          EditorTypography.hint(context).copyWith(fontSize: 12, height: 1.6));
  Widget section(String title, Widget body) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: EditorTypography.title(context)),
        const SizedBox(height: 13),
        body
      ]));
  Widget columns(Widget left, Widget right) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: left),
        const SizedBox(width: 24),
        Expanded(child: right)
      ]);
  Widget toggle(String title, String description, bool value,
          ValueChanged<bool> change) =>
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        VerticalToggle(value: value, onChanged: change, label: title),
        const SizedBox(width: 10),
        Expanded(
            child: GestureDetector(
                onTap: () => change(!value),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 4),
                      hint(description)
                    ])))
      ]);
  TextStyle get dimensionTextStyle => dialogBodyStyle.copyWith(
      fontSize: 13,
      height: 1.5,
      color: Theme.of(context).colorScheme.onSurface);
  Widget dimensionInput() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
            height: 38,
            decoration: BoxDecoration(
                color: Theme.of(context).inputDecorationTheme.fillColor,
                borderRadius: BorderRadius.circular(5)),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(
                      width: 84,
                      child: PrototypeSelect(
                          value: settings.sizeEdge,
                          textStyle: dimensionTextStyle,
                          options: const {'long': '长边', 'short': '短边'},
                          onChanged: (v) =>
                              setState(() => settings.sizeEdge = v))),
                  Expanded(
                      child: NumberDragInput(
                          key: const ValueKey('export-edge-pixels'),
                          controller: longEdge,
                          focusNode: dimensionFocus,
                          spec: const NumberDragSpec(
                              min: 1,
                              max: double.infinity,
                              fallback: 2400,
                              step: 4),
                          onDone: () {
                            if (settings.edgePixels != null)
                              longEdge.text = settings.edgePixels.toString();
                          },
                          onCancel: () => setState(() => settings.edgePixels =
                              int.tryParse(longEdge.text)),
                          style: dimensionTextStyle,
                          decoration: InputDecoration(
                              hintText: '原尺寸',
                              hintStyle: dimensionTextStyle.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: .40)),
                              suffixText: 'px',
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 0)),
                          onChanged: (v) => setState(() {
                                final value = double.tryParse(v);
                                settings.edgePixels =
                                    value != null && value.isFinite
                                        ? value.round()
                                        : null;
                              })))
                ])),
        if (longEdge.text.trim().isNotEmpty &&
            (settings.edgePixels == null ||
                settings.edgePixels! <= 0 ||
                settings.edgePixels! > 16384))
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('请输入 1～16384 的像素值',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error)))
      ]);
  Widget fileAndSize() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 2,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    label('文件格式'),
                    PrototypeSelect(
                        value: settings.format,
                        options: const {'jpg': 'JPG', 'png': 'PNG'},
                        onChanged: (v) => setState(() => settings.format = v))
                  ])),
          const SizedBox(width: 20),
          Expanded(
              flex: 3,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [label('成片尺寸'), dimensionInput()])),
          const SizedBox(width: 20),
          Expanded(
              flex: 3,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Text('画质', style: EditorTypography.label(context)),
                      const Spacer(),
                      Text(
                          settings.format == 'png'
                              ? 'PNG 无损'
                              : '${settings.quality}',
                          style: EditorTypography.hint(context)
                              .copyWith(fontSize: 12))
                    ]),
                    const SizedBox(height: 8),
                    SizedBox(
                        height: 38,
                        child: Slider(
                            value: settings.quality.toDouble(),
                            min: 1,
                            max: 100,
                            onChanged: settings.format == 'png'
                                ? null
                                : (v) => setState(
                                    () => settings.quality = v.round())))
                  ]))
        ]),
        const SizedBox(height: 9),
        hint('留空保留原尺寸；输入像素后按成片长边或短边等比例缩放，含边框。')
      ]);
  Widget informationAndColor() =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: toggle('保留拍摄参数', '相机、镜头、拍摄时间等', settings.retainCaptureInfo,
                (v) => setState(() => settings.retainCaptureInfo = v))),
        const SizedBox(width: 20),
        Expanded(
            child: toggle('保留 GPS', '文件内的精确位置，默认移除', settings.retainGps,
                (v) => setState(() => settings.retainGps = v))),
        const SizedBox(width: 20),
        Expanded(
            child: Tooltip(
                message: '转换为 sRGB，并嵌入 sRGB ICC 配置文件',
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          height: 28,
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('sRGB 色彩',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary)))),
                      const SizedBox(height: 3),
                      hint('转换并嵌入 ICC 配置文件')
                    ])))
      ]);
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = settings.scope == 'current'
        ? 1
        : settings.scope == 'edited'
            ? widget.editedCount
            : widget.selectedCount;
    return Dialog(
        clipBehavior: Clip.antiAlias,
        backgroundColor: scheme.surface,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: DefaultTextStyle(
            style: dialogBodyStyle.copyWith(color: scheme.onSurface),
            child: SizedBox(
                width: 860,
                height: math.min(860, MediaQuery.sizeOf(context).height - 48),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(26, 21, 18, 16),
                          child: Row(children: [
                            const Text('导出照片', style: dialogTitleStyle),
                            const SizedBox(width: 14),
                            Text('$count 张',
                                style: EditorTypography.hint(context)),
                            const Spacer(),
                            IconButton(
                                tooltip: '关闭导出',
                                onPressed: widget.onCancel,
                                icon: const Icon(Icons.close_rounded, size: 20))
                          ])),
                      Expanded(
                          child: Scrollbar(
                              controller: scroll,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                  controller: scroll,
                                  padding:
                                      const EdgeInsets.fromLTRB(26, 0, 26, 2),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        section(
                                            '导出位置',
                                            columns(
                                                Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      label('导出范围'),
                                                      PrototypeSelect(
                                                          value: settings.scope,
                                                          options: {
                                                            'current':
                                                                '当前照片 · 1 张',
                                                            'selected':
                                                                '选中照片 · ${widget.selectedCount} 张',
                                                            'edited':
                                                                '全部已编辑 · ${widget.editedCount} 张'
                                                          },
                                                          onChanged: (v) =>
                                                              setState(() =>
                                                                  settings.scope =
                                                                      v))
                                                    ]),
                                                Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      label('输出目录'),
                                                      Row(children: [
                                                        Expanded(
                                                            child: Container(
                                                                height: 38,
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            12),
                                                                decoration: BoxDecoration(
                                                                    color: Theme.of(context)
                                                                        .inputDecorationTheme
                                                                        .fillColor,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            5)),
                                                                alignment: Alignment
                                                                    .centerLeft,
                                                                child: Tooltip(
                                                                    message:
                                                                        settings
                                                                            .directory,
                                                                    child: Text(
                                                                        settings.directory.isEmpty
                                                                            ? '请选择目录'
                                                                            : settings.directory,
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                        style: const TextStyle(fontSize: 13))))),
                                                        const SizedBox(
                                                            width: 7),
                                                        SizedBox(
                                                            height: 38,
                                                            child: TextButton(
                                                                onPressed: widget
                                                                            .chooseDirectory ==
                                                                        null
                                                                    ? null
                                                                    : () async {
                                                                        final path =
                                                                            await widget.chooseDirectory!();
                                                                        if (mounted &&
                                                                            path !=
                                                                                null)
                                                                          setState(() =>
                                                                              settings.directory = path);
                                                                      },
                                                                child: const Text(
                                                                    '选择',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13))))
                                                      ])
                                                    ]))),
                                        section('文件与尺寸', fileAndSize()),
                                        section(
                                            '文件命名',
                                            NamingTemplateEditor(
                                                parts: widget.template,
                                                extension: settings.format,
                                                onChanged: (_) =>
                                                    setState(() {}))),
                                        section('信息与色彩', informationAndColor())
                                      ])))),
                      Container(
                          padding: const EdgeInsets.fromLTRB(26, 14, 26, 19),
                          decoration:
                              BoxDecoration(color: scheme.surface, boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: .12),
                                blurRadius: 14,
                                offset: const Offset(0, -5))
                          ]),
                          child: Row(children: [
                            Expanded(child: hint('生成新文件 · 保留原图 · 重名时询问')),
                            WorkspaceActionButton(
                                label: '取消', onPressed: widget.onCancel),
                            const SizedBox(width: 10),
                            SizedBox(
                                height: 40,
                                child: FilledButton(
                                    style: FilledButton.styleFrom(
                                        textStyle: dialogActionStyle,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(6))),
                                    onPressed: count > 0 &&
                                            settings.directory.isNotEmpty &&
                                            settings.validate() == null &&
                                            (longEdge.text.trim().isEmpty ||
                                                settings.edgePixels != null)
                                        ? widget.onExport
                                        : null,
                                    child: Text('导出 $count 张照片')))
                          ]))
                    ]))));
  }
}
