import 'package:flutter/material.dart';
import '../../export/export_options.dart';
import '../editor/prototype_controls.dart';
import '../workspace_dialog.dart';

class NamingTemplateEditor extends StatefulWidget {
  final List<NamingPart> parts;
  final ValueChanged<List<NamingPart>> onChanged;
  final String extension;
  const NamingTemplateEditor(
      {super.key,
      required this.parts,
      required this.onChanged,
      this.extension = 'jpg'});
  @override
  State<NamingTemplateEditor> createState() => _NamingTemplateEditorState();
}

class _NamingTemplateEditorState extends State<NamingTemplateEditor> {
  final controllers = <int, TextEditingController>{};
  final focuses = <int, FocusNode>{};
  int? active;
  List<NamingPart> get parts => widget.parts;
  @override
  void initState() {
    super.initState();
    normalise();
  }

  @override
  void didUpdateWidget(covariant NamingTemplateEditor old) {
    super.didUpdateWidget(old);
    if (!identical(old.parts, parts)) normalise();
  }

  void normalise() {
    if (parts.isEmpty || parts.last.variable || parts.last.value.isNotEmpty)
      parts.add(NamingPart.text(''));
    final tailId = parts.last.id;
    parts.removeWhere((p) =>
        !p.variable && p.value.isEmpty && p.id != tailId && p.id != active);
    for (var i = 0; i + 1 < parts.length;) {
      final left = parts[i], right = parts[i + 1];
      if (left.variable || right.variable || right.id == tailId) {
        i++;
        continue;
      }
      final prefix = left.value.length;
      final previousSelection = input(left).selection;
      final rightSelection = input(right).selection;
      final offset = active == right.id
          ? prefix + (rightSelection.isValid ? rightSelection.extentOffset : 0)
          : previousSelection.isValid
              ? previousSelection.extentOffset
              : prefix;
      left.value += right.value;
      input(left).value = TextEditingValue(
          text: left.value,
          selection: TextSelection.collapsed(
              offset: offset.clamp(0, left.value.length)));
      if (active == right.id) active = left.id;
      parts.removeAt(i + 1);
    }
  }

  double textWidth(NamingPart part, TextStyle style) {
    final text = part.value.isEmpty && identical(part, parts.last)
        ? '输入文字…'
        : part.value;
    final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context))
      ..layout();
    final width = (painter.width.ceilToDouble() + 6).clamp(6.0, 240.0);
    painter.dispose();
    return width;
  }

  TextEditingController input(NamingPart part) => controllers.putIfAbsent(
      part.id, () => TextEditingController(text: part.value));
  FocusNode focus(NamingPart part) =>
      focuses.putIfAbsent(part.id, () => FocusNode());
  void focusActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final part =
          parts.where((p) => p.id == active && !p.variable).firstOrNull;
      if (part != null) focus(part).requestFocus();
    });
  }

  void insert(String value) {
    final i = parts.indexWhere((p) => p.id == active && !p.variable);
    if (i >= 0) {
      final old = parts[i], controller = input(old);
      final selection = controller.selection;
      final start =
          selection.isValid ? selection.start : controller.text.length;
      final end = selection.isValid ? selection.end : start;
      final right = NamingPart.text(controller.text.substring(end));
      final left = NamingPart.text(controller.text.substring(0, start));
      parts.replaceRange(i, i + 1, [left, NamingPart.variable(value), right]);
      active = right.id;
      input(right).selection = const TextSelection.collapsed(offset: 0);
    } else {
      final tail = NamingPart.text('');
      parts.addAll([NamingPart.variable(value), tail]);
      active = tail.id;
    }
    normalise();
    widget.onChanged(parts);
    setState(() {});
    focusActive();
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    for (final f in focuses.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final literalStyle = dialogBodyStyle.copyWith(
        fontSize: 13, height: 1.5, color: scheme.onSurface);
    final example = parts
        .map((p) => !p.variable
            ? p.value
            : const {
                  'name': 'DSC_3079',
                  'date': '20210620',
                  'time': '164501',
                  'seq': '1',
                  'seq:3': '001',
                  'yyyy': '2021',
                  'MM': '06',
                  'dd': '20',
                  'HH': '16',
                  'mm': '45',
                  'ss': '01',
                  'camera': 'ILCE-6300',
                  'lens': '30mm',
                  'iso': '100',
                  'focal': '30',
                  'fnum': '4.0',
                  'shutter': '1-2000'
                }[p.value] ??
                '未填写')
        .join();
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('命名模板', style: EditorTypography.label(context)),
          const SizedBox(height: 8),
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Theme.of(context).inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(6)),
              child: Wrap(
                  spacing: 3,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final part in parts)
                      if (part.variable)
                        Container(
                            key: ValueKey('token:${part.id}'),
                            height: 32,
                            padding: const EdgeInsets.only(left: 9, right: 3),
                            decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(5)),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('{${part.value}}',
                                  style: TextStyle(
                                      fontSize: 12, color: scheme.primary)),
                              const SizedBox(width: 4),
                              SizedBox(
                                  width: 24,
                                  height: 26,
                                  child: IconButton(
                                      padding: EdgeInsets.zero,
                                      tooltip: '移除 {${part.value}}',
                                      icon: const Icon(Icons.close_rounded,
                                          size: 14),
                                      onPressed: () {
                                        setState(() {
                                          parts.remove(part);
                                          normalise();
                                        });
                                        widget.onChanged(parts);
                                      }))
                            ]))
                      else
                        SizedBox(
                            width: textWidth(part, literalStyle),
                            child: TextField(
                                key: ValueKey('literal:${part.id}'),
                                controller: input(part),
                                focusNode: focus(part),
                                style: literalStyle,
                                decoration: InputDecoration(
                                    hintText: identical(part, parts.last)
                                        ? '输入文字…'
                                        : null,
                                    filled: false,
                                    isDense: true,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 2, vertical: 9)),
                                onTap: () => active = part.id,
                                onChanged: (v) {
                                  part.value = v;
                                  active = part.id;
                                  normalise();
                                  if (active != part.id) focusActive();
                                  setState(() {});
                                  widget.onChanged(parts);
                                }))
                  ])),
          const SizedBox(height: 7),
          Text('点击变量插入；× 移除模块。普通文字可直接编辑，扩展名由导出格式自动添加。',
              style: EditorTypography.hint(context).copyWith(fontSize: 12)),
          const SizedBox(height: 13),
          for (final group in namingVariables.entries)
            Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 42,
                          child: Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Text(group.key,
                                  style: EditorTypography.hint(context)
                                      .copyWith(fontSize: 12)))),
                      Expanded(
                          child: Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final variable in group.value.entries)
                          SizedBox(
                              height: 30,
                              child: TextButton(
                                  onPressed: () => insert(variable.key),
                                  style: TextButton.styleFrom(
                                      backgroundColor:
                                          scheme.surfaceContainerHighest,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(5))),
                                  child: Text(
                                      '{${variable.key}}  ${variable.value}',
                                      style: const TextStyle(fontSize: 12))))
                      ]))
                    ])),
          const SizedBox(height: 8),
          Row(children: [
            Text('示例',
                style: EditorTypography.hint(context).copyWith(fontSize: 12)),
            const SizedBox(width: 12),
            Expanded(
                child: Text('$example.${widget.extension}',
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis))
          ]),
          const SizedBox(height: 4),
          Text('示例使用演示拍摄信息；正式导出前将检查缺失字段与重名。',
              style: EditorTypography.hint(context).copyWith(fontSize: 11))
        ]);
  }
}
