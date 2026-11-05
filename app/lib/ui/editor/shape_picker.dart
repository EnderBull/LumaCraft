import 'package:flutter/material.dart';
import '../../editor/shape_style.dart';
import 'prototype_controls.dart';

/// 在 24 px 网格内绘制各形状的示意图标：统一线宽与圆角，细节用柔和的金色填充。
class ShapeKindIcon extends StatelessWidget {
  final String kind;
  final double size;
  final bool selected;
  const ShapeKindIcon(this.kind,
      {super.key, this.size = 28, this.selected = false});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
        dimension: size,
        child: CustomPaint(
            painter: _ShapeIconPainter(
                kind,
                selected ? scheme.primary : scheme.onSurface.withValues(alpha: .78),
                const Color(0xffd7aa59))));
  }
}

class _ShapeIconPainter extends CustomPainter {
  final String kind;
  final Color line, detail;
  _ShapeIconPainter(this.kind, this.line, this.detail);

  static Path _polygon(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = detail.withValues(alpha: .24);
    if (kind == 'line') {
      canvas.drawLine(const Offset(4, 12), const Offset(20, 12),
          Paint()
            ..color = line
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round);
      canvas.drawCircle(const Offset(4, 12), 1.5, Paint()..color = detail);
      canvas.drawCircle(const Offset(20, 12), 1.5, Paint()..color = detail);
      return;
    }
    final Path path = switch (kind) {
      'rect' => Path()
        ..addRRect(RRect.fromRectAndRadius(
            const Rect.fromLTWH(3.5, 6, 17, 12), const Radius.circular(3))),
      'triangle' => _polygon(const [Offset(12, 4.5), Offset(20.5, 19), Offset(3.5, 19)]),
      'circle' => Path()..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8.5)),
      'parallelogram' => _polygon(const [
          Offset(8.5, 6),
          Offset(21, 6),
          Offset(15.5, 18),
          Offset(3, 18)
        ]),
      'trapezoid' => _polygon(const [
          Offset(8, 6),
          Offset(16, 6),
          Offset(21.5, 18),
          Offset(2.5, 18)
        ]),
      'diamond' => _polygon(const [
          Offset(12, 3),
          Offset(21.5, 12),
          Offset(12, 21),
          Offset(2.5, 12)
        ]),
      'hexagon' => _polygon(const [
          Offset(2.8, 12),
          Offset(7.4, 4.6),
          Offset(16.6, 4.6),
          Offset(21.2, 12),
          Offset(16.6, 19.4),
          Offset(7.4, 19.4)
        ]),
      _ => Path()
    };
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _ShapeIconPainter old) =>
      old.kind != kind || old.line != line || old.detail != detail;
}

/// 形状选择器：点击后弹出 4 列 × 2 行的图标网格，图标下方为小字名称。
/// 与其他下拉一致：直接打开和关闭、无动画，点击外部或按 Esc 关闭。
class ShapePicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const ShapePicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final fill =
        theme.inputDecorationTheme.fillColor ?? theme.scaffoldBackgroundColor;
    return Builder(
        builder: (fieldContext) => SizedBox(
            height: 38,
            child: TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    foregroundColor: scheme.onSurface,
                    backgroundColor: fill,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5))),
                onPressed: () async {
                  final box = fieldContext.findRenderObject() as RenderBox;
                  final overlay = Navigator.of(context)
                      .overlay!
                      .context
                      .findRenderObject() as RenderBox;
                  final origin =
                      box.localToGlobal(Offset.zero, ancestor: overlay);
                  final selected = await showMenu<String>(
                      context: context,
                      popUpAnimationStyle: AnimationStyle.noAnimation,
                      position: RelativeRect.fromRect(
                          Rect.fromLTWH(origin.dx,
                              origin.dy + box.size.height + 5, box.size.width, 0),
                          Offset.zero & overlay.size),
                      constraints:
                          BoxConstraints.tightFor(width: box.size.width),
                      color: scheme.surface,
                      surfaceTintColor: Colors.transparent,
                      elevation: 12,
                      shadowColor: Colors.black.withValues(alpha: .5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: scheme.onSurface.withValues(alpha: .08))),
                      menuPadding: const EdgeInsets.all(6),
                      items: [_ShapeGridEntry(value)]);
                  if (context.mounted && selected != null && selected != value) {
                    onChanged(selected);
                  }
                },
                child: Row(children: [
                  ShapeKindIcon(value, size: 22, selected: true),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(shapeKindNames[value] ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: EditorTypography.value(context))),
                  const SizedBox(width: 8),
                  const PrototypeIcon('chevronDown', size: 14)
                ]))));
  }
}

class _ShapeGridEntry extends PopupMenuEntry<String> {
  final String value;
  const _ShapeGridEntry(this.value);
  @override
  double get height => 168;
  @override
  bool represents(String? v) => false;
  @override
  State<_ShapeGridEntry> createState() => _ShapeGridEntryState();
}

class _ShapeGridEntryState extends State<_ShapeGridEntry> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final kinds = shapeKindNames.entries.toList();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (var row = 0; row < 2; row++)
        Padding(
            padding: EdgeInsets.only(top: row == 0 ? 0 : 4),
            child: Row(children: [
              for (var col = 0; col < 4; col++)
                Expanded(child: _cell(context, scheme, kinds[row * 4 + col]))
            ]))
    ]);
  }

  Widget _cell(BuildContext context, ColorScheme scheme,
      MapEntry<String, String> kind) {
    final selected = kind.key == widget.value;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Semantics(
            button: true,
            selected: selected,
            label: kind.value,
            child: InkWell(
                borderRadius: BorderRadius.circular(6),
                hoverColor: scheme.onSurface.withValues(alpha: .06),
                onTap: () => Navigator.pop(context, kind.key),
                child: Container(
                    height: 74,
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
                          ShapeKindIcon(kind.key, size: 30, selected: selected),
                          const SizedBox(height: 7),
                          Text(kind.value,
                              maxLines: 1,
                              overflow: TextOverflow.visible,
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
