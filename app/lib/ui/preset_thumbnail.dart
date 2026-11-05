import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../editor/style_document.dart';
import 'editor/prototype_controls.dart';

/// Shared thumbnail decoration; photo rendering and selection stay with callers.
class PresetThumbnail extends StatelessWidget {
  final StyleDocument style;
  final Widget child;
  const PresetThumbnail({super.key, required this.style, required this.child});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final shortest = math.min(box.maxWidth, box.maxHeight);
        final scale = shortest.isFinite ? (shortest / 95).clamp(.55, 1.0) : 1.0;
        return Stack(children: [
          Positioned.fill(child: child),
          Positioned(
              left: 5 * scale,
              bottom: 5 * scale,
              child: _CompositionBadge(style.suitability, scale))
        ]);
      });
}

class _CompositionBadge extends StatelessWidget {
  final String suitability;
  final double scale;
  const _CompositionBadge(this.suitability, this.scale);
  @override
  Widget build(BuildContext context) {
    final label = StyleDocument.suitabilityNames[suitability] ?? '横竖通用';
    final icons = switch (suitability) {
      'landscape' => ['landscapeMark'],
      'portrait' => ['portraitMark'],
      _ => ['landscapeMark', 'portraitMark']
    };
    return Tooltip(
        message: label,
        child: Semantics(
            label: label,
            image: true,
            child: Stack(
                key: ValueKey('composition-badge:$suitability'),
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                      child: ImageFiltered(
                          imageFilter:
                              ui.ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  color: const Color(0xff181817)
                                      .withValues(alpha: .55),
                                  borderRadius:
                                      BorderRadius.circular(5 * scale))))),
                  Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 5 * scale, vertical: 4 * scale),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        for (var i = 0; i < icons.length; i++) ...[
                          if (i > 0) SizedBox(width: 3 * scale),
                          PrototypeIcon(icons[i],
                              size: 18 * scale, color: const Color(0xfff2f0eb))
                        ]
                      ]))
                ])));
  }
}
