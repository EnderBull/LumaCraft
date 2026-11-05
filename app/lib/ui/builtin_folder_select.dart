import 'package:flutter/material.dart';
import '../editor/builtin_library.dart';
import '../editor/preset_store.dart';
import '../editor/style_document.dart';
import 'editor/prototype_controls.dart';
import 'workspace_dialog.dart';

Future<String?> createBuiltinFolder(
    BuildContext context, PresetStore store) async {
  final input = TextEditingController();
  String? error;
  bool busy = false;
  final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => WorkspaceDialog(
                  title: const Text('新建内置分组'),
                  content: SizedBox(
                      width: 350,
                      child: WorkspaceTextField(
                          label: '分组名称',
                          controller: input,
                          error: error,
                          maxLength: 100,
                          autofocus: true)),
                  actions: [
                    TextButton(
                        onPressed: busy ? null : () => Navigator.pop(ctx),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final name = input.text.trim();
                                if (name.isEmpty ||
                                    store.builtinLibrary.folders
                                        .any((f) => f.name == name) ||
                                    ['全部分组', '未分组'].contains(name)) {
                                  set(() => error = '请输入不重复的分组名称');
                                  return;
                                }
                                set(() => busy = true);
                                try {
                                  final id = 'g-${newObjectId()}';
                                  await store.writeBuiltinLibrary(
                                      BuiltinLibrary([
                                    ...store.builtinLibrary.folders,
                                    BuiltinFolder(id, name)
                                  ], store.builtinLibrary.entries));
                                  if (ctx.mounted) Navigator.pop(ctx, id);
                                } catch (e) {
                                  if (ctx.mounted)
                                    set(() {
                                      busy = false;
                                      error = '创建失败：$e';
                                    });
                                }
                              },
                        child: const Text('确定'))
                  ])));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    input.dispose();
  });
  return result;
}

class BuiltinFolderSelect extends StatelessWidget {
  final PresetStore store;
  final String value;
  final ValueChanged<String> onChanged;
  final bool includeAll;
  const BuiltinFolderSelect(
      {super.key,
      required this.store,
      required this.value,
      required this.onChanged,
      this.includeAll = false});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: store,
      builder: (context, _) => PrototypeSelect(
          value: value,
          options: {
            if (includeAll) 'all': '全部分组',
            for (final f in store.builtinLibrary.folders) f.id: f.name,
            '__new__': '＋ 新建分组'
          },
          onChanged: (v) async {
            if (v != '__new__') {
              onChanged(v);
              return;
            }
            final id = await createBuiltinFolder(context, store);
            if (context.mounted && id != null) onChanged(id);
          }));
}
