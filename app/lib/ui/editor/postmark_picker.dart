import 'package:flutter/material.dart';
import '../../editor/postmark.dart';
import 'hsb_color_picker.dart';
import 'prototype_controls.dart';

class _PostmarkPainter extends CustomPainter {
  final String kind;
  final Color ink;
  _PostmarkPainter(this.kind, this.ink);
  @override
  void paint(Canvas canvas, Size size) {
    final design = postmarkSize(kind);
    final k = (size.width / design.width) < (size.height / design.height)
        ? size.width / design.width
        : size.height / design.height;
    canvas.translate((size.width - design.width * k) / 2,
        (size.height - design.height * k) / 2);
    canvas.scale(k);
    paintPostmark(canvas, kind, ink);
  }

  @override
  bool shouldRepaint(covariant _PostmarkPainter old) =>
      old.kind != kind || old.ink != ink;
}

const _cellWidth = 116.0, _cellHeight = 96.0;

/// 内置素材选择。目前只有“邮戳”一类，选中后返回样式和墨色。
Future<(String, int)?> showBuiltinMaterialPicker(
    BuildContext anchor, int color, String? current) async {
  final scheme = Theme.of(anchor).colorScheme;
  final box = anchor.findRenderObject() as RenderBox;
  final overlay =
      Navigator.of(anchor).overlay!.context.findRenderObject() as RenderBox;
  final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
  const width = _cellWidth * 3 + 12;
  final raw = await showMenu<String>(
      context: anchor,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      position: RelativeRect.fromRect(
          Rect.fromLTWH(origin.dx + box.size.width - width,
              origin.dy + box.size.height + 5, width, 0),
          Offset.zero & overlay.size),
      constraints: const BoxConstraints.tightFor(width: width),
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: .5),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scheme.onSurface.withValues(alpha: .08))),
      menuPadding: const EdgeInsets.all(6),
      items: [_MaterialMenu(color, current)]);
  if (raw == null) return null;
  final parts = raw.split('|');
  if (parts.length != 2 || !postmarkKinds.containsKey(parts[0])) return null;
  final parsed = int.tryParse(parts[1], radix: 16);
  if (parsed == null) return null;
  return (parts[0], parsed);
}

class _MaterialMenu extends PopupMenuEntry<String> {
  final int color;
  final String? current;
  const _MaterialMenu(this.color, this.current);
  @override
  double get height => 28 + 48 + 8 + _cellHeight;
  @override
  bool represents(String? value) => false;
  @override
  State<_MaterialMenu> createState() => _MaterialMenuState();
}

class _MaterialMenuState extends State<_MaterialMenu> {
  late int color = widget.color;
  Future<void> chooseColor() async {
    var next = color;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => HsbColorPicker(
            initialColor: Color(color),
            onChanged: (c) => next = c.toARGB32()));
    if (ok == true && mounted) setState(() => color = next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
          child: Text('邮戳',
              style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: EditorTypography.dimOn(context)))),
      Row(children: [
        ColorSwatchButton(
            color: Color(color), label: '邮戳墨色', onPressed: chooseColor),
        const SizedBox(width: 8),
        Expanded(
            child: PostmarkInkRow(
                color: color, onChanged: (v) => setState(() => color = v)))
      ]),
      const SizedBox(height: 8),
      Row(children: [
        for (final kind in postmarkKinds.entries)
          Expanded(child: _cell(scheme, kind.key, kind.value))
      ])
    ]);
  }

  Widget _cell(ColorScheme scheme, String kind, String label) {
    final selected = kind == widget.current;
    final token = (color & 0xffffffff).toRadixString(16).padLeft(8, '0');
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Semantics(
            button: true,
            selected: selected,
            label: label,
            child: InkWell(
                borderRadius: BorderRadius.circular(6),
                hoverColor: scheme.onSurface.withValues(alpha: .06),
                onTap: () => Navigator.pop(context, '$kind|$token'),
                child: Container(
                    height: _cellHeight,
                    decoration: BoxDecoration(
                        color: selected ? scheme.surfaceContainerHighest : null,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: selected
                                ? scheme.primary.withValues(alpha: .8)
                                : Colors.transparent)),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                              width: 92,
                              height: 54,
                              decoration: BoxDecoration(
                                  color: const Color(0xfff6f3ec),
                                  borderRadius: BorderRadius.circular(4)),
                              padding: const EdgeInsets.all(5),
                              child: CustomPaint(
                                  painter: _PostmarkPainter(kind, Color(color)))),
                          const SizedBox(height: 7),
                          Text(label,
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                  fontSize: 11,
                                  height: 1.2,
                                  color: selected
                                      ? scheme.primary
                                      : scheme.onSurface
                                          .withValues(alpha: .72)))
                        ])))));
  }
}

/// 邮戳墨色：四个快捷色，点中的和当前颜色一致时高亮。
class PostmarkInkRow extends StatelessWidget {
  final int color;
  final ValueChanged<int> onChanged;
  const PostmarkInkRow(
      {super.key, required this.color, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      for (final e in postmarkInks.entries) ...[
        Expanded(
            child: Semantics(
                button: true,
                selected: e.value.$2 == color,
                label: '${e.value.$1}色墨',
                child: TextButton(
                    style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: EdgeInsets.zero,
                        backgroundColor: e.value.$2 == color
                            ? scheme.surfaceContainerHighest
                            : null,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(
                                color: e.value.$2 == color
                                    ? scheme.primary.withValues(alpha: .8)
                                    : scheme.onSurface
                                        .withValues(alpha: .08)))),
                    onPressed: () => onChanged(e.value.$2),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                  color: Color(e.value.$2),
                                  borderRadius: BorderRadius.circular(3))),
                          const SizedBox(width: 6),
                          Text(e.value.$1,
                              style: TextStyle(
                                  fontSize: 12, color: scheme.onSurface))
                        ])))),
        if (e.key != postmarkInks.keys.last) const SizedBox(width: 6),
      ]
    ]);
  }
}
