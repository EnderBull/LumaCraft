import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../window_controls.dart';

class BrowseViewport extends StatefulWidget {
  final Widget child;
  const BrowseViewport({super.key, required this.child});
  @override
  BrowseViewportState createState() => BrowseViewportState();
}

class BrowseViewportState extends State<BrowseViewport> {
  final focus = FocusNode();
  double zoom = 1;
  Offset pan = Offset.zero;
  bool space = false, dragging = false;
  void reset() => setState(() {
        zoom = 1;
        pan = Offset.zero;
      });
  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
      focusNode: focus,
      onKeyEvent: (_, e) {
        if (e.logicalKey != LogicalKeyboardKey.space)
          return KeyEventResult.ignored;
        setState(() => space = e is! KeyUpEvent);
        return KeyEventResult.handled;
      },
      onFocusChange: (value) {
        if (!value && mounted) setState(() => space = false);
      },
      child: ClipRect(
          child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => focus.requestFocus(),
              onPointerSignal: (event) {
                if (event is! PointerScrollEvent) return;
                GestureBinding.instance.pointerSignalResolver.register(event,
                    (_) async {
                  if (!await DesktopWindow.wheelAltPressed() || !mounted)
                    return;
                  final next = (zoom * math.exp(-event.scrollDelta.dy * .0015))
                          .clamp(.1, 8.0),
                      factor = next / zoom;
                  setState(() {
                    pan = (pan - event.localPosition) * factor +
                        event.localPosition;
                    zoom = next;
                  });
                });
              },
              child: MouseRegion(
                  cursor: dragging
                      ? SystemMouseCursors.grabbing
                      : space
                          ? SystemMouseCursors.grab
                          : SystemMouseCursors.basic,
                  child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) {
                        dragging = space ||
                            HardwareKeyboard.instance.logicalKeysPressed
                                .contains(LogicalKeyboardKey.space);
                      },
                      onPanUpdate: (d) {
                        if (dragging) setState(() => pan += d.delta);
                      },
                      onPanEnd: (_) => setState(() => dragging = false),
                      onPanCancel: () => setState(() => dragging = false),
                      child: Transform(
                          transform: Matrix4.identity()
                            ..translateByDouble(pan.dx, pan.dy, 0, 1)
                            ..scaleByDouble(zoom, zoom, zoom, 1),
                          child: widget.child))))));
}
