import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Wheel input animates toward an accumulated target. Dragging and native
/// trackpad gestures continue to use the normal ScrollPosition behavior.
class SmoothScrollController extends ScrollController {
  SmoothScrollController({super.initialScrollOffset});
  bool animateWheel = true;

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics,
          ScrollContext context, ScrollPosition? oldPosition) =>
      _WheelPosition(
          physics: physics,
          context: context,
          oldPosition: oldPosition,
          controller: this);
}

class _WheelPosition extends ScrollPositionWithSingleContext {
  final SmoothScrollController controller;
  double? _target;
  _WheelPosition(
      {required super.physics,
      required super.context,
      super.oldPosition,
      required this.controller});

  @override
  void beginActivity(ScrollActivity? newActivity) {
    if (newActivity is! DrivenScrollActivity) _target = null;
    super.beginActivity(newActivity);
  }

  @override
  void pointerScroll(double delta) {
    if (!controller.animateWheel || delta == 0) {
      _target = null;
      super.pointerScroll(delta);
      return;
    }
    final previous = _target;
    final base = previous != null && (previous - pixels) * delta >= 0
        ? previous
        : pixels;
    final target = (base + delta).clamp(minScrollExtent, maxScrollExtent);
    if (target == pixels) {
      goIdle();
      return;
    }
    _target = target;
    unawaited(animateTo(target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic));
  }
}

class SmoothScroll extends StatelessWidget {
  final SmoothScrollController controller;
  final Axis axis;
  final Widget child;
  const SmoothScroll(
      {super.key,
      required this.controller,
      this.axis = Axis.vertical,
      required this.child});

  @override
  Widget build(BuildContext context) => Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        // The resolver runs after hit testing, so native Scrollable callbacks
        // also see this event's input kind before calling pointerScroll.
        controller.animateWheel = event.kind == PointerDeviceKind.mouse &&
            !MediaQuery.disableAnimationsOf(context);
        final delta = axis == Axis.horizontal
            ? (event.scrollDelta.dx != 0
                ? event.scrollDelta.dx
                : event.scrollDelta.dy)
            : event.scrollDelta.dy;
        if (delta == 0 || !controller.hasClients) return;
        GestureBinding.instance.pointerSignalResolver.register(event, (signal) {
          if (controller.hasClients) {
            controller.position.pointerScroll(delta);
          }
        });
      },
      child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: child));
}
