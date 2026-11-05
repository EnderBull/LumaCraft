part of 'editor_page.dart';

extension ShapePanel on _PresetEditorState {
  Widget _shapeToggle(String title, bool value, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(child: Text(title, style: EditorTypography.label(context))),
        Semantics(
            label: title,
            toggled: value,
            child: SizedBox(
                width: 42,
                height: 32,
                child: TextButton(
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6))),
                    onPressed: onTap,
                    child: Container(
                        width: 30,
                        height: 16,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            color: value
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8)),
                        child: Align(
                            alignment: value
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                    color: value
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : EditorTypography.muted(context),
                                    shape: BoxShape.circle)))))))
      ]));

  Widget _shapeOpacity(String title, double value, ValueChanged<double> change) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(title, style: EditorTypography.label(context)),
          const Spacer(),
          Text('${value.round()}%', style: const TextStyle(fontSize: 12))
        ]),
        SliderTheme(
            data: SliderTheme.of(context).copyWith(
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12)),
            child: Slider(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                value: value.clamp(0, 100),
                min: 0,
                max: 100,
                semanticFormatterCallback: (v) => '$title ${v.round()}%',
                onChangeStart: (_) => c.begin(),
                onChanged: (v) {
                  change(v);
                  c.update();
                },
                onChangeEnd: (_) => c.end()))
      ]);

  Widget _shapeSelect(String title, String value, Map<String, String> options,
          ValueChanged<String> change) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(title, style: EditorTypography.label(context))),
                PrototypeSelect(
                    value: value,
                    options: options,
                    onChanged: (v) => c.edit(() => change(v)))
              ]));

  Widget shapeProperties(StyleNode node) {
    final s = node.shape, line = s.kind == 'line', circle = s.kind == 'circle';
    final hasFillChoice = !line;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      section('形状外观', [
        Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('形状', style: EditorTypography.label(context))),
                  ShapePicker(
                      value: s.kind,
                      onChanged: (v) => c.edit(() => s.applyKind(v)))
                ])),
        pair(
            numeric(line ? '长度 px' : '宽度 px', s.width, (v) => s.width = v,
                min: shapeLimits['width']!.$1,
                max: shapeLimits['width']!.$2,
                step: .1),
            numeric(line ? '粗细 px' : '高度 px', s.height, (v) => s.height = v,
                min: shapeLimits['height']!.$1,
                max: shapeLimits['height']!.$2,
                step: .1)),
        pair(
            numeric('旋转角度 °', s.rotation, (v) => s.rotation = v % 360,
                min: 0, max: 360, step: .1),
            s.kind == 'triangle'
                ? Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: TextButton(
                        style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6))),
                        onPressed: () => c.edit(
                            () => s.height = s.width * math.sqrt(3) / 2),
                        child: const Text('设为等边',
                            style: TextStyle(fontSize: 12))))
                : const SizedBox.shrink()),
        if (line) ...[
          _shapeToggle('圆头端点', s.round, () => c.edit(() => s.round = !s.round)),
          _shapeToggle('虚线', s.dashed, () => c.edit(() => s.dashed = !s.dashed)),
        ],
        if (s.kind == 'parallelogram')
          numeric('倾斜程度 %', s.skew * 100, (v) => s.skew = v / 100,
              min: 0, max: 85, step: .5),
        if (s.kind == 'trapezoid')
          numeric('上边收窄 %', s.inset * 100, (v) => s.inset = v / 100,
              min: 0, max: 49, step: .5),
        if (s.kind == 'hexagon') ...[
          _shapeSelect('朝向', s.pointy ? 'pointy' : 'flat',
              const {'flat': '平顶', 'pointy': '尖顶'},
              (v) => s.pointy = v == 'pointy'),
          numeric('角部收窄 %', s.inset * 100, (v) => s.inset = v / 100,
              min: 0, max: 50, step: .5),
        ],
        if (shapeHasRadius(s))
          numeric('圆角 px', s.radius, (v) => s.radius = v,
              min: 0, max: shapeMaxCut(s), step: .1),
        Text(
            line
                ? '拖动线条两端的方块调整长度；拖动上方圆形抓点旋转，Shift 以 15° 为步进。'
                : '拖动方块调整宽高（Shift 等比）；金色圆点调整圆角或形状；上方圆形抓点旋转，Shift 以 15° 为步进。',
            style: EditorTypography.hint(context)),
        if (circle)
          Text('宽高不同时为椭圆。', style: EditorTypography.hint(context)),
        const SizedBox(height: 4),
        Text('尺寸按照片短边 1000 px 为基准。', style: EditorTypography.hint(context)),
      ]),
      section(line ? '线条颜色' : '填充', [
        if (hasFillChoice)
          _shapeToggle('启用填充', s.fill, () => c.edit(() => s.fill = !s.fill)),
        if (s.fill) ...[
          colorField(
              line
                  ? '颜色'
                  : s.kind == 'triangle' && s.split
                      ? '左半填充颜色'
                      : '填充颜色',
              s.fillColor,
              (v) => s.fillColor = v),
          if (s.kind == 'triangle') ...[
            _shapeToggle(
                '左右分别设色', s.split, () => c.edit(() => s.split = !s.split)),
            if (s.split)
              colorField('右半填充颜色', s.fillColor2, (v) => s.fillColor2 = v),
          ],
          _shapeOpacity('填充不透明度', s.fillOpacity, (v) => s.fillOpacity = v),
        ],
      ]),
      if (!line)
        section('描边', [
          _shapeToggle('启用描边', s.stroke, () => c.edit(() => s.stroke = !s.stroke)),
          if (s.stroke) ...[
            numeric('描边粗细 px', s.strokeWidth, (v) => s.strokeWidth = v,
                min: .1, max: 200, step: .1),
            colorField('描边颜色', s.strokeColor, (v) => s.strokeColor = v),
            _shapeOpacity('描边不透明度', s.strokeOpacity, (v) => s.strokeOpacity = v),
          ],
        ]),
    ]);
  }
}
