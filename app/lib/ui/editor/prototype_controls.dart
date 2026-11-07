import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// One anchored picker for editor fields and canvas inspection modes.
/// Popup routes provide keyboard navigation, Escape and outside-click dismissal.
class PrototypeSelect extends StatelessWidget {
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  final TextStyle? textStyle;
  final TextStyle Function(String)? optionStyle;
  const PrototypeSelect(
      {super.key,
      required this.value,
      required this.options,
      this.textStyle,
      this.optionStyle,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final fill =
        theme.inputDecorationTheme.fillColor ?? theme.scaffoldBackgroundColor;
    return Builder(
        builder: (fieldContext) => SizedBox(
            height: 38,
            child: TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    foregroundColor: scheme.onSurface,
                    backgroundColor: fill,
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
                  final selected = await showMenu<String>(
                      context: context,
                      popUpAnimationStyle: AnimationStyle.noAnimation,
                      position: RelativeRect.fromRect(
                          Rect.fromLTWH(
                              origin.dx,
                              origin.dy + box.size.height + 5,
                              box.size.width,
                              0),
                          Offset.zero & overlay.size),
                      constraints:
                          BoxConstraints.tightFor(width: box.size.width),
                      color: scheme.surface,
                      surfaceTintColor: Colors.transparent,
                      elevation: 12,
                      shadowColor: Colors.black.withValues(alpha: .5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: scheme.onSurface.withValues(alpha: .08))),
                      menuPadding: const EdgeInsets.all(5),
                      items: [
                        for (final entry in options.entries)
                          PopupMenuItem<String>(
                              value: entry.key,
                              height: 38,
                              padding: EdgeInsets.zero,
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 9),
                                  decoration: BoxDecoration(
                                      color: entry.key == value
                                          ? scheme.surfaceContainerHighest
                                          : null,
                                      borderRadius: BorderRadius.circular(5)),
                                  child: Row(children: [
                                    Expanded(
                                        child: Text(entry.value,
                                            style:
                                                optionStyle?.call(entry.key) ??
                                                    EditorTypography.value(
                                                        context))),
                                    const SizedBox(width: 8),
                                    if (entry.key == value)
                                      Icon(Icons.check_rounded,
                                          size: 16, color: scheme.primary)
                                  ])))
                      ]);
                  if (context.mounted && selected != null && selected != value)
                    onChanged(selected);
                },
                child: Row(children: [
                  Expanded(
                      child: Text(options[value] ?? '多个值',
                          overflow: TextOverflow.ellipsis,
                          style: optionStyle?.call(value ?? "") ??
                              textStyle ??
                              EditorTypography.value(context))),
                  const SizedBox(width: 8),
                  const PrototypeIcon('chevronDown', size: 14)
                ]))));
  }
}

/// Paths are exported directly from the approved browser prototype, on a 24 px grid.
class PrototypeIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  final bool ui;
  const PrototypeIcon(this.name,
      {super.key, this.size = 20, this.color, this.ui = false});
  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: size,
      child: Center(
          child: SvgPicture.asset('assets/ui/${ui ? 'ui' : 'layer'}-$name.svg',
              width: size,
              height: size,
              fit: BoxFit.contain,
              theme: SvgTheme(
                  currentColor: color ??
                      Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .75)),
              excludeFromSemantics: true)));
}

class EditorModeSwitch extends StatelessWidget {
  final bool editing;
  final VoidCallback onBrowse;
  final VoidCallback? onEdit;
  const EditorModeSwitch(
      {super.key,
      required this.editing,
      required this.onBrowse,
      required this.onEdit});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final edit in [false, true])
            Tooltip(
                message: edit ? '编辑当前样式或新建样式' : '浏览照片、选择预设',
                child: TextButton(
                    style: TextButton.styleFrom(
                        minimumSize: const Size(60, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        backgroundColor: editing == edit
                            ? scheme.surfaceContainerHighest
                            : Colors.transparent,
                        foregroundColor:
                            editing == edit ? scheme.primary : scheme.onSurface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6))),
                    onPressed: edit ? onEdit : onBrowse,
                    child: Text(edit ? '编辑' : '浏览',
                        style: const TextStyle(fontSize: 13))))
        ]));
  }
}

class PrototypeTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool expand;
  final Widget? trailing;
  const PrototypeTabs(
      {super.key,
      required this.labels,
      required this.selected,
      required this.onSelect,
      this.expand = false,
      this.trailing});

  /// One tab's width: the label's own length plus padding, never below 56.
  ///
  /// Measured from the characters rather than laid out, because a Row cannot
  /// size a child from its content without a Flexible wrapper, and wrapping
  /// each tab in a Flexible would let a long label squeeze the others.
  static double _tabSlotWidth(String label) {
    // Chinese characters are about one font-size wide, Latin about half.
    var units = 0.0;
    for (final rune in label.runes) {
      units += rune < 0x2e80 ? 0.56 : 1.0;
    }
    // 13 px text, 11 px padding either side, plus a little slack.
    return math.max(56, units * 13 * 0.92 + 22);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget item(int i) => Stack(children: [
          Positioned.fill(
              child: TextButton(
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      foregroundColor:
                          selected == i ? scheme.primary : scheme.onSurface,
                      shape: const RoundedRectangleBorder()),
                  onPressed: () => onSelect(i),
                  child: Text(labels[i],
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(fontSize: 13)))),
          if (i == selected)
            Positioned(
                bottom: 0,
                left: 12,
                right: 12,
                height: 2,
                child: ColoredBox(color: scheme.primary))
        ]);
    return SizedBox(
        height: expand ? 43 : 49,
        child: Padding(
            padding: EdgeInsets.symmetric(horizontal: expand ? 15 : 10),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < labels.length; i++)
                if (expand)
                  Expanded(child: item(i))
                else
                  // Wide enough for a two-word label like "高德 API" on one
                  // line; the old 56 px slot forced it to wrap.
                  SizedBox(width: _tabSlotWidth(labels[i]), child: item(i)),
              if (!expand) const Spacer(),
              if (trailing != null)
                Center(child: SizedBox.square(dimension: 28, child: trailing!))
            ])));
  }
}

class PrototypeActionButton extends StatelessWidget {
  final String label, icon;
  final VoidCallback? onPressed;
  final bool primary, iconAfter;
  const PrototypeActionButton(
      {super.key,
      required this.label,
      required this.icon,
      required this.onPressed,
      this.primary = false,
      this.iconAfter = false});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme,
        ink = primary ? scheme.onPrimary : scheme.onSurface;
    final glyph = Opacity(
        opacity: onPressed == null ? .4 : 1,
        child: PrototypeIcon(icon, size: 16, color: ink));
    return SizedBox(
        height: 40,
        child: TextButton(
            style: TextButton.styleFrom(
                backgroundColor:
                    primary ? scheme.primary : scheme.surfaceContainerHighest,
                foregroundColor: ink,
                disabledForegroundColor: ink.withValues(alpha: .35),
                padding: const EdgeInsets.symmetric(horizontal: 9),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6))),
            onPressed: onPressed,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (!iconAfter) ...[glyph, const SizedBox(width: 7)],
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              if (iconAfter) ...[const SizedBox(width: 7), glyph]
            ])));
  }
}

class WorkspaceBrand extends StatelessWidget {
  const WorkspaceBrand({super.key});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(children: [
        Image.asset('assets/branding/lumacraft-icon-1024.png',
            width: 30, height: 30),
        const SizedBox(width: 10),
        const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LumaCraft',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .6)),
              Text('框印工坊', style: TextStyle(fontSize: 12))
            ])
      ]));
}

class EditorTypography {
  /// Opacity for dimmed body text (inactive labels, secondary badges).
  ///
  /// Measured in light mode: 0.60 gave 3.40:1 on the card background, below
  /// the 4.5:1 readable minimum. 0.72 is the lowest value that clears the
  /// panel, input and card backgrounds at once, so it is used everywhere
  /// instead of each call site picking its own number.
  static const dimOpacity = .72;

  /// Text that sits on a coloured accent fill, such as a switch track.
  static Color dimOn(BuildContext context) => Theme.of(context)
      .colorScheme
      .onSurface
      .withValues(alpha: dimOpacity);

  static Color muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xffaaa69c)
          // Measured against the panel, input, card and page backgrounds:
          // the old #766e63 dropped to 3.76:1 on the page colour, which is
          // below the 4.5:1 readable minimum. This one clears all four.
          : const Color(0xff625a4f);
  static TextStyle title(BuildContext context) => TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.5,
      color: Theme.of(context).colorScheme.onSurface);
  static TextStyle label(BuildContext context) => TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: muted(context));
  static TextStyle hint(BuildContext context) =>
      label(context).copyWith(height: 1.8);
  static TextStyle value(BuildContext context) => TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: Theme.of(context).colorScheme.onSurface);
}
