import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../editor/background_style.dart';
import '../../editor/texture_render.dart';
import 'prototype_controls.dart';

/// 纹理缩略图：用当前底色、纹理颜色和大小画一小块边框，所见即所得。
class TextureSwatch extends StatelessWidget {
  final BackgroundStyle fill;
  final int base;
  final String kind;
  final Size size;
  const TextureSwatch(
      {super.key,
      required this.fill,
      required this.base,
      required this.kind,
      required this.size});
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CustomPaint(
          size: size,
          painter: _SwatchPainter(fill, base, kind,
              Theme.of(context).colorScheme.onSurface.withValues(alpha: .1))));
}

class _SwatchPainter extends CustomPainter {
  final BackgroundStyle fill;
  final int base;
  final String kind;
  final Color edge;
  _SwatchPainter(this.fill, this.base, this.kind, this.edge)
      : super(repaint: textureTiles);

  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    canvas.drawRect(area, Paint()..color = Color(base));
    // 缩略图约等于 1/3 预览尺寸；不透明度过低时适当提亮，避免看不出纹理。
    const k = .32;
    final sample = BackgroundStyle(
        mode: 'texture',
        texture: kind,
        textureColor: fill.textureColor,
        textureOpacity: math.max(fill.textureOpacity, 45),
        textureScale: fill.textureScale);
    canvas.save();
    canvas.scale(k);
    paintTexture(canvas, sample, Offset.zero & (size / k),
        const Rect.fromLTWH(-100, -100, 0, 0));
    canvas.restore();
    canvas.drawRect(
        area.deflate(.5),
        Paint()
          ..color = edge
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _SwatchPainter old) =>
      old.kind != kind ||
      old.base != base ||
      old.fill.textureColor != fill.textureColor ||
      old.fill.textureOpacity != fill.textureOpacity ||
      old.fill.textureScale != fill.textureScale;
}

/// 纹理选择器：弹出当前风格下的纹理缩略图网格，与形状选择器同款，直接打开和关闭。
class TexturePicker extends StatelessWidget {
  final BackgroundStyle fill;
  final int base;
  final ValueChanged<String> onChanged;
  const TexturePicker(
      {super.key,
      required this.fill,
      required this.base,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final background =
        theme.inputDecorationTheme.fillColor ?? theme.scaffoldBackgroundColor;
    final kinds = textureGroups[textureGroupOf(fill.texture)]?.$2 ??
        textureGroups.values.first.$2;
    return Builder(
        builder: (fieldContext) => SizedBox(
            height: 38,
            child: TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.only(left: 7, right: 12),
                    foregroundColor: scheme.onSurface,
                    backgroundColor: background,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5))),
                onPressed: () async {
                  final box = fieldContext.findRenderObject() as RenderBox;
                  final overlay = Navigator.of(context)
                      .overlay!
                      .context
                      .findRenderObject() as RenderBox;
                  final origin =
                      box.localToGlobal(Offset.zero, ancestor: overlay);
                  final columns = math.min(kinds.length, 4);
                  final width =
                      math.max(box.size.width, columns * _cellWidth + 12.0);
                  final right = origin.dx + box.size.width;
                  final selected = await showMenu<String>(
                      context: context,
                      popUpAnimationStyle: AnimationStyle.noAnimation,
                      position: RelativeRect.fromRect(
                          Rect.fromLTWH(right - width,
                              origin.dy + box.size.height + 5, width, 0),
                          Offset.zero & overlay.size),
                      constraints: BoxConstraints.tightFor(width: width),
                      color: scheme.surface,
                      surfaceTintColor: Colors.transparent,
                      elevation: 12,
                      shadowColor: Colors.black.withValues(alpha: .5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: scheme.onSurface.withValues(alpha: .08))),
                      menuPadding: const EdgeInsets.all(6),
                      items: [_TextureGridEntry(fill, base, kinds, columns)]);
                  if (context.mounted &&
                      selected != null &&
                      selected != fill.texture) {
                    onChanged(selected);
                  }
                },
                child: Row(children: [
                  TextureSwatch(
                      fill: fill,
                      base: base,
                      kind: fill.texture,
                      size: const Size(26, 22)),
                  const SizedBox(width: 9),
                  Expanded(
                      child: Text(textureKindNames[fill.texture] ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: EditorTypography.value(context))),
                  const SizedBox(width: 8),
                  const PrototypeIcon('chevronDown', size: 14)
                ]))));
  }
}

const _cellWidth = 84.0, _cellHeight = 92.0;

class _TextureGridEntry extends PopupMenuEntry<String> {
  final BackgroundStyle fill;
  final int base;
  final Map<String, String> kinds;
  final int columns;
  const _TextureGridEntry(this.fill, this.base, this.kinds, this.columns);
  int get rows => (kinds.length / columns).ceil();
  @override
  double get height => rows * _cellHeight + (rows - 1) * 4;
  @override
  bool represents(String? v) => false;
  @override
  State<_TextureGridEntry> createState() => _TextureGridEntryState();
}

class _TextureGridEntryState extends State<_TextureGridEntry> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final kinds = widget.kinds.entries.toList();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (var row = 0; row < widget.rows; row++)
        Padding(
            padding: EdgeInsets.only(top: row == 0 ? 0 : 4),
            child: Row(children: [
              for (var col = 0; col < widget.columns; col++)
                Expanded(
                    child: row * widget.columns + col < kinds.length
                        ? _cell(context, scheme,
                            kinds[row * widget.columns + col])
                        : const SizedBox.shrink())
            ]))
    ]);
  }

  Widget _cell(BuildContext context, ColorScheme scheme,
      MapEntry<String, String> kind) {
    final selected = kind.key == widget.fill.texture;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Semantics(
            button: true,
            selected: selected,
            label: kind.value,
            child: InkWell(
                borderRadius: BorderRadius.circular(6),
                hoverColor: scheme.onSurface.withValues(alpha: .06),
                onTap: () => Navigator.pop(context, kind.key),
                child: Container(
                    height: _cellHeight,
                    decoration: BoxDecoration(
                        color: selected ? scheme.surfaceContainerHighest : null,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: selected
                                ? scheme.primary.withValues(alpha: .8)
                                : Colors.transparent)),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextureSwatch(
                              fill: widget.fill,
                              base: widget.base,
                              kind: kind.key,
                              size: const Size(64, 52)),
                          const SizedBox(height: 7),
                          Text(kind.value,
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              softWrap: false,
                              style: TextStyle(
                                  fontSize: 11,
                                  height: 1.2,
                                  color: selected
                                      ? scheme.primary
                                      : scheme.onSurface
                                          .withValues(alpha: .72)))
                        ])))));
  }
}
