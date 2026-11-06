import 'package:flutter/material.dart';
import 'prototype_controls.dart';

/// 「添加组件」下拉菜单每行放几个组件。
/// 行数由入口数量自动算出。当前是 9 个组件再加“内置素材”，3 列 × 4 行。
const componentPickerColumns = 3;

/// 单个格子的宽度与高度。
const componentPickerCellWidth = 86.0, componentPickerCellHeight = 78.0;

class ComponentChoice {
  final String key, label, icon;
  const ComponentChoice(this.key, this.label, this.icon);
}

/// 菜单行数（向上取整）。
int componentPickerRows(int count) =>
    (count + componentPickerColumns - 1) ~/ componentPickerColumns;

/// 贴着 [anchor] 按钮展开的轻量下拉菜单：直接打开和关闭、无动画，
/// 点击外部或按 Esc 关闭，点选后返回组件类型。
Future<String?> showComponentPicker(
    BuildContext anchor, List<ComponentChoice> choices) {
  final scheme = Theme.of(anchor).colorScheme;
  final box = anchor.findRenderObject() as RenderBox;
  final overlay =
      Navigator.of(anchor).overlay!.context.findRenderObject() as RenderBox;
  final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
  const padding = 6.0;
  final width = componentPickerColumns * componentPickerCellWidth + padding * 2;
  return showMenu<String>(
      context: anchor,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      position: RelativeRect.fromRect(
          Rect.fromLTWH(origin.dx, origin.dy + box.size.height + 5,
              box.size.width, 0),
          Offset.zero & overlay.size),
      constraints: BoxConstraints.tightFor(width: width),
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: .5),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scheme.onSurface.withValues(alpha: .08))),
      menuPadding: const EdgeInsets.all(padding),
      items: [_ComponentGridEntry(choices)]);
}

class _ComponentGridEntry extends PopupMenuEntry<String> {
  final List<ComponentChoice> choices;
  const _ComponentGridEntry(this.choices);
  @override
  double get height => componentPickerRows(choices.length) *
      (componentPickerCellHeight + 4);
  @override
  bool represents(String? value) => false;
  @override
  State<_ComponentGridEntry> createState() => _ComponentGridEntryState();
}

class _ComponentGridEntryState extends State<_ComponentGridEntry> {
  @override
  Widget build(BuildContext context) {
    final rows = componentPickerRows(widget.choices.length);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (var row = 0; row < rows; row++)
        Padding(
            padding: EdgeInsets.only(top: row == 0 ? 0 : 4),
            child: Row(children: [
              for (var col = 0; col < componentPickerColumns; col++)
                Expanded(
                    child: row * componentPickerColumns + col <
                            widget.choices.length
                        ? _cell(context,
                            widget.choices[row * componentPickerColumns + col])
                        : const SizedBox.shrink())
            ]))
    ]);
  }

  Widget _cell(BuildContext context, ComponentChoice choice) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Semantics(
            button: true,
            label: choice.label,
            child: InkWell(
                borderRadius: BorderRadius.circular(6),
                hoverColor: scheme.onSurface.withValues(alpha: .06),
                onTap: () => Navigator.pop(context, choice.key),
                child: SizedBox(
                    height: componentPickerCellHeight,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PrototypeIcon(choice.icon, size: 30),
                          const SizedBox(height: 8),
                          Text(choice.label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: TextStyle(
                                  fontSize: 12,
                                  height: 1.2,
                                  color: scheme.onSurface
                                      .withValues(alpha: .82)))
                        ])))));
  }
}
