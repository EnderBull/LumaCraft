import 'dart:io';

import 'package:flutter/material.dart';

import '../../editor/image_mark.dart';
import '../../editor/postmark.dart';
import '../../editor/shape_style.dart';
import '../../editor/style_document.dart';
import '../../export/android_photo_io.dart';
import '../../fonts/font_catalog.dart';
import '../../photo_state.dart';
import '../editor/hsb_color_picker.dart';
import 'alpha_workspace.dart';
import 'mobile_fields.dart';
import 'mobile_photo_info_page.dart';

class MobileEditorPanel extends StatefulWidget {
  const MobileEditorPanel({
    super.key,
    required this.workspace,
    required this.selected,
    required this.onSelected,
    required this.onClose,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
  });

  final AlphaWorkspace workspace;
  final String? selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onClose;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final GestureDragCancelCallback onDragCancel;

  @override
  State<MobileEditorPanel> createState() => _MobileEditorPanelState();
}

class _MobileEditorPanelState extends State<MobileEditorPanel> {
  final _selectedChip = GlobalKey();
  AlphaWorkspace get workspace => widget.workspace;

  void _revealSelection() => WidgetsBinding.instance.addPostFrameCallback((_) {
        final chip = _selectedChip.currentContext;
        if (!mounted || chip == null) return;
        final position = Scrollable.of(chip).position;
        final box = chip.findRenderObject();
        final viewport = position.context.storageContext.findRenderObject();
        if (box is! RenderBox ||
            viewport is! RenderBox ||
            !box.hasSize ||
            !viewport.hasSize) return;
        final left = viewport.globalToLocal(box.localToGlobal(Offset.zero)).dx;
        final right = left + box.size.width;
        final delta = left < 0 ? left : right - viewport.size.width;
        if (left >= 0 && right <= viewport.size.width) return;
        final target = (position.pixels + delta)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
        if (MediaQuery.disableAnimationsOf(chip)) {
          position.jumpTo(target);
        } else {
          position.animateTo(target,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic);
        }
      });
  @override
  void initState() {
    super.initState();
    _revealSelection();
  }

  @override
  void didUpdateWidget(covariant MobileEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _revealSelection();
  }

  Future<void> _replaceImage(String id) async {
    try {
      final source = await AndroidPhoto.pick();
      if (source == null) return;
      final file = File(source.path);
      try {
        final mark = await importImageMark(source.path);
        if (!mounted) return;
        workspace.editComponent(id, (node) {
          node.image
            ..data = mark.data
            ..ratio = mark.ratio
            ..filename = source.name.split(RegExp(r'[/\\]')).last;
        });
      } finally {
        await file.delete();
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('替换素材失败 · $error')),
        );
      }
    }
  }

  IconData _componentIcon(String type) => switch (type) {
        'shape' => Icons.category_outlined,
        'image' => Icons.image_outlined,
        'palette' => Icons.palette_outlined,
        'place' => Icons.place_outlined,
        'camera' => Icons.photo_camera_outlined,
        'lens' => Icons.camera_outlined,
        'time' => Icons.schedule_outlined,
        'signature' => Icons.draw_outlined,
        'params' => Icons.tune,
        _ => Icons.text_fields,
      };

  Widget _chip(ThemeData theme, StyleNode node, StyleNode? selected) {
    final colors = theme.colorScheme;
    final active = node.id == selected?.id;
    return Semantics(
      key: active ? _selectedChip : null,
      selected: active,
      child: Material(
        color:
            active ? colors.primaryContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            FocusScope.of(context).unfocus();
            widget.onSelected(node.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(_componentIcon(node.type),
                    size: 16,
                    color: active
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(node.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color:
                          active ? colors.onPrimaryContainer : colors.onSurface,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final nodes = workspace.style.nodes;
    final selected =
        widget.selected == null ? null : workspace.style.node(widget.selected!);
    return Material(
      color: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
          builder: (context, bounds) => Column(
                children: [
                  if (bounds.maxHeight >= 120)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: widget.onDragUpdate,
                      onVerticalDragEnd: widget.onDragEnd,
                      onVerticalDragCancel: widget.onDragCancel,
                      child: Column(
                        children: [
                          SizedBox(
                            height: 24,
                            child: Center(
                              child: Container(
                                width: theme.bottomSheetTheme.dragHandleSize
                                        ?.width ??
                                    32,
                                height: theme.bottomSheetTheme.dragHandleSize
                                        ?.height ??
                                    4,
                                decoration: BoxDecoration(
                                  color:
                                      theme.bottomSheetTheme.dragHandleColor ??
                                          colors.onSurfaceVariant
                                              .withValues(alpha: .4),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 44,
                            child: Row(
                              children: [
                                const SizedBox(width: 14),
                                Expanded(
                                    child: Text('编辑样式',
                                        style: theme.textTheme.titleSmall)),
                                IconButton(
                                    tooltip: '收起编辑',
                                    onPressed: widget.onClose,
                                    icon: const Icon(Icons.keyboard_arrow_down,
                                        size: 23)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (nodes.isNotEmpty && bounds.maxHeight >= 100)
                    ColoredBox(
                      color: colors.surfaceContainer,
                      child: SizedBox(
                        height: 52,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          child: Row(
                            spacing: 7,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final node in nodes)
                                _chip(theme, node, selected)
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: selected == null
                        ? Center(
                            child:
                                Text(nodes.isEmpty ? '此预设没有可编辑的组件。' : '请选择组件'))
                        : ListView(
                            key: ValueKey(selected.id),
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                            children: [
                              if (workspace.style.locked(selected.id))
                                const Text('该组件已锁定。')
                              else
                                _MobileProperties(
                                  node: selected,
                                  workspace: workspace,
                                  replaceImage: () =>
                                      _replaceImage(selected.id),
                                ),
                              if (captureFieldsForComponent(selected.type)
                                      .isNotEmpty &&
                                  workspace.current != null) ...[
                                const SizedBox(height: 12),
                                Text('当前照片', style: theme.textTheme.titleSmall),
                                MobileCaptureFields(
                                  workspace: workspace,
                                  keys:
                                      captureFieldsForComponent(selected.type),
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
              )),
    );
  }
}

Widget _pair(Widget a, Widget? b) => b == null
    ? a
    : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: 10),
          Expanded(child: b)
        ],
      );

class _MobileProperties extends StatelessWidget {
  final StyleNode node;
  final AlphaWorkspace workspace;
  final VoidCallback replaceImage;

  const _MobileProperties({
    required this.node,
    required this.workspace,
    required this.replaceImage,
  });

  void edit(void Function(StyleNode) change) =>
      workspace.editComponent(node.id, change);

  Widget number(String label, double Function(StyleNode) read, double min,
          double max, void Function(StyleNode, double) apply,
          {double step = 1}) =>
      MobileNumberField(
        label: label,
        value: read(node),
        defaultValue: read(workspace.presetDefault(node.id) ?? node),
        min: min,
        max: max,
        step: step,
        onReset: () => workspace.resetComponentNumber(node.id, read, apply),
        onPreview: (value) => workspace.previewComponent(
            node.id, value == null ? null : (n) => apply(n, value)),
        onChanged: (value) {
          if (value != null) edit((n) => apply(n, value));
        },
      );

  Widget color(String label, int value, void Function(StyleNode, int) apply) =>
      _colorAction(label, value, (_, next) async {
        edit((node) => apply(node, next));
      });

  Widget _colorAction(String label, int value,
          Future<void> Function(BuildContext, int) apply) =>
      Builder(
          builder: (context) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label),
                subtitle: Text(colorHex(Color(value))),
                trailing: ColorSwatchButton(
                  color: Color(value),
                  label: label,
                  onPressed: () async {
                    var chosen = value;
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => HsbColorPicker(
                        initialColor: Color(value),
                        onChanged: (color) => chosen = color.toARGB32(),
                      ),
                    );
                    if (context.mounted &&
                        confirmed == true &&
                        chosen != value) {
                      await apply(context, chosen);
                    }
                  },
                ),
              ));

  Future<void> _recolorPostmark(
      BuildContext context, String kind, int next) async {
    final presetId = workspace.presetId;
    final original = node.image.filename;
    try {
      final mark = await buildPostmark(kind, next);
      if (!context.mounted ||
          workspace.presetId != presetId ||
          workspace.style.node(node.id)?.image.filename != original) return;
      // Keep the width and ratio stored for each composition.
      edit((target) => target.image
        ..data = mark.data
        ..filename = mark.filename);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('邮戳换色失败，请重试。')),
        );
      }
    }
  }

  Widget toggle(
          String label, bool value, void Function(StyleNode, bool) apply) =>
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: value,
          onChanged: (value) => edit((node) => apply(node, value)));

  Widget select(String label, String value, Map<String, String> choices,
          void Function(StyleNode, String) apply) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Builder(
            builder: (context) => mobileFieldLayout(
                context,
                label,
                DropdownButtonFormField<String>(
                  key: ValueKey((label, value)),
                  initialValue: choices.containsKey(value) ? value : null,
                  isExpanded: true,
                  decoration: mobileInputDecoration(context),
                  items: [
                    for (final choice in choices.entries)
                      DropdownMenuItem(
                          value: choice.key, child: Text(choice.value))
                  ],
                  onChanged: (value) {
                    if (value != null) edit((node) => apply(node, value));
                  },
                ))),
      );

  @override
  Widget build(BuildContext context) {
    final shape = node.shape;
    final line = shape.kind == 'line';
    Widget dimension(String label, String key, double Function(StyleNode) read,
        void Function(StyleNode, double) apply) {
      final (min, max) = shapeLimits[key]!;
      return number(label, read, min, max, apply, step: .1);
    }

    final palette = node.palette;
    final override = workspace.caption(node.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('批次样式', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (node.type == 'image') ...[
          if (node.image.filename.isNotEmpty)
            Text(node.image.filename,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          if (postmarkOf(node.image) case (final kind, final ink))
            _colorAction('邮戳墨色', ink,
                (context, next) => _recolorPostmark(context, kind, next))
          else
            OutlinedButton.icon(
                onPressed: replaceImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('替换图片素材')),
          number('图片宽度', (n) => n.image.width, 4, 2000,
              (n, v) => n.image.width = v),
        ] else if (node.type == 'shape') ...[
          select('形状', shape.kind, shapeKindNames, (n, value) {
            n.shape.kind = shape.kind;
            n.shape.applyKind(value);
          }),
          _pair(
            dimension(line ? '长度 px' : '宽度 px', 'width', (n) => n.shape.width,
                (n, v) => n.shape.width = v),
            dimension(line ? '粗细 px' : '高度 px', 'height', (n) => n.shape.height,
                (n, v) => n.shape.height = v),
          ),
          dimension('旋转角度 °', 'rotation', (n) => n.shape.rotation,
              (n, v) => n.shape.rotation = v % 360),
          if (shapeHasRadius(shape))
            dimension('圆角 px', 'radius', (n) => n.shape.radius,
                (n, v) => n.shape.radius = v),
          if (line) ...[
            toggle('圆头端点', shape.round, (n, v) => n.shape.round = v),
            toggle('虚线', shape.dashed, (n, v) => n.shape.dashed = v),
          ],
          if (shape.kind == 'parallelogram')
            number('倾斜程度 %', (n) => n.shape.skew * 100, 0, 85,
                (n, v) => n.shape.skew = v / 100),
          if (shape.kind == 'hexagon')
            toggle('尖顶朝向', shape.pointy, (n, v) => n.shape.pointy = v),
          if (shape.kind == 'hexagon' || shape.kind == 'trapezoid')
            number(
                '收窄程度 %',
                (n) => n.shape.inset * 100,
                0,
                shape.kind == 'hexagon' ? 50 : 49,
                (n, v) => n.shape.inset = v / 100),
          if (!line) toggle('填充', shape.fill, (n, v) => n.shape.fill = v),
          if (shape.fill) ...[
            color(line ? '线条颜色' : '填充颜色', shape.fillColor,
                (n, v) => n.shape.fillColor = v),
            if (shape.kind == 'triangle') ...[
              toggle('双色填充', shape.split, (n, v) => n.shape.split = v),
              if (shape.split)
                color('第二填充色', shape.fillColor2,
                    (n, v) => n.shape.fillColor2 = v),
            ],
          ],
          if (!line) toggle('描边', shape.stroke, (n, v) => n.shape.stroke = v),
          if (!line && shape.stroke) ...[
            color('描边颜色', shape.strokeColor, (n, v) => n.shape.strokeColor = v),
            number('描边粗细', (n) => n.shape.strokeWidth, .1, 200,
                (n, v) => n.shape.strokeWidth = v),
            number('描边不透明度', (n) => n.shape.strokeOpacity, 0, 100,
                (n, v) => n.shape.strokeOpacity = v),
          ],
        ] else if (node.type == 'palette') ...[
          _pair(
            select(
                '展示形式',
                palette.mode,
                const {'blocks': '独立色块', 'strip': '色条'},
                (n, v) => n.palette.mode = v),
            palette.mode == 'blocks'
                ? select(
                    '色块形状',
                    palette.shape,
                    const {
                      'circle': '圆形',
                      'roundedRect': '圆角矩形',
                      'hexagon': '六边形'
                    },
                    (n, v) => n.palette.shape = v)
                : null,
          ),
          _pair(
            number('色块大小', (n) => n.palette.size, 4, 300,
                (n, v) => n.palette.size = v),
            palette.mode == 'strip' || palette.shape == 'roundedRect'
                ? number('色块高度', (n) => n.palette.height, 4, 300,
                    (n, v) => n.palette.height = v)
                : null,
          ),
          if (palette.mode == 'blocks')
            _pair(
              number('色块间距', (n) => n.palette.gap, 0, 100,
                  (n, v) => n.palette.gap = v),
              palette.shape == 'roundedRect'
                  ? number('圆角大小', (n) => n.palette.radius, 0, 150,
                      (n, v) => n.palette.radius = v)
                  : null,
            )
          else
            number('圆角大小', (n) => n.palette.radius, 0, 150,
                (n, v) => n.palette.radius = v),
          number('整体缩放 %', (n) => n.palette.scale * 100, 10, 600,
              (n, v) => n.palette.scale = v / 100),
          toggle('反转色序', palette.reversed, (n, v) => n.palette.reversed = v),
          toggle('描边', palette.stroke, (n, v) => n.palette.stroke = v),
          if (palette.stroke) ...[
            select(
                '描边方式',
                palette.strokeMode,
                const {'outer': '外轮廓', 'each': '每个色块'},
                (n, v) => n.palette.strokeMode = v),
            color('描边颜色', palette.strokeColor,
                (n, v) => n.palette.strokeColor = v),
            _pair(
              number('描边粗细', (n) => n.palette.strokeWidth, .1, 30,
                  (n, v) => n.palette.strokeWidth = v,
                  step: .1),
              number('描边间距', (n) => n.palette.strokeGap, 0, 10,
                  (n, v) => n.palette.strokeGap = v,
                  step: .1),
            ),
            number('描边不透明度', (n) => n.palette.strokeOpacity, 0, 100,
                (n, v) => n.palette.strokeOpacity = v),
          ],
        ] else ...[
          if (node.type == 'text')
            MobileField(
                label: '共用文字',
                value: node.text,
                multiline: true,
                onCommit: (value) {
                  edit((node) => node.text = value);
                  return null;
                }),
          select('字体', node.font, artworkFontOptions, (n, v) => n.font = v),
          _pair(
            number('字号 px', (n) => n.fontSize, 1, double.infinity,
                (n, v) => n.fontSize = v),
            number('字间距 px', (n) => n.spacing, -double.infinity,
                double.infinity, (n, v) => n.spacing = v,
                step: .25),
          ),
          color('文字颜色', node.color, (n, v) => n.color = v),
          select(
              '文字对齐',
              node.align,
              const {'left': '左对齐', 'center': '居中', 'right': '右对齐'},
              (n, v) => n.align = v),
        ],
        _OpacityControl(
          value: node.opacity,
          onPreview: (value) => workspace.previewComponent(
              node.id, value == null ? null : (n) => n.opacity = value),
          onChanged: (value) => edit((n) => n.opacity = value),
        ),
        if (node.type == 'text' && workspace.current != null) ...[
          const SizedBox(height: 14),
          Text('当前照片', style: Theme.of(context).textTheme.titleMedium),
          MobileField(
              label: '仅修改本张文字',
              value: override ?? node.text,
              multiline: true,
              onCommit: (value) {
                workspace.editCaption(
                    node.id, value == node.text ? null : value);
                return null;
              }),
          if (override != null)
            TextButton(
                onPressed: () => workspace.editCaption(node.id, null),
                child: const Text('恢复共用文字')),
        ],
      ],
    );
  }
}

class _OpacityControl extends StatefulWidget {
  const _OpacityControl(
      {required this.value, required this.onPreview, required this.onChanged});

  final double value;
  final ValueChanged<double?> onPreview;
  final ValueChanged<double> onChanged;

  @override
  State<_OpacityControl> createState() => _OpacityControlState();
}

class _OpacityControlState extends State<_OpacityControl> {
  double? _draft;

  @override
  Widget build(BuildContext context) {
    final value = _draft ?? widget.value;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('不透明度'), Text('${value.round()}%')],
        ),
        Slider(
          value: value.clamp(0, 100),
          max: 100,
          semanticFormatterCallback: (value) => '不透明度 ${value.round()}%',
          onChanged: (next) {
            setState(() => _draft = next);
            widget.onPreview(next);
          },
          onChangeEnd: (next) {
            setState(() => _draft = null);
            widget.onChanged(next);
          },
        ),
      ],
    );
  }
}
