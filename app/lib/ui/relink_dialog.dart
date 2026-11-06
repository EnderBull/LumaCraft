import 'dart:async';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../photo_relink.dart';
import '../photo_state.dart';
import 'workspace_dialog.dart';
import 'photo_thumb.dart';

/// Manual relinking for the records that could not be matched automatically.
///
/// Left column: records whose photo is gone. Right column: photos in the
/// folder that no record points at. Pick one of each, then link.
Future<int> showRelinkDialog(
  BuildContext context, {
  required List<PendingRecord> pending,
  required List<File> available,
  required String folderLabel,
  required bool Function(String oldPath, String newPath) onLink,
  required Future<void> Function() onDone,
}) async {
  final linked = await showDialog<int>(
      context: context,
      // Same as every other panel here: clicking outside closes it.
      barrierDismissible: true,
      builder: (ctx) => _RelinkDialog(
          pending: pending,
          available: available,
          folderLabel: folderLabel,
          onLink: onLink,
          onDone: onDone));
  return linked ?? 0;
}

class _RelinkDialog extends StatefulWidget {
  final List<PendingRecord> pending;
  final List<File> available;
  final String folderLabel;
  final bool Function(String oldPath, String newPath) onLink;
  final Future<void> Function() onDone;
  const _RelinkDialog(
      {required this.pending,
      required this.available,
      required this.folderLabel,
      required this.onLink,
      required this.onDone});
  @override
  State<_RelinkDialog> createState() => _RelinkDialogState();
}

class _RelinkDialogState extends State<_RelinkDialog> {
  late final records = List<PendingRecord>.of(widget.pending);
  late final candidates = List<File>.of(widget.available);
  final times = <String, String>{};

  /// Files the user picked by hand. They may live in another folder and may
  /// have been renamed, so the name/time rules do not apply to them.
  final picked = <File>[];

  /// Pairs the app proposes for the hand-picked photos. Each one still needs
  /// the user's confirmation before anything is written.
  final suggested = <(PendingRecord, String)>[];
  String? selectedRecord, selectedFile;
  String? message;
  bool linking = false;
  int done = 0;

  @override
  void initState() {
    super.initState();
    for (final record in records) {
      if ((record.captureTime ?? '').isNotEmpty) continue;
      _readTime(record);
    }
  }

  /// Old records saved before capture times were stored still get a chance.
  Future<void> _readTime(PendingRecord record) async {
    if (!await File(record.oldPath).exists()) return;
    try {
      final info = await compute(readCapture, record.oldPath);
      final time = (info['time'] ?? '').trim();
      if (time.isEmpty || !mounted) return;
      setState(() {
        final i = records.indexWhere((r) => r.oldPath == record.oldPath);
        if (i < 0) return;
        records[i] = PendingRecord(record.oldPath, record.fileName, time,
            edited: record.edited);
      });
    } catch (_) {}
  }

  Future<String> _fileTime(File file) async {
    final known = times[file.path];
    if (known != null) return known;
    String time = '';
    try {
      final info = await compute(readCapture, file.path);
      time = (info['time'] ?? '').trim();
    } catch (_) {}
    times[file.path] = time;
    return time;
  }

  /// Adds one or more photos chosen from anywhere on disk. A renamed photo is
  /// exactly the case that automatic matching cannot handle, so the user gets
  /// the final say here.
  Future<void> _pickFiles() async {
    final chosen = await openFiles(acceptedTypeGroups: [
      const XTypeGroup(label: '照片', extensions: [
        'jpg',
        'jpeg',
        'heic',
        'heif',
        'hif'
      ])
    ]);
    if (chosen.isEmpty || !mounted) return;
    setState(() {
      for (final file in chosen) {
        final already = picked.any((f) => f.path == file.path) ||
            candidates.any((f) => f.path == file.path);
        if (!already) picked.add(File(file.path));
      }
      final fresh = chosen.first;
      if (selectedFile == null) selectedFile = fresh.path;
      message = null;
    });
    // Read the new files' times, then propose the obvious pairs. A photo
    // whose time matches exactly one record is almost certainly that record,
    // but nothing is written until the user confirms.
    final read = <String, String>{};
    for (final file in List<File>.of(picked)) {
      read[file.path] = await _fileTime(file);
    }
    if (!mounted) return;
    final open = records
        .where((r) => !suggested.any((p) => p.$1.oldPath == r.oldPath))
        .toList();
    final free = <String, String>{};
    for (final file in picked) {
      if (suggested.any((p) => p.$2 == file.path)) continue;
      free[file.path] = read[file.path] ?? '';
    }
    final fresh2 = suggestPairs(records: open, timesByPath: free);
    if (fresh2.isEmpty || !mounted) return;
    setState(() {
      suggested.addAll(fresh2);
      message = '有 ${fresh2.length} 对拍摄时间完全相同，已自动配好，确认后接回';
    });
  }

  /// Applies every proposed pair the user has not removed.
  Future<void> _confirmSuggested() async {
    if (suggested.isEmpty || linking) return;
    setState(() {
      linking = true;
      message = null;
    });
    var applied = 0;
    for (final pair in List.of(suggested)) {
      final record = pair.$1, path = pair.$2;
      if (!widget.onLink(record.oldPath, path)) continue;
      applied++;
      if (!mounted) return;
      setState(() {
        records.removeWhere((r) => r.oldPath == record.oldPath);
        candidates.removeWhere((f) => f.path == path);
        picked.removeWhere((f) => f.path == path);
        suggested.removeWhere((p) => p.$1.oldPath == record.oldPath);
        times[path] = record.captureTime ?? '';
      });
    }
    await widget.onDone();
    if (!mounted) return;
    setState(() {
      linking = false;
      if (applied > 0) done += applied;
      message = applied == 0
          ? '这些照片都已有自己的记录，未覆盖'
          : '已接回 $applied 张，还剩 ${records.length} 张需要手动选择';
    });
  }

  Future<void> _link() async {
    PendingRecord? found;
    for (final r in records) {
      if (r.oldPath == selectedRecord) found = r;
    }
    File? target;
    for (final f in [...candidates, ...picked]) {
      if (f.path == selectedFile) target = f;
    }
    if (found == null || target == null) return;
    final record = found, file = target;
    final manual = picked.any((f) => f.path == file.path);
    setState(() {
      linking = true;
      message = null;
    });
    // Only a photo picked for this record gets the time check waived.
    if (!manual) {
      final time = await _fileTime(file);
      if (!mounted) return;
      if (time.isEmpty) {
        setState(() {
          linking = false;
          message = '这张照片读不出拍摄时间，无法确认是不是同一张，换一张试试';
        });
        return;
      }
      if (record.captureTime != null && record.captureTime!.isNotEmpty &&
          time != record.captureTime) {
        setState(() {
          linking = false;
          message = '拍摄时间和原记录不同（原 ${record.captureTime}），为免接错已停止'
              '。如果确认是同一张，请用“选择其他文件…”手动指定';
        });
        return;
      }
    }
    final accepted = widget.onLink(record.oldPath, file.path);
    await widget.onDone();
    if (!mounted) return;
    setState(() {
      linking = false;
      if (!accepted) {
        message = '这张照片已有自己的记录，未覆盖';
        return;
      }
      records.removeWhere((r) => r.oldPath == record.oldPath);
      candidates.removeWhere((f) => f.path == file.path);
      picked.removeWhere((f) => f.path == file.path);
      selectedRecord = null;
      selectedFile = null;
      done++;
      message = manual ? '已手动关联 1 张' : '已关联 1 张';
      if (done > 1) message = manual ? '已手动关联 $done 张' : '已关联 $done 张';
    });
  }

  @override
  Widget build(BuildContext context) {
    final canLink = selectedRecord != null && selectedFile != null && !linking;
    final waiting = records
        .where((r) => !suggested.any((p) => p.$1.oldPath == r.oldPath))
        .length;
    return WorkspaceDialog(
        title: Text(waiting == records.length
            ? '重新关联照片（${records.length} 张待处理）'
            : '重新关联照片（手动 ${waiting} 张 · 已自动配对 ${suggested.length} 对）'),
        content: SizedBox(
            width: 780,
            height: 420,
            child: RelinkBody(
                pending: records,
                available: candidates,
                picked: picked,
                folderLabel: widget.folderLabel,
                selectedRecord: selectedRecord,
                selectedFile: selectedFile,
                message: message,
                onPickFiles: _pickFiles,
                suggested: suggested,
                onRemoveSuggestion: (oldPath) => setState(() {
                      suggested.removeWhere((p) => p.$1.oldPath == oldPath);
                      message = null;
                    }),
                onConfirmSuggested:
                    suggested.isEmpty || linking ? null : _confirmSuggested,
                onSelectRecord: (path) => setState(() {
                      selectedRecord = path;
                      message = null;
                    }),
                onSelectFile: (path) => setState(() {
                      selectedFile = path;
                      message = null;
                    }))),
        actions: [
          if (suggested.isNotEmpty)
            WorkspaceActionButton(
                label: linking ? '正在接回…' : '确认接回 ${suggested.length} 对',
                onPressed: linking ? null : _confirmSuggested),
          WorkspaceActionButton(
              label: '稍后处理',
              onPressed: linking ? null : () => Navigator.pop(context, done)),
          WorkspaceActionButton(
              label: linking ? '正在关联…' : '关联选中的两张',
              onPressed: canLink ? _link : null)
        ]);
  }
}

/// The two-column matching area. Kept separate from the dialog frame so it
/// can be rendered on its own for layout checks.
class RelinkBody extends StatelessWidget {
  final List<PendingRecord> pending;
  final List<File> available,
      picked;
  final String folderLabel;
  final String? selectedRecord, selectedFile, message;
  final ValueChanged<String>? onSelectRecord, onSelectFile;
  final VoidCallback? onPickFiles, onConfirmSuggested;
  final ValueChanged<String>? onRemoveSuggestion;
  final List<(PendingRecord, String)> suggested;
  const RelinkBody(
      {super.key,
      required this.pending,
      required this.available,
      this.picked = const [],
      this.suggested = const [],
      required this.folderLabel,
      this.selectedRecord,
      this.selectedFile,
      this.message,
      this.onSelectRecord,
      this.onSelectFile,
      this.onPickFiles,
      this.onConfirmSuggested,
      this.onRemoveSuggestion});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    Widget panel(String title, String hint, Widget child) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: dialogBodyStyle.copyWith(fontSize: 13)),
              const SizedBox(height: 2),
              Text(hint,
                  style: dialogBodyStyle.copyWith(
                      fontSize: 12, color: Theme.of(context).hintColor)),
              const SizedBox(height: 8),
              Expanded(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: dark
                              ? const Color(0xff1f1e1c)
                              : const Color(0xffece8e2),
                          borderRadius: BorderRadius.circular(6)),
                      child: child))
            ]);
    Widget empty(String text) => Center(
        child: Text(text,
            style: dialogBodyStyle.copyWith(
                fontSize: 12, color: Theme.of(context).hintColor)));
    // Anything already proposed for a pair stays out of the two columns, so
    // what is left there is exactly what still needs a manual pick.
    final waiting = pending
        .where((r) => !suggested.any((p) => p.$1.oldPath == r.oldPath))
        .toList();
    final paired = {
      for (final pair in suggested) pair.$2,
    };
    final freeFiles = [
      ...available.where((f) => !paired.contains(f.path)),
      ...picked.where((f) => !paired.contains(f.path))
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
          '这些照片搬了位置，原来的样式和信息还留在记录里。'
          '自动关联只在文件名和拍摄时间都相同时才接回。'
          '现在的位置：$folderLabel',
          style: dialogBodyStyle.copyWith(
              fontSize: 12, color: Theme.of(context).hintColor)),
      const SizedBox(height: 14),
      Expanded(
          child: Row(children: [
        Expanded(
            child: panel(
                waiting.isEmpty ? '找不到的照片' : '还需要手动配的记录 ${waiting.length} 条',
                waiting.isEmpty ? '点一行选中' : '已自动配好的在下方，这里只需处理剩下的',
                waiting.isEmpty
                    ? empty('已全部处理')
                    : RecordsList(
                        items: [
                          for (final r in waiting)
                            (
                              r.oldPath,
                              r.fileName,
                              r.captureTime ?? '',
                              r.edited
                            )
                        ],
                        selected: selectedRecord,
                        onTap: onSelectRecord ?? (_) {}))),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.arrow_forward, size: 16)),
        Expanded(
            child: panel(
                '可手动选的照片 ${freeFiles.length} 张',
                picked.isEmpty
                    ? '只列出还没有对上记录的照片'
                    : '另有 ${picked.length} 张手动选择',
                Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                          child: freeFiles.isEmpty
                              ? empty('还没有可手动选的照片，点下面的按钮挑')
                              : FilesList(
                                  files: freeFiles,
                                  selected: selectedFile,
                                  onTap: onSelectFile ?? (_) {})),
                      if (onPickFiles != null)
                        Padding(
                            padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                            child: WorkspaceActionButton(
                                label: '选择其他文件…',
                                onPressed: onPickFiles))
                    ])))
      ])),
      if (suggested.isNotEmpty) ...[
        const SizedBox(height: 12),
        Row(children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(4)),
              child: Text('已自动配对 ${suggested.length} 对 · 待确认',
                  style: dialogBodyStyle.copyWith(
                      fontSize: 12, color: scheme.primary))),
          const SizedBox(width: 8),
          Expanded(
              child: Text('拍摄时间完全相同才算一对；不对的点右侧叉号退回手动',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dialogBodyStyle.copyWith(
                      fontSize: 12, color: Theme.of(context).hintColor)))
        ]),
        const SizedBox(height: 6),
        SizedBox(
            height: 92,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xff1f1e1c)
                        : const Color(0xffece8e2),
                    borderRadius: BorderRadius.circular(6)),
                child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    itemCount: suggested.length,
                    itemBuilder: (context, i) {
                      final (record, path) = suggested[i];
                      final name = path.split(RegExp(r'[\\/]')).last;
                      return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            Icon(Icons.check_circle_outline,
                                size: 13, color: scheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                                flex: 4,
                                child: Text(record.fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        dialogBodyStyle.copyWith(fontSize: 12))),
                            const Icon(Icons.arrow_forward,
                                size: 12, color: Colors.grey),
                            Expanded(
                                flex: 5,
                                child: Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        dialogBodyStyle.copyWith(fontSize: 12))),
                            if (onRemoveSuggestion != null)
                              IconButton(
                                  tooltip: '不配这一对，退回手动选择',
                                  iconSize: 14,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      onRemoveSuggestion!(record.oldPath),
                                  icon: const Icon(Icons.close))
                          ]));
                    })))
      ],
      if (message != null)
        Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(message!,
                style: dialogBodyStyle.copyWith(
                    fontSize: 12, color: scheme.primary)))
    ]);
  }
}

class RecordsList extends StatelessWidget {
  final List<(String, String, String, bool)> items;
  final String? selected;
  final ValueChanged<String> onTap;
  const RecordsList(
      {super.key,
      required this.items,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) => ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final (path, name, time, edited) = items[i];
        final active = path == selected;
        return _RelinkRow(
            active: active,
            onTap: () => onTap(path),
            title: name,
            subtitle: [
              if (time.isNotEmpty) time,
              if (edited) '已编辑',
              if (time.isEmpty) '拍摄时间待读取'
            ].join(' · '));
      });
}

class FilesList extends StatefulWidget {
  final List<File> files;
  final String? selected;
  final ValueChanged<String> onTap;
  const FilesList(
      {super.key,
      required this.files,
      required this.selected,
      required this.onTap});
  @override
  State<FilesList> createState() => _FilesListState();
}

class _FilesListState extends State<FilesList> {
  final times = <String, String>{};
  @override
  void initState() {
    super.initState();
    for (final file in widget.files) {
      compute(readCapture, file.path).then((info) {
        if (!mounted) return;
        setState(() => times[file.path] = (info['time'] ?? '').trim());
      }).catchError((Object _) {});
    }
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: widget.files.length,
      itemBuilder: (context, i) {
        final file = widget.files[i];
        final active = file.path == widget.selected;
        return _RelinkRow(
            active: active,
            onTap: () => widget.onTap(file.path),
            title: file.uri.pathSegments.last,
            subtitle: times[file.path] ?? '正在读取拍摄时间…',
            leading: SizedBox(
                width: 34,
                height: 26,
                child: PhotoThumb(file)));
      });
}

class _RelinkRow extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final String title, subtitle;
  final Widget? leading;
  const _RelinkRow(
      {required this.active,
      required this.onTap,
      required this.title,
      required this.subtitle,
      this.leading});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => onTap(),
            child: Container(
                color: active
                    ? scheme.primary.withValues(alpha: .18)
                    : Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(children: [
                  if (leading != null) ...[
                    ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: leading!),
                    const SizedBox(width: 8)
                  ],
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: dialogBodyStyle.copyWith(fontSize: 13)),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: dialogBodyStyle.copyWith(
                                fontSize: 12,
                                color: Theme.of(context).hintColor))
                      ]))
                ]))));
  }
}
