import 'package:flutter/material.dart';
import '../../export/export_options.dart';
import '../workspace_dialog.dart';
import '../editor/prototype_controls.dart';

class ExportConflictDialog extends StatelessWidget {
  final List<String> filenames;
  final ValueChanged<ExportConflictChoice> onChoose;
  final bool canReplace;
  const ExportConflictDialog(
      {super.key,
      required this.filenames,
      required this.onChoose,
      this.canReplace = true});

  /// Pale red for "keep all": it is the least destructive option here, and a
  /// soft tint keeps it distinct from the accent-coloured actions without
  /// looking like a warning.
  static Color keepAllColor(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? const Color(0xff5c3a36)
          : const Color(0xfff3dcd8);

  static Color keepAllInk(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? const Color(0xfff6ddd8)
          : const Color(0xff7a4038);
  @override
  Widget build(BuildContext context) => Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: DefaultTextStyle(
          style: dialogBodyStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurface),
          child: SizedBox(
              width: 660,
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          const Expanded(
                              child: Text('发现重名文件', style: dialogTitleStyle)),
                          IconButton(
                              tooltip: '取消导出',
                              onPressed: () =>
                                  onChoose(ExportConflictChoice.cancel),
                              icon: const Icon(Icons.close_rounded, size: 20))
                        ]),
                        const SizedBox(height: 12),
                        Text('输出目录中已有 ${filenames.length} 个同名文件。请选择处理方式后继续。'),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 132),
                            child: SingleChildScrollView(
                                child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .inputDecorationTheme
                                            .fillColor,
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (final name in filenames)
                                            Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 3),
                                                child: Text(name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 13)))
                                        ])))),
                        const SizedBox(height: 12),
                        Text(
                            canReplace
                                ? '添加编号会保留全部文件；替换会覆盖输出目录中的同名文件。'
                                : '本批次多张照片生成了相同名称，请添加编号全部保留，或取消后修改模板。',
                            style: EditorTypography.hint(context)
                                .copyWith(fontSize: 12, height: 1.6)),
                        const SizedBox(height: 22),
                        Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 9,
                            runSpacing: 9,
                            children: [
                              SizedBox(
                                  width: 112,
                                  height: 40,
                                  child: WorkspaceActionButton(
                                      label: '取消导出',
                                      onPressed: () => onChoose(
                                          ExportConflictChoice.cancel))),
                              SizedBox(
                                  width: 112,
                                  height: 40,
                                  child: FilledButton(
                                      onPressed: () => onChoose(
                                          ExportConflictChoice.skipExisting),
                                      style: FilledButton.styleFrom(
                                          textStyle: dialogActionStyle,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6))),
                                      child: const Text('跳过同名'))),
                              SizedBox(
                                  width: 112,
                                  height: 40,
                                  child: FilledButton(
                                      onPressed: !canReplace
                                          ? null
                                          : () => onChoose(
                                              ExportConflictChoice.replace),
                                      style: FilledButton.styleFrom(
                                          textStyle: dialogActionStyle,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6))),
                                      child: const Text('替换保存'))),
                              SizedBox(
                                  width: 112,
                                  height: 40,
                                  child: FilledButton(
                                      onPressed: () => onChoose(
                                          ExportConflictChoice.keepAll),
                                      style: FilledButton.styleFrom(
                                          textStyle: dialogActionStyle,
                                          backgroundColor:
                                              ExportConflictDialog.keepAllColor(
                                                  Theme.of(context)),
                                          foregroundColor: ExportConflictDialog
                                              .keepAllInk(Theme.of(context)),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6))),
                                      child: const Text('全部保留')))
                            ])
                      ])))));
}
