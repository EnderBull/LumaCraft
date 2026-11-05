import 'package:flutter/material.dart';

enum WorkspaceIcon {
  text,
  signature,
  parameters,
  camera,
  lens,
  time,
  location,
  save,
  arrowRight,
  visible,
  hidden,
  locked,
  unlocked,
  ungroup,
  drive,
  folder,
  folderOpen,
  folderAdd,
  bottomLayout,
  sideLayout,
  moon,
  sun
}

class AppIcon extends StatelessWidget {
  final WorkspaceIcon icon;
  final double size;
  final Color? color;
  const AppIcon(this.icon, {super.key, this.size = 22, this.color});
  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: size,
      child: CustomPaint(
          painter: _IconPainter(
              icon,
              color ??
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: .7),
              Theme.of(context).colorScheme.primary)));
}

class _IconPainter extends CustomPainter {
  final WorkspaceIcon icon;
  final Color color, accent;
  _IconPainter(this.icon, this.color, this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color.withValues(alpha: .11);
    final detail = Paint()
      ..color = accent
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    void rect(double x, double y, double w, double h, double radius,
        {bool surface = true}) {
      final shape = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h), Radius.circular(radius));
      if (surface) canvas.drawRRect(shape, fill);
      canvas.drawRRect(shape, line);
    }

    void segment(double x, double y, double a, double b, [Paint? pen]) =>
        canvas.drawLine(Offset(x, y), Offset(a, b), pen ?? line);
    switch (icon) {
      case WorkspaceIcon.text:
        segment(5, 7, 5, 4);
        segment(5, 4, 19, 4);
        segment(19, 4, 19, 7);
        segment(12, 4, 12, 18);
        segment(9, 18, 15, 18);
        segment(7, 21, 17, 21, detail);
      case WorkspaceIcon.signature:
        final p = Path()
          ..moveTo(5, 18)
          ..lineTo(6, 14)
          ..lineTo(16, 4)
          ..quadraticBezierTo(18, 2, 20, 5)
          ..lineTo(9, 17)
          ..close();
        canvas.drawPath(p, line);
        segment(14, 6, 18, 10);
        segment(4, 22, 20, 22, detail);
      case WorkspaceIcon.parameters:
        for (final y in [5.0, 12.0, 19.0]) segment(4, y, 20, y);
        segment(8, 3, 8, 7, detail);
        segment(16, 10, 16, 14, detail);
        segment(10, 17, 10, 21, detail);
      case WorkspaceIcon.camera:
        rect(3, 7, 18, 14, 2.5, surface: false);
        segment(7, 7, 9, 4);
        segment(9, 4, 15, 4);
        segment(15, 4, 17, 7);
        canvas.drawCircle(const Offset(12, 14), 4, line);
        segment(18, 10, 18.1, 10, detail);
      case WorkspaceIcon.lens:
        canvas.drawCircle(const Offset(12, 12), 9, line);
        canvas.drawCircle(const Offset(12, 12), 5, line);
        canvas.drawArc(const Rect.fromLTWH(8, 8, 8, 8), 0, 1.9, false,
            detail..style = PaintingStyle.stroke);
      case WorkspaceIcon.time:
        canvas.drawCircle(const Offset(12, 12), 9, line);
        segment(12, 6, 12, 12);
        segment(12, 12, 16, 14, detail);
      case WorkspaceIcon.location:
        final p = Path()
          ..moveTo(12, 22)
          ..cubicTo(8, 17, 4, 13, 4, 9)
          ..cubicTo(4, -1, 20, -1, 20, 9)
          ..cubicTo(20, 13, 16, 17, 12, 22);
        canvas.drawPath(p, line);
        canvas.drawCircle(
            const Offset(12, 9), 3, detail..style = PaintingStyle.stroke);
      case WorkspaceIcon.save:
        final p = Path()
          ..moveTo(6, 4)
          ..lineTo(16, 4)
          ..lineTo(20, 8)
          ..lineTo(20, 18)
          ..quadraticBezierTo(20, 20, 18, 20)
          ..lineTo(6, 20)
          ..quadraticBezierTo(4, 20, 4, 18)
          ..lineTo(4, 6)
          ..quadraticBezierTo(4, 4, 6, 4);
        canvas.drawPath(p, line);
        rect(8, 4, 8, 6, 1, surface: false);
        rect(8, 14, 8, 6, 1, surface: false);
      case WorkspaceIcon.arrowRight:
        segment(5, 12, 19, 12);
        segment(14, 7, 19, 12);
        segment(19, 12, 14, 17);
      case WorkspaceIcon.visible:
      case WorkspaceIcon.hidden:
        final p = Path()
          ..moveTo(2, 12)
          ..quadraticBezierTo(12, 1, 22, 12)
          ..quadraticBezierTo(12, 23, 2, 12);
        canvas.drawPath(p, line);
        canvas.drawCircle(
            const Offset(12, 12), 2.5, detail..style = PaintingStyle.stroke);
        if (icon == WorkspaceIcon.hidden) segment(3, 3, 21, 21);
      case WorkspaceIcon.locked:
      case WorkspaceIcon.unlocked:
        rect(5, 11, 14, 11, 2, surface: false);
        final p = Path()
          ..moveTo(8, 11)
          ..lineTo(8, 7)
          ..cubicTo(8, 1, 16, 1, 16, 7);
        if (icon == WorkspaceIcon.locked) p.lineTo(16, 11);
        canvas.drawPath(p, line);
        segment(12, 15, 12, 18, detail);
      case WorkspaceIcon.ungroup:
        rect(3, 3, 8, 8, 2, surface: false);
        rect(13, 13, 8, 8, 2, surface: false);
        segment(14, 5, 20, 5, detail);
        segment(20, 5, 20, 10, detail);
        segment(4, 14, 4, 19, detail);
        segment(4, 19, 10, 19, detail);
      case WorkspaceIcon.drive:
        rect(3, 5, 18, 15, 3);
        segment(3, 14, 21, 14);
        segment(7, 9, 13, 9);
        segment(7, 17, 10, 17);
        canvas.drawCircle(const Offset(17, 17), 1, detail);
      case WorkspaceIcon.folder:
      case WorkspaceIcon.folderOpen:
      case WorkspaceIcon.folderAdd:
        final back = Path()
          ..moveTo(3, 18)
          ..lineTo(3, 6.5)
          ..quadraticBezierTo(3, 4, 5.5, 4)
          ..lineTo(9, 4)
          ..lineTo(11.5, 6.5)
          ..lineTo(18.5, 6.5)
          ..quadraticBezierTo(21, 6.5, 21, 9)
          ..lineTo(21, 18)
          ..quadraticBezierTo(21, 20.5, 18.5, 20.5)
          ..lineTo(5.5, 20.5)
          ..quadraticBezierTo(3, 20.5, 3, 18)
          ..close();
        canvas.drawPath(back, fill);
        canvas.drawPath(back, line);
        if (icon == WorkspaceIcon.folderOpen) {
          final front = Path()
            ..moveTo(4, 10.5)
            ..lineTo(21, 10.5)
            ..quadraticBezierTo(22, 10.5, 21.5, 12.5)
            ..lineTo(19.5, 19)
            ..quadraticBezierTo(19, 20.5, 17.5, 20.5)
            ..lineTo(6, 20.5)
            ..quadraticBezierTo(4, 20.5, 3.5, 18.5)
            ..lineTo(2.5, 13)
            ..quadraticBezierTo(2, 10.5, 4, 10.5)
            ..close();
          canvas.drawPath(front, Paint()..color = color.withValues(alpha: .16));
          canvas.drawPath(front, line);
          segment(7, 16.5, 12, 16.5, detail);
        } else {
          segment(3, 9.5, 21, 9.5);
          if (icon == WorkspaceIcon.folderAdd) {
            segment(12, 12, 12, 17, detail);
            segment(9.5, 14.5, 14.5, 14.5, detail);
          } else {
            segment(7, 15.5, 12, 15.5, detail);
          }
        }
      case WorkspaceIcon.bottomLayout:
      case WorkspaceIcon.sideLayout:
        rect(2.5, 2.5, 19, 19, 3.5, surface: false);
        final panel = Paint()..color = color.withValues(alpha: .35);
        final isBottom = icon == WorkspaceIcon.bottomLayout;
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(5.5, 5.5, 3, isBottom ? 8 : 13),
                const Radius.circular(1)),
            panel);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(15.5, 5.5, 3, isBottom ? 8 : 13),
                const Radius.circular(1)),
            panel);
        segment(isBottom ? 6 : 11, 17.5, isBottom ? 18 : 13, 17.5, detail);
      case WorkspaceIcon.moon:
        final moon = Path()
          ..moveTo(19.8, 14.6)
          ..cubicTo(12.5, 18, 6, 11.5, 9.4, 4.2)
          ..cubicTo(-1, 8, 5, 25, 15, 20)
          ..quadraticBezierTo(18, 19, 19.8, 14.6)
          ..close();
        canvas.drawPath(moon, fill);
        canvas.drawPath(moon, line);
        segment(17.5, 3, 17.5, 7, detail);
        segment(15.5, 5, 19.5, 5, detail);
      case WorkspaceIcon.sun:
        canvas.drawCircle(const Offset(12, 12), 4.3, fill);
        canvas.drawCircle(const Offset(12, 12), 4.3, line);
        for (final pair in [
          [12, 2, 12, 4],
          [12, 20, 12, 22],
          [2, 12, 4, 12],
          [20, 12, 22, 12],
          [5, 5, 6.5, 6.5],
          [17.5, 17.5, 19, 19],
          [19, 5, 17.5, 6.5],
          [6.5, 17.5, 5, 19]
        ]) {
          segment(pair[0].toDouble(), pair[1].toDouble(), pair[2].toDouble(),
              pair[3].toDouble(), detail);
        }
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      icon != old.icon || color != old.color || accent != old.accent;
}
