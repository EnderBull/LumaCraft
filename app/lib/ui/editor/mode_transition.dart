import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

const workspaceCanvasTag = 'workspace-photo-canvas';

class EditorBrowseState {
  final List<File> files;
  final int current, anchor;
  final Set<String> selected;
  final double scrollOffset;
  final String? directory;
  final List<String> directories;
  final ui.Image? photo;
  final bool scanning;
  const EditorBrowseState(
      {required this.files,
      required this.current,
      required this.anchor,
      required this.selected,
      required this.scrollOffset,
      required this.directory,
      this.directories = const [],
      required this.photo,
      required this.scanning});
}

/// Chrome is never transformed. Only the sidebars consume this route's clock.
class WorkspaceModeRoute extends PageRouteBuilder<void> {
  WorkspaceModeRoute(
      {required WidgetBuilder builder, required bool reduceMotion})
      : super(
            transitionDuration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 260),
            reverseTransitionDuration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 260),
            allowSnapshotting: false,
            pageBuilder: (context, animation, secondaryAnimation) =>
                builder(context),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) => child);
  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;
}

class ModeSidebar extends StatelessWidget {
  final Widget child;
  final bool right;
  const ModeSidebar({super.key, required this.child, this.right = false});
  @override
  Widget build(BuildContext context) {
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || ModalRoute.of(context) is! WorkspaceModeRoute)
      return child;
    return ClipRect(
        child: AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, child) => Transform.translate(
                offset: Offset(
                    (right ? 16 : -16) *
                        (1 - Curves.easeInOutCubic.transform(animation.value)),
                    0),
                child: Opacity(
                    opacity: Curves.easeInOutCubic.transform(animation.value),
                    child: child))));
  }
}

class WorkspaceCanvas extends StatelessWidget {
  final Widget child;
  const WorkspaceCanvas({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Hero(
      tag: workspaceCanvasTag,
      createRectTween: (begin, end) => _CanvasRectTween(begin: begin, end: end),
      flightShuttleBuilder: (context, animation, direction, from, to) =>
          (to.widget as Hero).child,
      child: FittedBox(child: child));
}

class _CanvasRectTween extends RectTween {
  _CanvasRectTween({super.begin, super.end});
  @override
  Rect? lerp(double t) =>
      Rect.lerp(begin, end, Curves.easeInOutCubic.transform(t));
}
