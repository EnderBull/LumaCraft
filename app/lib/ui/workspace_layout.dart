import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../workspace_settings.dart';

class WorkspaceLayout extends StatelessWidget {
  final WorkspaceSettings settings;
  final Widget library, stage, inspector, filmstrip;
  const WorkspaceLayout(
      {super.key,
      required this.settings,
      required this.library,
      required this.stage,
      required this.inspector,
      required this.filmstrip});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: settings,
      builder: (context, _) => LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth, height = constraints.maxHeight;
            final left = settings.left
                .clamp(160.0, math.min(320.0, width - 690))
                .toDouble();
            final right = settings.right
                .clamp(260.0, math.min(420.0, width - left - 400))
                .toDouble();
            final bottom = settings.bottom
                .clamp(132.0, math.min(300.0, height - 240))
                .toDouble();
            final center = width - left - right;
            final duration =
                settings.resizing || MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 360);
            Widget panel(String key, double x, double y, double w, double h,
                    Widget child, {bool shadow = true}) =>
                AnimatedPositioned(
                    key: ValueKey(key),
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    left: x,
                    top: y,
                    width: w,
                    height: h,
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: shadow
                                ? Theme.of(context).colorScheme.surface
                                : null,
                            boxShadow: shadow
                                ? [
                                    BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: .22),
                                        blurRadius: 18,
                                        spreadRadius: -5)
                                  ]
                                : null),
                        child: ClipRect(child: RepaintBoundary(child: child))));
            Widget handle(String key, double x, double y, double w, double h,
                    bool vertical) =>
                Positioned(
                    left: x,
                    top: y,
                    width: w,
                    height: h,
                    child: Semantics(
                        label: '拖动调整$key',
                        child: MouseRegion(
                            cursor: vertical
                                ? SystemMouseCursors.resizeColumn
                                : SystemMouseCursors.resizeRow,
                            child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanStart: (_) {
                                  settings.left = left;
                                  settings.right = right;
                                  settings.bottom = bottom;
                                  settings.resizing = true;
                                  settings.changed();
                                },
                                onPanUpdate: (event) {
                                  if (key == '左侧栏')
                                    settings.left =
                                        (settings.left + event.delta.dx)
                                            .clamp(160, width - right - 400);
                                  if (key == '右侧栏')
                                    settings.right =
                                        (settings.right - event.delta.dx)
                                            .clamp(260, width - left - 400);
                                  if (key == '底栏')
                                    settings.bottom =
                                        (settings.bottom - event.delta.dy)
                                            .clamp(132, height - 240);
                                  settings.changed();
                                },
                                onPanEnd: (_) {
                                  settings.resizing = false;
                                  settings.changed();
                                },
                                onPanCancel: () {
                                  settings.resizing = false;
                                  settings.changed();
                                },
                                child: const SizedBox.expand()))));
            Widget shade(bool bottom) => IgnorePointer(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: bottom
                                ? [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: .13)
                                  ]
                                : [
                                    Colors.black.withValues(alpha: .25),
                                    Colors.transparent
                                  ]))));
            final sideHeight = settings.sideFirst ? height : height - bottom;
            return Stack(children: [
              panel('stage', left, 0, center, height - bottom, stage,
                  shadow: false),
              // The panel that fills the outer edges is painted last. Keys keep
              // panel state intact when this order changes during a layout switch.
              if (settings.sideFirst)
                panel('filmstrip', left, height - bottom, center, bottom,
                    filmstrip),
              panel('library', 0, 0, left, sideHeight, library),
              panel(
                  'inspector', width - right, 0, right, sideHeight, inspector),
              if (!settings.sideFirst)
                panel(
                    'filmstrip', 0, height - bottom, width, bottom, filmstrip),
              // Shadow overlays are above every panel, rather than being covered
              // by later opaque siblings. They never intercept mouse input.
              Positioned(
                  top: 0, left: 0, right: 0, height: 22, child: shade(false)),
              AnimatedPositioned(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  left: settings.sideFirst ? left : 0,
                  top: height - bottom - 17,
                  width: settings.sideFirst ? center : width,
                  height: 17,
                  child: shade(true)),
              // Explicit inner-edge shadows stay above the filmstrip's opaque
              // repaint layer, including when the sidebars fill the full height.
              for (final isLeft in [true, false])
                AnimatedPositioned(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    left: isLeft ? left : width - right - 18,
                    top: 0,
                    width: 18,
                    height: sideHeight,
                    child: IgnorePointer(
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    begin: isLeft
                                        ? Alignment.centerLeft
                                        : Alignment.centerRight,
                                    end: isLeft
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    colors: [
                          Colors.black.withValues(alpha: .22),
                          Colors.transparent
                        ]))))),
              handle('左侧栏', left - 3, 0, 6, sideHeight, true),
              handle('右侧栏', width - right - 3, 0, 6, sideHeight, true),
              handle('底栏', settings.sideFirst ? left : 0, height - bottom - 3,
                  settings.sideFirst ? center : width, 6, false),
            ]);
          }));
}
