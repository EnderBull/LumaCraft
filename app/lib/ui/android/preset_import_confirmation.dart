import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'preset_demo_preview.dart';
import '../../editor/preset_package.dart';
import '../../editor/style_render.dart';

Future<bool> confirmMobilePresetImport(
    BuildContext context, List<SharedPreset> presets) async {
  if (presets.isEmpty) return false;
  return await showDialog<bool>(
        context: context,
        builder: (_) => _ImportConfirmation(presets),
      ) ==
      true;
}

class _ImportConfirmation extends StatefulWidget {
  const _ImportConfirmation(this.presets);
  final List<SharedPreset> presets;

  @override
  State<_ImportConfirmation> createState() => _ImportConfirmationState();
}

class _ImportConfirmationState extends State<_ImportConfirmation> {
  ui.Image? _photo;
  late final _preview = loadPresetDemoLandscape().then((photo) {
    if (mounted) {
      _photo = photo;
    } else {
      photo.dispose();
    }
    return photo;
  });

  @override
  void dispose() {
    _photo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.presets.length;
    return AlertDialog(
      title: Text(count == 1 ? '导入预设？' : '导入预设 · ' + count.toString() + ' 个'),
      content: SizedBox(
        width: 420,
        height: math.min(
            count == 1 ? 232 : 430, MediaQuery.sizeOf(context).height * .52),
        child: FutureBuilder<ui.Image>(
          future: _preview,
          builder: (context, snapshot) => ListView.separated(
            primary: false,
            itemCount: count,
            separatorBuilder: (_, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final style = widget.presets[index].style;
              final photo = snapshot.data;
              final colors = Theme.of(context).colorScheme;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(style.name,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 190,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: photo != null
                            ? RepaintBoundary(
                                child: StylePreview(
                                    photo: photo,
                                    document: style,
                                    fields: presetDemoFields))
                            : Center(
                                child: snapshot.hasError
                                    ? const Text('示意预览暂不可用')
                                    : const CircularProgressIndicator(
                                        strokeWidth: 2)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认导入')),
      ],
    );
  }
}
