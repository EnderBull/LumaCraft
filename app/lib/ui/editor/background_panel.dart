part of 'editor_page.dart';

extension BackgroundPanel on _PresetEditorState {
  Widget propertySelect(String title, String value, Map<String, String> options,
          ValueChanged<String> change) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: EditorTypography.label(context)),
            const SizedBox(height: 8),
            PrototypeSelect(
                value: value,
                options: options,
                onChanged: (v) => c.edit(() => change(v)))
          ]));

  Widget compactToggle(String label, bool enabled, VoidCallback change) =>
      Row(children: [
        Expanded(child: Text(label, style: EditorTypography.label(context))),
        Semantics(
            label: label,
            toggled: enabled,
            child: SizedBox(
                width: 42,
                height: 32,
                child: TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: change,
                    child: Container(
                        width: 30,
                        height: 16,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            color: enabled
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8)),
                        child: Align(
                            alignment: enabled
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: enabled
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                        : EditorTypography.muted(context))))))))
      ]);

  Widget triple(Widget a, Widget b, Widget d) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: a),
        const SizedBox(width: 10),
        Expanded(child: b),
        const SizedBox(width: 10),
        Expanded(child: d)
      ]);

  Widget shadowSlider(
          String title, double value, ValueChanged<double> change) =>
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
                value: value.clamp(0, 100),
                min: 0,
                max: 100,
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                semanticFormatterCallback: (v) => '$title ${v.round()}%',
                onChangeStart: (_) => c.begin(),
                onChanged: (v) {
                  change(v);
                  c.update();
                },
                onChangeEnd: (_) => c.end())),
      ]);

  Widget shadowProperties() {
    final s = c.doc.shadow;
    return section('照片投影', [
      compactToggle(
          '启用投影', s.enabled, () => c.edit(() => s.enabled = !s.enabled)),
      if (s.enabled) ...[
        const SizedBox(height: 10),
        triple(
            numeric('角度 °', s.angle, (v) => s.angle = v, max: 360),
            numeric('距离 px', s.distance, (v) => s.distance = v,
                max: 200, step: .1),
            numeric('大小 px', s.size, (v) => s.size = v, max: 100, step: .1)),
        shadowSlider('不透明度', s.opacity, (v) => s.opacity = v),
        const SizedBox(height: 14),
        shadowSlider('羽化程度', s.feather, (v) => s.feather = v),
        const SizedBox(height: 14),
        colorField('投影颜色', s.color, (v) => s.color = v),
      ]
    ]);
  }

  Widget backgroundProperties() {
    final fill = c.doc.fill, colors = paletteFromFields(fields);
    return section('背景填充', [
      propertySelect(
          '填充方式',
          fill.mode,
          const {'solid': '纯色', 'gradient': '双色渐变', 'blur': '照片模糊'},
          (v) => fill.mode = v),
      if (fill.mode != 'blur') ...[
        if (fill.mode == 'gradient')
          pair(
              colorField('起始颜色', c.doc.background, (v) => c.doc.background = v),
              colorField('结束颜色', fill.secondColor, (v) => fill.secondColor = v))
        else
          colorField('背景颜色', c.doc.background, (v) => c.doc.background = v),
        if (fill.mode == 'gradient') ...[
          propertySelect(
              '渐变类型',
              fill.gradientType,
              const {'linear': '线性渐变', 'radial': '中心渐变'},
              (v) => fill.gradientType = v),
          if (fill.gradientType == 'radial') ...[
            pair(numeric('中心 X %', fill.centerX, (v) => fill.centerX = v),
                numeric('中心 Y %', fill.centerY, (v) => fill.centerY = v)),
            numeric('扩散范围 %', fill.radius, (v) => fill.radius = v,
                min: 1, max: 200),
          ],
          pair(
              fill.gradientType == 'linear'
                  ? numeric('方向 °', fill.angle, (v) => fill.angle = v, max: 360)
                  : const SizedBox.shrink(),
              Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: neutral(
                      '交换颜色',
                      () => c.edit(() {
                            final old = c.doc.background;
                            c.doc.background = fill.secondColor;
                            fill.secondColor = old;
                          }),
                      icon: Icons.swap_horiz))),
          propertySelect(
              '照片取色应用至',
              backgroundSecond ? 'end' : 'start',
              const {'start': '起始颜色', 'end': '结束颜色'},
              (v) => backgroundSecond = v == 'end'),
        ],
        Text('快捷颜色', style: EditorTypography.label(context)),
        const SizedBox(height: 9),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final color in [0xfff3f0e8, 0xffffffff, 0xff121212, ...colors])
            ColorSwatchButton(
                color: Color(color),
                label: colorHex(Color(color)),
                onPressed: () => c.edit(() {
                      if (fill.mode == 'gradient' && backgroundSecond) {
                        fill.secondColor = color;
                      } else {
                        c.doc.background = color;
                      }
                    }))
        ]),
        if (colors.length != 6)
          TextButton(
              onPressed: () => ensurePhotoPalette(),
              child: const Text('提取照片配色')),
        if (paletteError != null)
          Text(paletteError!, style: EditorTypography.hint(context)),
      ] else ...[
        numeric('模糊强度', fill.blur, (v) => fill.blur = v, max: 100, step: .5),
        triple(
            numeric('明度', fill.brightness, (v) => fill.brightness = v,
                min: -100, max: 100),
            numeric('对比度 %', fill.contrast, (v) => fill.contrast = v, max: 200),
            numeric('饱和度 %', fill.saturation, (v) => fill.saturation = v,
                max: 200)),
        Text('使用当前照片铺满背景，调整只影响背景；前景保留完整构图。',
            style: EditorTypography.hint(context)),
      ],
    ]);
  }

  Widget textureProperties() {
    final fill = c.doc.fill, group = textureGroupOf(fill.texture);
    return section('边框纹理', [
      pair(
          propertySelect(
              '纹理风格',
              group,
              {
                'none': '无',
                for (final e in textureGroups.entries) e.key: e.value.$1
              },
              (v) => fill.texture =
                  v == 'none' ? 'none' : textureGroups[v]!.$2.keys.first),
          group == 'none'
              ? const SizedBox.shrink()
              : propertySelect('纹理', fill.texture,
                  textureGroups[group]!.$2, (v) => fill.texture = v)),
      if (fill.hasTexture) ...[
        shadowSlider('不透明度', fill.textureOpacity,
            (v) => fill.textureOpacity = v),
        const SizedBox(height: 14),
        pair(
            numeric('大小 %', fill.textureScale, (v) => fill.textureScale = v,
                min: 50, max: 300),
            colorField('纹理颜色', fill.textureColor,
                (v) => fill.textureColor = v)),
        Text('纹理只铺在边框上，不影响照片。', style: EditorTypography.hint(context)),
      ]
    ]);
  }

  Widget filmProperties() {
    final f = c.doc.film, g = StyleGeometry(c.doc, ratio);
    final vertical = f.verticalFor(g.photo), hole = f.holeFor(g.photo);
    final required = (vertical ? hole.width : hole.height) + f.inset;
    final available = vertical ? [g.left, g.right] : [g.top, g.bottom];
    return section('胶片打孔', [
      compactToggle(
          '启用装饰', f.enabled, () => c.edit(() => f.enabled = !f.enabled)),
      if (f.enabled) ...[
        const SizedBox(height: 10),
        propertySelect(
            '排列位置',
            f.orientation,
            const {
              'vertical': '左右双侧',
              'horizontal': '上下双侧',
              'long': '沿长边'
            },
            (v) => f.orientation = v),
        if (f.orientation == 'long')
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('横图、方图排在上下，竖图排在左右。孔宽、孔高按横图填写，竖图自动转向。',
                  style: EditorTypography.hint(context))),
        triple(
            numeric('孔宽 px', f.width, (v) => f.width = v,
                min: 2, max: 100, step: .1),
            numeric('孔高 px', f.height, (v) => f.height = v,
                min: 2, max: 100, step: .1),
            numeric('圆角 px', f.radius, (v) => f.radius = v, max: 50, step: .1)),
        pair(numeric('孔间距 px', f.gap, (v) => f.gap = v, max: 100, step: .1),
            numeric('距外缘 px', f.inset, (v) => f.inset = v, max: 100, step: .1)),
        colorField('孔洞颜色', f.color, (v) => f.color = v),
        Text(
            available.any((a) => a < required)
                ? '部分边框空间不足，暂不显示该侧孔洞；增大边框或缩小孔洞。'
                : '模拟孔洞允许在画布边缘裁切成半孔，不改变图片透明度。',
            style: EditorTypography.hint(context)),
      ]
    ]);
  }
}
