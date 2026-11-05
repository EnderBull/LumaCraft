import 'package:flutter/material.dart';
import 'number_drag_input.dart';
import 'prototype_controls.dart';

String colorHex(Color color) =>
    '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class ColorSwatchButton extends StatelessWidget {
  final Color color;
  final bool mixed;
  final String label;
  final VoidCallback onPressed;
  const ColorSwatchButton(
      {super.key,
      required this.color,
      required this.label,
      required this.onPressed,
      this.mixed = false});
  @override
  Widget build(BuildContext context) => Tooltip(
      message: '打开 HSB 取色板',
      child: Semantics(
          label: '选择$label',
          button: true,
          child: SizedBox.square(
              dimension: 40,
              child: TextButton(
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6))),
                  onPressed: onPressed,
                  child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                          color: mixed ? const Color(0xff9b978e) : color,
                          gradient: mixed
                              ? const LinearGradient(colors: [
                                  Color(0xffdedbd3),
                                  Color(0xff79766f)
                                ])
                              : null,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: .45))))))));
}

/// HSB is HSV: hue in degrees, saturation and brightness in percent.
class HsbColorPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onChanged;
  const HsbColorPicker(
      {super.key, required this.initialColor, required this.onChanged});
  @override
  State<HsbColorPicker> createState() => _HsbColorPickerState();
}

class _HsbColorPickerState extends State<HsbColorPicker> {
  late HSVColor hsv = HSVColor.fromColor(widget.initialColor);
  late final channels = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController()
  ];
  final channelFocus = [FocusNode(), FocusNode(), FocusNode()];
  late final hex = TextEditingController(text: colorHex(widget.initialColor));
  final hexFocus = FocusNode();
  bool invalidHex = false;
  bool closing = false;
  Color get color => hsv.toColor();
  List<double> get values => [hsv.hue, hsv.saturation * 100, hsv.value * 100];
  @override
  void initState() {
    super.initState();
    sync();
    hexFocus.addListener(() {
      if (!hexFocus.hasFocus && !invalidHex) hex.text = colorHex(color);
    });
    for (var i = 0; i < 3; i++) {
      channelFocus[i].addListener(() {
        if (!channelFocus[i].hasFocus) commitChannel(i);
      });
    }
  }

  void sync() {
    for (var i = 0; i < 3; i++) {
      if (!channelFocus[i].hasFocus)
        channels[i].text = numberInputText(values[i]);
    }
    if (!hexFocus.hasFocus) hex.text = colorHex(color);
  }

  void update(HSVColor next, {bool fromHex = false}) {
    if (!mounted || closing) return;
    setState(() {
      hsv = next;
      invalidHex = false;
      if (!fromHex) hex.text = colorHex(color);
      sync();
    });
    widget.onChanged(color);
  }

  void channelChanged(int i, String text) {
    final n = double.tryParse(text);
    if (n == null || !n.isFinite) return;
    final v = n.clamp(0.0, i == 0 ? 360.0 : 100.0);
    update(i == 0
        ? hsv.withHue(v)
        : i == 1
            ? hsv.withSaturation(v / 100)
            : hsv.withValue(v / 100));
  }

  void commitChannel(int i) {
    if (closing) return;
    final value = double.tryParse(channels[i].text);
    if (value != null && value.isFinite) channelChanged(i, channels[i].text);
    channels[i].text = numberInputText(values[i]);
  }

  void hexChanged(String text) {
    final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(text.trim());
    if (match == null) {
      setState(() => invalidHex = true);
      return;
    }
    var next = HSVColor.fromColor(
        Color(0xff000000 | int.parse(match.group(1)!, radix: 16)));
    if (next.saturation == 0 || next.value == 0) next = next.withHue(hsv.hue);
    update(next, fromHex: true);
  }

  @override
  void dispose() {
    for (final controller in channels) {
      controller.dispose();
    }
    for (final focus in channelFocus) {
      focus.dispose();
    }
    hex.dispose();
    hexFocus.dispose();
    super.dispose();
  }

  InputDecoration decoration({String? suffix}) => InputDecoration(
      isDense: true,
      suffixText: suffix,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none));
  Widget channel(int i, String label) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label, style: EditorTypography.label(context)),
        const SizedBox(height: 7),
        SizedBox(
            height: 40,
            child: NumberDragInput(
                controller: channels[i],
                focusNode: channelFocus[i],
                spec: NumberDragSpec(
                    min: 0, max: i == 0 ? 360 : 100, fallback: values[i]),
                decoration: decoration(suffix: i == 0 ? '°' : '%'),
                style: EditorTypography.value(context),
                onChanged: (text) => channelChanged(i, text),
                onDone: () => commitChannel(i),
                onCancel: () => commitChannel(i)))
      ]);
  Widget sample(String label, Color value) => Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label, style: EditorTypography.label(context)),
        const SizedBox(height: 6),
        Container(
            height: 30,
            decoration: BoxDecoration(
                color: value,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Theme.of(context).dividerColor)))
      ]));
  @override
  Widget build(BuildContext context) => PopScope<bool>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) closing = true;
      },
      child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: 360,
                  maxHeight:
                      (MediaQuery.sizeOf(context).height - 64).clamp(260, 700)),
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('选择颜色 · HSB',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        Flexible(
                            child: SingleChildScrollView(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                              AspectRatio(
                                  aspectRatio: 1.5,
                                  child: LayoutBuilder(builder: (context, box) {
                                    void pick(Offset position) => update(hsv
                                        .withSaturation(
                                            (position.dx / box.maxWidth)
                                                .clamp(0, 1))
                                        .withValue(
                                            (1 - position.dy / box.maxHeight)
                                                .clamp(0, 1)));
                                    return Semantics(
                                        label: '饱和度与亮度',
                                        child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            child: GestureDetector(
                                                key:
                                                    const ValueKey('hsb-plane'),
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTapDown: (e) =>
                                                    pick(e.localPosition),
                                                onPanStart: (e) =>
                                                    pick(e.localPosition),
                                                onPanUpdate: (e) =>
                                                    pick(e.localPosition),
                                                child: CustomPaint(
                                                    painter:
                                                        _HsbPlanePainter(hsv),
                                                    size: Size.infinite))));
                                  })),
                              const SizedBox(height: 12),
                              Stack(alignment: Alignment.center, children: [
                                Container(
                                    height: 12,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 7),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        gradient: const LinearGradient(colors: [
                                          Color(0xffff0000),
                                          Color(0xffffff00),
                                          Color(0xff00ff00),
                                          Color(0xff00ffff),
                                          Color(0xff0000ff),
                                          Color(0xffff00ff),
                                          Color(0xffff0000)
                                        ]))),
                                SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                        trackHeight: 12,
                                        activeTrackColor: Colors.transparent,
                                        inactiveTrackColor: Colors.transparent,
                                        thumbColor: Colors.white,
                                        overlayColor:
                                            Colors.white.withValues(alpha: .12),
                                        thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 7)),
                                    child: Slider(
                                        key: const ValueKey('hsb-hue'),
                                        min: 0,
                                        max: 360,
                                        value: hsv.hue,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7),
                                        semanticFormatterCallback: (v) =>
                                            '色相 ${v.round()}度',
                                        onChanged: (v) =>
                                            update(hsv.withHue(v))))
                              ]),
                              const SizedBox(height: 14),
                              Row(children: [
                                Expanded(child: channel(0, 'H 色相')),
                                const SizedBox(width: 8),
                                Expanded(child: channel(1, 'S 饱和度')),
                                const SizedBox(width: 8),
                                Expanded(child: channel(2, 'B 亮度'))
                              ]),
                              const SizedBox(height: 14),
                              Text('HEX',
                                  style: EditorTypography.label(context)),
                              const SizedBox(height: 7),
                              SizedBox(
                                  height: 40,
                                  child: TextField(
                                      key: const ValueKey('hsb-hex'),
                                      controller: hex,
                                      focusNode: hexFocus,
                                      decoration: decoration(),
                                      style: EditorTypography.value(context),
                                      onChanged: hexChanged)),
                              if (invalidHex)
                                Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text('请输入6位HEX颜色',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error))),
                              const SizedBox(height: 14),
                              Row(children: [
                                sample('原颜色', widget.initialColor),
                                const SizedBox(width: 12),
                                sample('当前颜色', color)
                              ])
                            ]))),
                        const SizedBox(height: 16),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                  onPressed: () {
                                    closing = true;
                                    Navigator.pop(context, false);
                                  },
                                  child: const Text('取消')),
                              const SizedBox(width: 8),
                              FilledButton(
                                  onPressed: invalidHex
                                      ? null
                                      : () {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                          closing = true;
                                          Navigator.pop(context, true);
                                        },
                                  child: const Text('确定'))
                            ])
                      ])))));
}

class _HsbPlanePainter extends CustomPainter {
  final HSVColor hsv;
  _HsbPlanePainter(this.hsv);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(colors: [
            Colors.white,
            HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor()
          ]).createShader(rect));
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black]).createShader(rect));
    final point =
        Offset(hsv.saturation * size.width, (1 - hsv.value) * size.height);
    canvas.drawCircle(
        point,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.black);
    canvas.drawCircle(
        point,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _HsbPlanePainter oldDelegate) =>
      oldDelegate.hsv != hsv;
}
