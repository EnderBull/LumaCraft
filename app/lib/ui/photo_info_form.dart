import 'package:flutter/material.dart';
import '../photo_state.dart';
import 'editor/prototype_controls.dart';
import 'workspace_dialog.dart';

/// Editable shooting information for one photo.
///
/// Laid out in three fixed groups — device, exposure, time and place — so the
/// panel has the same shape for every photo and nothing moves while filling
/// in. One switch decides whether values the photo already has may be changed:
///
/// * switch off (default) — an existing value is shown as a locked card and
///   cannot be typed into; a missing value is an empty card you can fill;
/// * switch on — every value can be edited, including overwriting.
///
/// Nothing here touches the photo file: values live in the app's own record.
class PhotoInfoForm extends StatefulWidget {
  /// What the photo file itself carries.
  final Map<String, String> existing;

  /// Overrides saved by the user for this photo.
  final Map<String, String> manual;

  /// Only build these fields; defaults to all of them.
  final List<String>? keys;

  /// Tighter spacing for use inside a narrow panel.
  final bool compact;

  /// Called with the new text; an empty string means "no override".
  final void Function(String key, String value) onChanged;
  const PhotoInfoForm(
      {super.key,
      required this.existing,
      required this.manual,
      required this.onChanged,
      this.keys,
      this.compact = false});
  @override
  State<PhotoInfoForm> createState() => _PhotoInfoFormState();
}

class _PhotoInfoFormState extends State<PhotoInfoForm> {
  final controllers = <String, TextEditingController>{};
  bool overwrite = false;

  List<String> get keys => widget.keys ?? infoFields.keys.toList();

  static const groups = [
    ('设备', 'camera', ['camera', 'lens']),
    ('曝光参数', 'params', ['focal', 'aperture', 'shutter', 'iso']),
    ('时间与地点', 'time', ['time', 'place'])
  ];

  @override
  void initState() {
    super.initState();
    for (final key in keys) {
      controllers[key] = TextEditingController(text: _initial(key));
    }
  }

  /// What the box shows when nothing has been typed yet: the saved override
  /// first, then what the file carries.
  String _initial(String key) =>
      (widget.manual[key] ?? '').isNotEmpty
          ? widget.manual[key]!
          : (widget.existing[key] ?? '');

  bool _hasExisting(String key) =>
      (widget.existing[key] ?? '').trim().isNotEmpty;

  bool _editable(String key) => overwrite || !_hasExisting(key);

  @override
  void didUpdateWidget(covariant PhotoInfoForm old) {
    super.didUpdateWidget(old);
    // Another photo is shown: refill the boxes from that photo.
    if (widget.existing != old.existing || widget.manual != old.manual) {
      for (final key in keys) {
        controllers.putIfAbsent(key, () => TextEditingController())
            .text = _initial(key);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setOverwrite(bool value) {
    setState(() {
      overwrite = value;
      for (final key in keys) {
        if (!_hasExisting(key)) continue;
        final controller = controllers[key]!;
        if (value) {
          controller.text = _initial(key);
        } else {
          // Protect what the file carries again; any override is dropped.
          controller.text = widget.existing[key] ?? '';
          widget.onChanged(key, '');
        }
      }
    });
  }

  /// A card holding one value. Locked, empty or editable are three different
  /// looks, so it is always obvious what can be typed into.
  Widget _card(String key) {
    final scheme = Theme.of(context).colorScheme;
    final editable = _editable(key);
    final controller = controllers[key]!;
    final text = controller.text.trim();
    final locked = !editable;
    final missing = text.isEmpty;
    final problem = text.isEmpty ? null : validateInfo(key, text);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
          decoration: BoxDecoration(
              color: locked
                  ? scheme.surfaceContainerHighest.withValues(alpha: .55)
                  : Theme.of(context).inputDecorationTheme.fillColor,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                  color: editable && missing
                      ? scheme.primary.withValues(alpha: .45)
                      : Colors.transparent)),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Text(infoFields[key]!,
                      style: dialogBodyStyle.copyWith(
                          fontSize: 11.5,
                          color: EditorTypography.dimOn(context))),
                  const Spacer(),
                  if (locked)
                    Icon(Icons.lock_outline,
                        size: 11,
                        color: scheme.onSurface.withValues(alpha: .34))
                ]),
                const SizedBox(height: 6),
                if (locked)
                  Text(missing ? '照片没有这项信息' : _pretty(key, text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dialogBodyStyle.copyWith(
                          fontSize: 14,
                          color: scheme.onSurface.withValues(alpha: .72)))
                else
                  TextField(
                      key: ValueKey('photo-info-$key'),
                      controller: controller,
                      style: dialogBodyStyle.copyWith(fontSize: 14),
                      decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 2),
                          hintText: '缺失，可在这里补上',
                          hintStyle: dialogBodyStyle.copyWith(
                              fontSize: 13.5,
                              color: scheme.primary.withValues(alpha: .72))),
                      onChanged: (value) => widget.onChanged(key, value))
              ])),
      // Validation is shown in both states: some photos carry a malformed
      // value in the file itself, and that is worth knowing before exporting.
      if (problem != null)
        Padding(
            padding: const EdgeInsets.only(top: 5, left: 2),
            child: Row(children: [
              Icon(Icons.error_outline, size: 12, color: scheme.error),
              const SizedBox(width: 4),
              Expanded(
                  child: Text('信息格式错误或无效',
                      style: dialogBodyStyle.copyWith(
                          fontSize: 11.5, color: scheme.error)))
            ]))
    ]);
  }

  /// Small units so the value reads naturally, matching how it looked before.
  String _pretty(String key, String text) {
    final number = double.tryParse(text);
    final short = number != null && number == number.roundToDouble()
        ? number.toInt().toString()
        : text;
    return switch (key) {
      'focal' => '$short mm',
      'aperture' => 'f/$short',
      'shutter' => '$text s',
      'time' => text.replaceFirstMapped(
          RegExp(r'^(\d{4}):(\d{2}):(\d{2})'),
          (m) => '${m[1]}-${m[2]}-${m[3]}'),
      _ => text
    };
  }

  Widget _row(List<String> pair) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _card(pair[0])),
        const SizedBox(width: 10),
        Expanded(child: _card(pair[1]))
      ]);

  Widget _heading(String title, String icon) => Padding(
      padding: EdgeInsets.only(top: widget.compact ? 16 : 22, bottom: 9),
      child: Row(children: [
        PrototypeIcon(icon, size: 16),
        const SizedBox(width: 8),
        Text(title, style: EditorTypography.title(context))
      ]));

  Widget _switchRow() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
        padding: const EdgeInsets.fromLTRB(13, 9, 9, 9),
        decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(7)),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('覆盖已有数据',
                    style: dialogBodyStyle.copyWith(fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                    overwrite
                        ? '所有项都可以修改，保存后会覆盖照片原有的值'
                        : '照片已有的项锁定不可改；缺的项可以直接填',
                    style: dialogBodyStyle.copyWith(
                        fontSize: 11.5,
                        color: Theme.of(context).hintColor))
              ])),
          const SizedBox(width: 14),
          Transform.scale(
              scale: .72,
              child: Switch(
                  value: overwrite,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: _setOverwrite))
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final available = keys.toSet();
    final hasAnyExisting = keys.any(_hasExisting);
    final widgets = <Widget>[];
    for (final (title, icon, groupKeys) in groups) {
      final present = [
        for (final key in groupKeys)
          if (available.contains(key)) key
      ];
      if (present.isEmpty) continue;
      widgets.add(_heading(title, icon));
      // Two short values per row; long ones and singles take the full width.
      const pairs = [
        ['focal', 'aperture'],
        ['shutter', 'iso']
      ];
      final done = <String>{};
      for (final pair in pairs) {
        if (present.contains(pair[0]) && present.contains(pair[1])) {
          widgets.add(_row(pair));
          widgets.add(const SizedBox(height: 10));
          done.addAll(pair);
        }
      }
      for (final key in present) {
        if (done.contains(key)) continue;
        widgets.add(_card(key));
        widgets.add(const SizedBox(height: 10));
      }
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasAnyExisting) ...[
            _switchRow(),
            SizedBox(height: widget.compact ? 2 : 6)
          ],
          ...widgets,
          Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('只保存在软件内，不会改动照片文件。',
                  style: dialogBodyStyle.copyWith(
                      fontSize: 11.5,
                      color: Theme.of(context).hintColor)))
        ]);
  }
}
