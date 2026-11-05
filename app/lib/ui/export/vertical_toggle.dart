import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Compact vertical switch with a larger thumb and redundant state glyph.
class VerticalToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  const VerticalToggle(
      {super.key,
      required this.value,
      required this.onChanged,
      required this.label});
  @override
  State<VerticalToggle> createState() => _VerticalToggleState();
}

class _VerticalToggleState extends State<VerticalToggle> {
  bool focused = false;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
        label: widget.label,
        toggled: widget.value,
        button: true,
        child: FocusableActionDetector(
            mouseCursor: SystemMouseCursors.click,
            onShowFocusHighlight: (v) => setState(() => focused = v),
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent()
            },
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
                widget.onChanged(!widget.value);
                return null;
              })
            },
            child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onChanged(!widget.value),
                child: SizedBox(
                    width: 34,
                    height: 48,
                    child: Center(
                        child: Container(
                            width: 28,
                            height: 46,
                            decoration: BoxDecoration(
                                color: widget.value
                                    ? scheme.primary.withValues(alpha: .75)
                                    : scheme.onSurface.withValues(alpha: .15),
                                borderRadius: BorderRadius.circular(15),
                                border: focused
                                    ? Border.all(
                                        color: scheme.primary, width: 1.5)
                                    : null),
                            child: Stack(children: [
                              AnimatedPositioned(
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                          ? Duration.zero
                                          : const Duration(milliseconds: 150),
                                  curve: Curves.easeOut,
                                  left: 3,
                                  top: widget.value ? 3 : 21,
                                  child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                          color: widget.value
                                              ? scheme.onPrimary
                                              : scheme.onSurface
                                                  .withValues(alpha: .60),
                                          shape: BoxShape.circle),
                                      child: CustomPaint(
                                          painter: _StateGlyph(
                                              widget.value,
                                              widget.value
                                                  ? scheme.primary
                                                  : scheme.surface))))
                            ])))))));
  }
}

class _StateGlyph extends CustomPainter {
  final bool checked;
  final Color color;
  _StateGlyph(this.checked, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (checked) {
      canvas.drawPath(
          Path()
            ..moveTo(6, 11)
            ..lineTo(9.5, 14.5)
            ..lineTo(16, 7.5),
          pen);
    } else {
      canvas.drawLine(const Offset(7.5, 7.5), const Offset(14.5, 14.5), pen);
      canvas.drawLine(const Offset(14.5, 7.5), const Offset(7.5, 14.5), pen);
    }
  }

  @override
  bool shouldRepaint(_StateGlyph old) =>
      old.checked != checked || old.color != color;
}
