import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class MobileField extends StatefulWidget {
  final String label, value;
  final bool numeric, multiline;
  final String? Function(String) onCommit;

  const MobileField({
    super.key,
    required this.label,
    required this.value,
    required this.onCommit,
    this.numeric = false,
    this.multiline = false,
  });

  @override
  State<MobileField> createState() => _MobileFieldState();
}

class _MobileFieldState extends State<MobileField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_finishOnBlur);
  }

  @override
  void didUpdateWidget(covariant MobileField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focus.hasFocus) {
      _controller.text = widget.value;
      _error = null;
    }
  }

  void _finishOnBlur() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    if (_controller.text == widget.value) return;
    final error = widget.onCommit(_controller.text);
    if (mounted && error != _error) setState(() => _error = error);
  }

  @override
  void dispose() {
    _focus.removeListener(_finishOnBlur);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => mobileFieldLayout(
        context,
        widget.label,
        TextField(
          controller: _controller,
          focusNode: _focus,
          keyboardType: widget.numeric
              ? const TextInputType.numberWithOptions(
                  decimal: true, signed: true)
              : widget.multiline
                  ? TextInputType.multiline
                  : TextInputType.text,
          maxLines: widget.multiline ? 3 : 1,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _commit(),
          onTapOutside: (_) => _focus.unfocus(),
          decoration: mobileInputDecoration(context, error: _error),
        ),
      );
}

class MobileNumberField extends StatefulWidget {
  const MobileNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.defaultValue,
    this.scrubBase,
    this.integer = false,
    this.onPreview,
    this.onReset,
    this.onValidityChanged,
    this.min = double.negativeInfinity,
    this.max = double.infinity,
    this.step = 1,
    this.hint,
  });

  final String label;
  final double? value, defaultValue, scrubBase;
  final bool integer;
  final double min, max, step;
  final String? hint;
  final ValueChanged<double?> onChanged;
  final ValueChanged<double?>? onPreview;
  final VoidCallback? onReset;
  final ValueChanged<bool>? onValidityChanged;

  @override
  State<MobileNumberField> createState() => _MobileNumberFieldState();
}

class _MobileNumberFieldState extends State<MobileNumberField> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  bool _typing = false;
  Offset? _start;
  double? _scrub;
  bool _rejected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _input.dispose();
    super.dispose();
  }

  String _format(double? number) {
    if (number == null) return '';
    if (number == number.roundToDouble()) return number.toStringAsFixed(0);
    return number.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  void _beginTyping() {
    _input.text = _format(widget.value);
    _input.selection =
        TextSelection(baseOffset: 0, extentOffset: _input.text.length);
    setState(() => _typing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _typing) _focus.requestFocus();
    });
  }

  void _onFocus() {
    if (!_focus.hasFocus && _typing) _finishTyping();
  }

  void _finishTyping() {
    final text = _input.text.trim();
    final value = double.tryParse(text);
    final invalid = text.isNotEmpty &&
        (value == null ||
            (widget.integer && value != value.roundToDouble()) ||
            !value.isFinite ||
            value < widget.min ||
            value > widget.max);
    setState(() {
      _typing = false;
      _error = invalid ? '请输入范围内的有效数值' : null;
    });
    widget.onValidityChanged?.call(!invalid);
    if (!invalid && (value != null || widget.hint != null)) {
      widget.onChanged(value);
    }
  }

  void _drag(DragUpdateDetails event) {
    final delta = event.globalPosition - _start!;
    if (_scrub == null) {
      if (_rejected) return;
      if (delta.dy.abs() >= 10 && delta.dx.abs() < delta.dy.abs() * 1.5) {
        _rejected = true;
        return;
      }
      if (delta.dx.abs() < 12 || delta.dx.abs() < delta.dy.abs() * 1.5) return;
    }
    final base = widget.value ??
        widget.scrubBase ??
        widget.defaultValue ??
        (widget.min.isFinite ? widget.min : 0);
    final distance = delta.dx - (delta.dx >= 0 ? 12 : -12);
    final amount = delta.dx.abs() < 12 ? 0 : (distance / 5).round();
    final next =
        (base + amount * widget.step).clamp(widget.min, widget.max).toDouble();
    if (_scrub == next) return;
    setState(() {
      _scrub = next;
      _error = null;
    });
    widget.onValidityChanged?.call(true);
    widget.onPreview?.call(next);
  }

  void _endDrag({required bool commit}) {
    final value = _scrub;
    if (value == null) return;
    setState(() => _scrub = null);
    if (commit) {
      widget.onChanged(value);
    } else {
      widget.onPreview?.call(null);
    }
  }

  @override
  Widget build(BuildContext context) => mobileFieldLayout(
        context,
        widget.label,
        _typing
            ? TextField(
                controller: _input,
                focusNode: _focus,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (_typing) _finishTyping();
                },
                onTapOutside: (_) => _focus.unfocus(),
                decoration: mobileInputDecoration(context, hint: widget.hint),
              )
            : Semantics(
                label: widget.label,
                value: _format(_scrub ?? widget.value),
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  dragStartBehavior: DragStartBehavior.down,
                  onTap: _beginTyping,
                  onDoubleTap: () {
                    setState(() => _error = null);
                    widget.onValidityChanged?.call(true);
                    if (widget.onReset case final reset?) {
                      reset();
                    } else {
                      widget.onChanged(widget.defaultValue);
                    }
                  },
                  onHorizontalDragStart: (event) {
                    _start = event.globalPosition;
                    _rejected = false;
                  },
                  onHorizontalDragUpdate: _drag,
                  onHorizontalDragEnd: (_) => _endDrag(commit: true),
                  onHorizontalDragCancel: () => _endDrag(commit: false),
                  child: InputDecorator(
                    decoration: mobileInputDecoration(context,
                        hint: widget.hint, error: _error),
                    isEmpty: _scrub == null && widget.value == null,
                    child: Text(_format(_scrub ?? widget.value)),
                  ),
                ),
              ),
      );
}

InputDecoration mobileInputDecoration(BuildContext context,
        {String? hint, String? error}) =>
    InputDecoration(
      hintText: hint,
      errorText: error,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );

Widget mobileFieldLayout(BuildContext context, String label, Widget field) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 5),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (_) {},
            child: field,
          ),
        ],
      ),
    );
