part of 'editor_page.dart';

extension PalettePanel on _PresetEditorState {
  Widget paletteProperties(StyleNode node) {
    final p = node.palette, colors = paletteFromFields(fields);
    Widget label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: EditorTypography.label(context)));
    Widget select(String title, String value, Map<String, String> options,
            ValueChanged<String> change) =>
        Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  label(title),
                  PrototypeSelect(
                      value: value,
                      options: options,
                      onChanged: (v) => c.edit(() => change(v)))
                ]));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      section('照片配色', [
        if (colors.length == 6)
          Row(children: [
            for (final color in p.reversed ? colors.reversed : colors)
              Expanded(
                  child: Tooltip(
                      message:
                          '#${(color & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                      child: Container(
                          height: 26,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                              color: Color(color),
                              borderRadius: BorderRadius.circular(4)))))
          ]),
        const SizedBox(height: 10),
        Text(
            paletteError ??
                (colors.length == 6 ? '自动提取原照片的六种代表色，随照片更新。' : '正在提取照片配色…'),
            style: EditorTypography.hint(context)),
        Row(children: [
          Expanded(
              child: TextButton(
                  onPressed: () => c.edit(() => p.reversed = !p.reversed),
                  child: const Text('反转顺序'))),
          if (paletteError != null)
            Expanded(
                child: TextButton(
                    onPressed: () => ensurePhotoPalette(),
                    child: const Text('重新提取')))
        ]),
      ]),
      section('色卡外观', [
        if (p.mode == 'blocks')
          pair(
              select('形式', p.mode, const {'blocks': '独立色块', 'strip': '连续色条'},
                  (v) => p.mode = v),
              select(
                  '形状',
                  p.shape,
                  const {
                    'circle': '圆形',
                    'roundedRect': '圆角矩形',
                    'hexagon': '六边形'
                  },
                  (v) => p.shape = v))
        else
          select('形式', p.mode, const {'blocks': '独立色块', 'strip': '连续色条'},
              (v) => p.mode = v),
        if (p.mode == 'strip')
          pair(
              numeric('总宽度 px', p.size * 6, (v) => p.size = v / 6,
                  min: 24, max: 1800),
              numeric('高度 px', p.height, (v) => p.height = v, min: 4, max: 300))
        else if (p.shape == 'roundedRect')
          pair(numeric('宽度 px', p.size, (v) => p.size = v, min: 4, max: 300),
              numeric('高度 px', p.height, (v) => p.height = v, min: 4, max: 300))
        else
          numeric(p.shape == 'circle' ? '直径 px' : '边长 px', p.size,
              (v) => p.size = v,
              min: 4, max: 300),
        if (p.mode == 'blocks' && p.shape != 'circle')
          pair(
              numeric('间距 px', p.gap, (v) => p.gap = v, max: 100, step: .1),
              numeric('圆角 px', p.radius, (v) => p.radius = v,
                  max: 150, step: .1))
        else if (p.mode == 'blocks')
          numeric('间距 px', p.gap, (v) => p.gap = v, max: 100, step: .1)
        else
          numeric('圆角 px', p.radius, (v) => p.radius = v, max: 150, step: .1),
        Text('圆角随形状尺寸限制；间距按外轮廓计算。', style: EditorTypography.hint(context)),
        const SizedBox(height: 12),
        numeric('整体缩放 %', p.scale * 100, (v) => p.scale = v / 100,
            min: 10, max: 600),
        opacityControl([node]),
        const SizedBox(height: 12),
        Text('尺寸按照片短边 1000 px 为基准；整体缩放同步调整间距和描边。',
            style: EditorTypography.hint(context)),
      ]),
      section('描边', [
        Row(children: [
          Expanded(child: Text('启用描边', style: EditorTypography.label(context))),
          Semantics(
              label: '启用描边',
              toggled: p.stroke,
              child: SizedBox(
                  width: 42,
                  height: 32,
                  child: TextButton(
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6))),
                      onPressed: () => c.edit(() => p.stroke = !p.stroke),
                      child: Container(
                          width: 30,
                          height: 16,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                              color: p.stroke
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8)),
                          child: Align(
                              alignment: p.stroke
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                      color: p.stroke
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onPrimary
                                          : EditorTypography.muted(context),
                                      shape: BoxShape.circle)))))))
        ]),
        if (p.stroke) ...[
          if (p.mode == 'strip')
            select(
                '描边范围',
                p.strokeMode,
                const {'outer': '整体描边', 'each': '每块描边'},
                (v) => p.strokeMode = v),
          pair(
              numeric('描边粗细 px', p.strokeWidth, (v) => p.strokeWidth = v,
                  min: .1, max: 30, step: .1),
              numeric('描边间距 px', p.strokeGap, (v) => p.strokeGap = v,
                  min: 0, max: 10, step: .1)),
          colorField('描边颜色', p.strokeColor, (v) => p.strokeColor = v),
          Text(p.strokeGap == 0 ? '间距为0时保留内描边。' : '描边向外留透明间隙；色条内部的分隔线保持相连。',
              style: EditorTypography.hint(context)),
        ]
      ]),
    ]);
  }
}
