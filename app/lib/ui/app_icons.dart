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
  sun,
  photoAdd,
  resumeEditing,
  presetLibrary,
  presetImport,
  textImport,
  qrImage,
  qrCamera,
  presetCopy,
  presetMove,
  presetDelete,
  presetFavorite,
  settings
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
      case WorkspaceIcon.photoAdd:
        final frame = Path()
          ..moveTo(14, 5)
          ..lineTo(5.5, 5)
          ..quadraticBezierTo(3, 5, 3, 7.5)
          ..lineTo(3, 17.5)
          ..quadraticBezierTo(3, 20, 5.5, 20)
          ..lineTo(16.5, 20)
          ..quadraticBezierTo(19, 20, 19, 17.5)
          ..lineTo(19, 11);
        canvas.drawPath(frame, line);
        segment(4, 17, 8, 13);
        segment(8, 13, 11, 16);
        segment(11, 16, 15, 12);
        canvas.drawCircle(const Offset(8, 9), 1, detail);
        segment(17, 5, 23, 5, detail);
        segment(20, 2, 20, 8, detail);
      case WorkspaceIcon.resumeEditing:
        rect(4, 4, 15, 16, 2.5, surface: false);
        segment(7, 15, 10, 12);
        segment(10, 12, 13, 15);
        segment(13, 15, 16, 12);
        segment(14, 19, 22, 11, detail);
        segment(14, 19, 14, 21, detail);
        segment(14, 21, 16, 21, detail);
      case WorkspaceIcon.presetLibrary:
        final top = Path()
          ..moveTo(12, 3)
          ..lineTo(21, 8)
          ..lineTo(12, 13)
          ..lineTo(3, 8)
          ..close();
        canvas.drawPath(top, line);
        segment(3, 12, 12, 17);
        segment(12, 17, 21, 12);
        segment(3, 16, 12, 21, detail);
        segment(12, 21, 21, 16, detail);
      case WorkspaceIcon.presetImport:
        final page = Path()
          ..moveTo(5, 20)
          ..lineTo(5, 4)
          ..quadraticBezierTo(5, 3, 6, 3)
          ..lineTo(13, 3)
          ..lineTo(19, 9)
          ..lineTo(19, 12)
          ..moveTo(13, 3)
          ..lineTo(13, 9)
          ..lineTo(19, 9)
          ..moveTo(5, 20)
          ..lineTo(11, 20);
        canvas.drawPath(page, line);
        segment(16.5, 13, 16.5, 21, detail);
        segment(13.5, 18, 16.5, 21, detail);
        segment(16.5, 21, 19.5, 18, detail);
      case WorkspaceIcon.textImport:
        rect(5, 5, 14, 16, 2);
        rect(9, 3, 6, 4, 1.2);
        segment(8, 11, 16, 11);
        segment(8, 14.5, 16, 14.5);
        segment(8, 18, 13, 18, detail);
      case WorkspaceIcon.qrImage:
        rect(3, 3, 18, 18, 3);
        rect(6, 6, 4, 4, .7, surface: false);
        rect(14, 6, 4, 4, .7, surface: false);
        rect(6, 14, 4, 4, .7, surface: false);
        segment(14, 14, 14, 18, detail);
        segment(17, 17, 18, 17, detail);
      case WorkspaceIcon.qrCamera:
        final corners = Path()
          ..moveTo(3, 8)
          ..lineTo(3, 5)
          ..quadraticBezierTo(3, 3, 5, 3)
          ..lineTo(8, 3)
          ..moveTo(16, 3)
          ..lineTo(19, 3)
          ..quadraticBezierTo(21, 3, 21, 5)
          ..lineTo(21, 8)
          ..moveTo(21, 16)
          ..lineTo(21, 19)
          ..quadraticBezierTo(21, 21, 19, 21)
          ..lineTo(16, 21)
          ..moveTo(8, 21)
          ..lineTo(5, 21)
          ..quadraticBezierTo(3, 21, 3, 19)
          ..lineTo(3, 16);
        canvas.drawPath(corners, line);
        segment(6, 12, 18, 12, detail);
      case WorkspaceIcon.presetCopy:
        rect(8, 8, 12, 13, 2);
        canvas.drawPath(
            Path()
              ..moveTo(4, 16)
              ..lineTo(4, 5)
              ..quadraticBezierTo(4, 3, 6, 3)
              ..lineTo(15, 3),
            line);
        segment(11, 16, 16, 16, detail);
      case WorkspaceIcon.presetMove:
        rect(3, 6, 18, 13, 2.5);
        segment(8, 13, 16, 13, detail);
        segment(13, 10, 16, 13, detail);
        segment(16, 13, 13, 16, detail);
      case WorkspaceIcon.presetDelete:
        rect(6, 7, 12, 14, 2);
        segment(4, 7, 20, 7);
        segment(9, 4, 15, 4);
        segment(10, 11, 10, 17, detail);
        segment(14, 11, 14, 17, detail);
      case WorkspaceIcon.presetFavorite:
        canvas.drawPath(
            Path()
              ..moveTo(12, 3)
              ..lineTo(14.8, 8.7)
              ..lineTo(21.2, 9.6)
              ..lineTo(16.6, 14.1)
              ..lineTo(17.7, 20.5)
              ..lineTo(12, 17.5)
              ..lineTo(6.3, 20.5)
              ..lineTo(7.4, 14.1)
              ..lineTo(2.8, 9.6)
              ..lineTo(9.2, 8.7)
              ..close(),
            line);
        segment(10, 12, 14, 12, detail);
      case WorkspaceIcon.settings:
        // Drawn by `ui-settings.svg` instead; this case only keeps the switch
        // exhaustive for callers that still reference the enum value.
        break;
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      icon != old.icon || color != old.color || accent != old.accent;
}
