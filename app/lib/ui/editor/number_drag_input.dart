import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NumberDragSpec {
  final double min, max, step, fallback;
  final double? reset;
  const NumberDragSpec(
      {required this.min,
      required this.max,
      required this.fallback,
      this.step = 1,
      this.reset});
}

String numberInputText(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

/// A short mouse movement claims the gesture before text selection or scrolling.
/// Taps still reach the normal editable field, including keyboard/Tab focus.
class NumberDragInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final NumberDragSpec spec;
  final ValueChanged<String> onChanged;
  final VoidCallback onDone, onCancel;
  final String? Function()? onReset;
  final InputDecoration? decoration;
  final TextStyle? style;
  const NumberDragInput(
      {super.key,
      required this.controller,
      required this.focusNode,
      required this.spec,
      required this.onChanged,
      required this.onDone,
      required this.onCancel,
      this.onReset,
      this.decoration,
      this.style});
  @override
  State<NumberDragInput> createState() => _NumberDragInputState();
}

class _NumberDragInputState extends State<NumberDragInput> {
  bool dragging = false;
  double value = 0;
  String before = '';
  void begin() {
    widget.onDone();
    before = widget.controller.text;
    value = (double.tryParse(before) ?? widget.spec.fallback)
        .clamp(widget.spec.min, widget.spec.max);
    widget.focusNode.requestFocus();
    setState(() => dragging = true);
  }

  void change(double pixels) {
    if (!dragging) return;
    final keys = HardwareKeyboard.instance;
    final multiplier =
        (keys.isShiftPressed ? 10.0 : 1.0) * (keys.isAltPressed ? .1 : 1.0);
    value = (value + pixels * widget.spec.step * multiplier / 4)
        .clamp(widget.spec.min, widget.spec.max);
    final text = numberInputText(value);
    widget.controller.value = TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
    widget.onChanged(text);
  }

  void finish({bool cancel = false}) {
    if (!dragging) return;
    setState(() => dragging = false);
    if (cancel) {
      widget.controller.text = before;
      widget.onCancel();
    } else {
      widget.onDone();
    }
    widget.focusNode.unfocus();
  }

  void restore() {
    final custom = widget.onReset;
    if (custom != null) {
      final text = custom();
      if (text != null) {
        widget.controller.value = TextEditingValue(
            text: text,
            selection:
                TextSelection(baseOffset: 0, extentOffset: text.length));
      }
      return;
    }
    final reset = widget.spec.reset;
    if (reset == null) return;
    final text = numberInputText(reset);
    widget.controller.value = TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: 0, extentOffset: text.length));
    widget.onChanged(text);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget.focusNode.requestFocus();
        widget.controller.selection = TextSelection(
            baseOffset: 0, extentOffset: widget.controller.text.length);
      },
      onDoubleTap: widget.onReset == null && widget.spec.reset == null
          ? null
          : restore,
      child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            _NumberScrubRecognizer:
                GestureRecognizerFactoryWithHandlers<_NumberScrubRecognizer>(
                    () => _NumberScrubRecognizer(), (recognizer) {
              recognizer.onStart = begin;
              recognizer.onDelta = change;
              recognizer.onEnd = () => finish();
              recognizer.onCancel = () => finish(cancel: true);
            })
          },
          child: IgnorePointer(
              child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  readOnly: dragging,
                  enableInteractiveSelection: !dragging,
                  mouseCursor:
                      dragging ? SystemMouseCursors.resizeLeftRight : null,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: widget.decoration,
                  style: widget.style,
                  onChanged: widget.onChanged,
                  onSubmitted: (_) => widget.onDone(),
                  onTapOutside: (_) => widget.focusNode.unfocus()))));
}

class _NumberScrubRecognizer extends OneSequenceGestureRecognizer {
  VoidCallback? onStart, onEnd, onCancel;
  ValueChanged<double>? onDelta;
  int? pointer;
  Offset origin = Offset.zero, previous = Offset.zero;
  bool accepted = false, horizontal = true;
  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      pointer == null &&
      event.kind == PointerDeviceKind.mouse &&
      event.buttons == kPrimaryMouseButton &&
      super.isPointerAllowed(event);
  @override
  void addAllowedPointer(PointerDownEvent event) {
    pointer = event.pointer;
    origin = previous = event.position;
    accepted = false;
    startTrackingPointer(event.pointer, event.transform);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != pointer) return;
    if (event is PointerMoveEvent) {
      final total = event.position - origin;
      if (!accepted && total.distance >= 4) {
        horizontal = total.dx.abs() >= total.dy.abs();
        resolve(GestureDisposition.accepted);
      }
      if (accepted) {
        final delta = event.position - previous;
        onDelta?.call(horizontal ? delta.dx : -delta.dy);
        previous = event.position;
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (accepted) {
        if (event is PointerCancelEvent)
          onCancel?.call();
        else
          onEnd?.call();
      } else {
        resolve(GestureDisposition.rejected);
      }
      stopTrackingPointer(event.pointer);
      pointer = null;
    }
  }

  @override
  void acceptGesture(int id) {
    if (id == pointer && !accepted) {
      accepted = true;
      onStart?.call();
    }
  }

  @override
  void rejectGesture(int id) {
    if (id == pointer) {
      if (accepted) onCancel?.call();
      stopTrackingPointer(id);
      pointer = null;
      accepted = false;
    }
  }

  @override
  void didStopTrackingLastPointer(int id) {}
  @override
  String get debugDescription => 'number scrub';
}
