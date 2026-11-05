import 'package:flutter/material.dart';
import '../../editor/postmark.dart';

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

/// 内置邮戳选择：贴着按钮弹出 3 款缩略图，直接打开和关闭、无动画。
Future<String?> showPostmarkPicker(
    BuildContext anchor, String ink, String? current) {
  final scheme = Theme.of(anchor).colorScheme;
  final box = anchor.findRenderObject() as RenderBox;
  final overlay =
      Navigator.of(anchor).overlay!.context.findRenderObject() as RenderBox;
  final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
  const width = _cellWidth * 3 + 12;
  return showMenu<String>(
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
      items: [_PostmarkGridEntry(Color(postmarkInks[ink]!.$2), current)]);
}

class _PostmarkGridEntry extends PopupMenuEntry<String> {
  final Color ink;
  final String? current;
  const _PostmarkGridEntry(this.ink, this.current);
  @override
  double get height => _cellHeight;
  @override
  bool represents(String? value) => false;
  @override
  State<_PostmarkGridEntry> createState() => _PostmarkGridEntryState();
}

class _PostmarkGridEntryState extends State<_PostmarkGridEntry> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      for (final kind in postmarkKinds.entries)
        Expanded(child: _cell(scheme, kind.key, kind.value))
    ]);
  }

  Widget _cell(ColorScheme scheme, String kind, String label) {
    final selected = kind == widget.current;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Semantics(
            button: true,
            selected: selected,
            label: label,
            child: InkWell(
                borderRadius: BorderRadius.circular(6),
                hoverColor: scheme.onSurface.withValues(alpha: .06),
                onTap: () => Navigator.pop(context, kind),
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
                                  painter: _PostmarkPainter(kind, widget.ink))),
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

/// 邮戳墨色：四个圆角色块并排，当前墨色高亮。
class PostmarkInkRow extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const PostmarkInkRow(
      {super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      for (final e in postmarkInks.entries) ...[
        Expanded(
            child: Semantics(
                button: true,
                selected: e.key == value,
                label: '${e.value.$1}色墨',
                child: TextButton(
                    style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: EdgeInsets.zero,
                        backgroundColor: e.key == value
                            ? scheme.surfaceContainerHighest
                            : null,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(
                                color: e.key == value
                                    ? scheme.primary.withValues(alpha: .8)
                                    : scheme.onSurface
                                        .withValues(alpha: .08)))),
                    onPressed: () => onChanged(e.key),
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
