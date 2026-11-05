import 'dart:math' as math;
import 'dart:ui';
import 'shape_style.dart';

Color _tint(int color, double opacity) {
  final c = Color(color);
  return c.withValues(alpha: (c.a * opacity / 100).clamp(0.0, 1.0));
}

/// 绘制形状；预览、缩略图、画布与导出共用。[nodeOpacity] 为组件整体不透明度（0～100）。
void paintShape(Canvas canvas, Offset center, ShapeStyle s, double nodeOpacity) {
  final path = shapePath(s), factor = nodeOpacity / 100;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(s.rotation * math.pi / 180);
  if (s.fill) {
    if (s.kind == 'triangle' && s.split) {
      // 先在独立图层内画不透明的两色，再整体套用不透明度：
      // 两色交界不会出现细缝，半透明时也不会叠加变浓。
      final alpha = (s.fillOpacity * factor / 100).clamp(0.0, 1.0);
      canvas.saveLayer(path.getBounds().inflate(2),
          Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
      canvas.drawPath(
          path,
          Paint()
            ..isAntiAlias = true
            ..color = Color(s.fillColor | 0xff000000));
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, -1e5, 1e5, 1e5));
      canvas.drawPath(
          path,
          Paint()
            ..isAntiAlias = true
            ..color = Color(s.fillColor2 | 0xff000000));
      canvas.restore();
      canvas.restore();
    } else {
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.fill
            ..isAntiAlias = true
            ..color = _tint(s.fillColor, s.fillOpacity * factor));
    }
  }
  if (s.stroke && s.kind != 'line') {
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true
          ..strokeWidth = s.strokeWidth
          ..strokeJoin = StrokeJoin.miter
          ..color = _tint(s.strokeColor, s.strokeOpacity * factor));
  }
  canvas.restore();
}
