part of 'preset_panel.dart';

extension PresetActions on _PresetPanelState {
  Future<void> run(Future<void> Function() action) async {
    if (!usable) return;
    update(() {
      working = true;
      message = '';
    });
    try {
      await action();
    } catch (e) {
      if (mounted) update(() => message = '操作失败：$e');
    } finally {
      if (mounted) update(() => working = false);
    }
  }

  Future<String?> textPrompt(String title, String initial,
      {int maxLength = 200}) async {
    final input = TextEditingController(text: initial);
    String? error;
    final result = await showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => WorkspaceDialog(
                    title: Text(title),
                    content: SizedBox(
                        width: 350,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              WorkspaceTextField(
                                  label: '名称',
                                  controller: input,
                                  error: error,
                                  maxLength: maxLength,
                                  autofocus: true)
                            ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () {
                            final name = input.text.trim();
                            if (name.isEmpty) {
                              set(() => error = '请输入名称');
                              return;
                            }
                            Navigator.pop(ctx, name);
                          },
                          child: const Text('确定'))
                    ])));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      input.dispose();
    });
    return result;
  }

  Future<String?> chooseFolder(String title) async {
    var folder = store.libraryFolder == 'all' ? '' : store.libraryFolder;
    return showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => WorkspaceDialog(
                    title: Text(title),
                    content: SizedBox(
                        width: 320,
                        child: FolderSelect(
                            store: store,
                            value: folder,
                            onChanged: (v) => set(() => folder = v))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, folder),
                          child: const Text('移动'))
                    ])));
  }

  Future<void> persist(
      List<UserPreset> presets, List<PresetFolder> folders) async {
    await store.saveLibrary(presets, folders);
    if (!mounted) return;
    update(() {
      if (store.libraryFolder != 'all' &&
          store.libraryFolder.isNotEmpty &&
          !folders.any((f) => f.id == store.libraryFolder))
        store.libraryFolder = 'all';
      final valid = store.entries.map((e) => e.id).toSet();
      store.selection.ids.removeWhere((id) => !valid.contains(id));
    });
  }

  void toggleFavorite(PresetEntry e) {
    if (!usable) return;
    final f = widget.settings.favorites;
    if (!f.add(e.id)) f.remove(e.id);
    widget.settings.changed();
  }

  Future<void> rename(PresetEntry entry) => run(() async {
        final name = await textPrompt('重命名预设', entry.style.name);
        if (!mounted || name == null || name == entry.style.name) return;
        if (store.presets
            .any((p) => p.style.name == name && 'user:${p.id}' != entry.id))
          throw const FormatException('名称已存在');
        final next = [
          for (final p in store.presets)
            'user:${p.id}' == entry.id
                ? UserPreset(p.id, p.style.copy()..name = name,
                    folder: p.folder)
                : p
        ];
        await persist(next, store.folders);
      });
  Future<void> copySelected() => run(() async {
        final chosen = selected, next = [...store.presets], ids = <String>{};
        for (final e in chosen) {
          final name = uniquePresetName(
              '${e.style.name} 副本', next.map((p) => p.style.name));
          final id = newObjectId();
          ids.add('user:$id');
          next.add(
              UserPreset(id, e.style.copy()..name = name, folder: e.folder));
        }
        await persist(next, store.folders);
        if (mounted)
          update(() {
            store.selection.ids
              ..clear()
              ..addAll(ids);
            message = '已复制 ${chosen.length} 个预设';
          });
      });
  Future<void> moveSelected() => run(() async {
        if (selected.any((e) => e.builtIn)) return;
        final ids = {...store.selection.ids},
            folder = await chooseFolder('移动 ${selected.length} 个预设');
        if (folder == null || !mounted) return;
        await persist([
          for (final p in store.presets)
            ids.contains('user:${p.id}')
                ? UserPreset(p.id, p.style, folder: folder)
                : p
        ], store.folders);
        if (mounted) update(store.selection.clear);
      });
  Future<void> deleteSelected() => run(() async {
        final chosen = selected;
        if (chosen.any((e) => e.builtIn)) return;
        final yes = await showDialog<bool>(
            context: context,
            builder: (ctx) => WorkspaceDialog(
                    title: Text('删除 ${chosen.length} 个预设？'),
                    content: SizedBox(
                        width: 350,
                        child: SingleChildScrollView(
                            child: Text(
                                '${chosen.map((e) => e.style.name).join('\n')}\n\n已应用到照片的效果会保留。'))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('删除'))
                    ]));
        if (yes != true || !mounted) return;
        final ids = chosen.map((e) => e.id).toSet();
        await persist(
            store.presets.where((p) => !ids.contains('user:${p.id}')).toList(),
            store.folders);
        widget.settings.favorites.removeAll(ids);
        widget.settings.changed();
        if (mounted) update(store.selection.clear);
      });
  Future<void> newFolder() => run(() async {
        await createPresetFolder(context, store);
      });
  Future<void> renameFolder(PresetFolder folder) => run(() async {
        final name = await textPrompt('重命名分组', folder.name, maxLength: 100);
        if (name == null || !mounted) return;
        if (store.folders.any((f) => f.id != folder.id && f.name == name))
          throw const FormatException('分组名称已存在');
        await persist(store.presets, [
          for (final f in store.folders)
            f.id == folder.id ? PresetFolder(f.id, name) : f
        ]);
      });
  Future<void> manageFolders() async {
    if (!usable) return;
    await showDialog<void>(
        context: context,
        builder: (ctx) => FolderManager(
            store: store,
            preview: preview,
            onRename: renameFolder,
            onDelete: deleteFolder,
            onExport: exportEntries));
  }

  Future<void> deleteFolder(PresetFolder folder) => run(() async {
        var removeContents = false;
        final count = store.presets.where((p) => p.folder == folder.id).length;
        final yes = await showDialog<bool>(
            context: context,
            builder: (ctx) => StatefulBuilder(
                builder: (ctx, set) => WorkspaceDialog(
                        title: Text('删除分组“${folder.name}”？'),
                        content: SizedBox(
                          width: 380,
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('其中有 $count 个预设'),
                                const SizedBox(height: 12),
                                RadioGroup<bool>(
                                    groupValue: removeContents,
                                    onChanged: (v) =>
                                        set(() => removeContents = v!),
                                    child: Column(children: [
                                      const RadioListTile<bool>(
                                          value: false,
                                          title: Text('保留预设，移至未分组'),
                                          contentPadding: EdgeInsets.zero),
                                      RadioListTile<bool>(
                                          value: true,
                                          title: Text('同时删除其中全部 $count 个预设'),
                                          contentPadding: EdgeInsets.zero),
                                    ]))
                              ]),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('取消')),
                          FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('删除'))
                        ])));
        if (yes != true || !mounted) return;
        final removed = {
          for (final p in store.presets)
            if (p.folder == folder.id) 'user:${p.id}'
        };
        await store.deleteFolder(folder.id, deleteContents: removeContents);
        if (removeContents) {
          widget.settings.favorites.removeAll(removed);
          widget.settings.changed();
        }
        if (mounted) update(store.selection.clear);
      });
  Future<void> exportEntries(List<PresetEntry> chosen) => run(() async {
        if (chosen.isEmpty) throw const FormatException('没有可导出的预设');
        final shares = [
          for (final e in chosen)
            SharedPreset(e.style,
                folder: store.folders
                        .where((f) => f.id == e.folder)
                        .map((f) => f.name)
                        .firstOrNull ??
                    '')
        ];
        final name = chosen.length == 1 ? chosen.first.style.name : '预设合集';
        final location = await getSaveLocation(
            suggestedName:
                '${name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.lmp',
            acceptedTypeGroups: [
              const XTypeGroup(label: 'LumaCraft 预设', extensions: ['lmp'])
            ]);
        if (location == null) return;
        final path = location.path.toLowerCase().endsWith('.lmp')
            ? location.path
            : '${location.path}.lmp';
        final data = await compute(encodeLmp, shares);
        await File(path).writeAsString(data, flush: true);
        if (mounted) update(() => message = '已导出 ${chosen.length} 个预设');
      });
  Future<void> importPresets() => run(() async {
        final file = await openFile(acceptedTypeGroups: [
          const XTypeGroup(label: 'LumaCraft 预设', extensions: ['lmp'])
        ]);
        if (file == null) return;
        final incoming = await readLmp(File(file.path));
        if (!mounted) return;
        final choices = <int, String>{};
        final taken = store.presets.map((p) => p.style.name).toSet(),
            conflicts = <int>{};
        for (var i = 0; i < incoming.length; i++) {
          if (!taken.add(incoming[i].style.name)) conflicts.add(i);
        }
        final yes = await showDialog<bool>(
            context: context,
            builder: (ctx) => StatefulBuilder(
                builder: (ctx, set) => WorkspaceDialog(
                        title: Text('导入 ${incoming.length} 个预设'),
                        content: SizedBox(
                            width: 560,
                            height: 390,
                            child: ListView.builder(
                                itemCount: incoming.length,
                                itemBuilder: (ctx, i) {
                                  final p = incoming[i];
                                  return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 14),
                                      child: Row(children: [
                                        SizedBox(
                                            width: 110,
                                            height: 85,
                                            child: PresetThumbnail(
                                                style: p.style,
                                                child: preview(PresetEntry(
                                                    'import:$i', p.style)))),
                                        const SizedBox(width: 15),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                              Text(p.style.name,
                                                  style: EditorTypography.title(
                                                      ctx)),
                                              const SizedBox(height: 5),
                                              Text(
                                                  p.folder.isEmpty
                                                      ? '未分组'
                                                      : p.folder,
                                                  style: EditorTypography.hint(
                                                      ctx)),
                                              if (conflicts.contains(i)) ...[
                                                const SizedBox(height: 9),
                                                PrototypeSelect(
                                                    value: choices[i] ?? 'copy',
                                                    options: const {
                                                      'copy': '保留两份',
                                                      'replace': '覆盖同名预设',
                                                      'skip': '跳过'
                                                    },
                                                    onChanged: (v) => set(
                                                        () => choices[i] = v))
                                              ]
                                            ]))
                                      ]));
                                })),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('取消')),
                          FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('导入'))
                        ])));
        previews.removeWhere((id, _) => id.startsWith('import:'));
        if (yes != true || !mounted) return;
        final result = mergeLmp(store, incoming, choices);
        await persist(result.presets, result.folders);
        if (mounted) update(() => message = '已导入 ${result.count} 个预设');
      });
  Future<String?> menu(Offset p, Map<String, String> items) => showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(p.dx, p.dy, 0, 0),
          popUpAnimationStyle: AnimationStyle.noAnimation,
          color: Theme.of(context).colorScheme.surface,
          elevation: 12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          items: [
            for (final e in items.entries)
              PopupMenuItem(
                  value: e.key,
                  height: 38,
                  child: Text(e.value, style: const TextStyle(fontSize: 13)))
          ]);
  Future<void> topMenu() async {
    final box = context.findRenderObject() as RenderBox;
    final action =
        await menu(box.localToGlobal(Offset(box.size.width - 10, 35)), {
      if (widget.onNew != null) 'new': '新建空白样式',
      'import': '导入预设',
      'export': store.libraryFolder == 'all' ? '导出全部预设' : '导出当前分组',
      'folder': '新建分组',
      'manage': '管理分组',
      if (store.authoring && widget.onEditBuiltin != null) 'builtins': '内置预设维护'
    });
    if (!mounted) return;
    if (action == 'new') widget.onNew?.call();
    if (action == 'import') await importPresets();
    if (action == 'export')
      await exportEntries(store.entries
          .where((e) =>
              store.libraryFolder == 'all' ||
              !e.builtIn && e.folder == store.libraryFolder)
          .toList());
    if (action == 'folder') await newFolder();
    if (action == 'manage') await manageFolders();
    if (action == 'builtins') await manageBuiltins();
  }

  Future<void> manageBuiltins() async {
    if (!store.authoring || widget.onEditBuiltin == null) return;
    final id = await showDialog<String>(
        context: context,
        builder: (_) => BuiltinManager(store: store, preview: preview));
    if (!mounted || id == null) return;
    final entry =
        store.entries.where((e) => e.builtIn && e.id == id).firstOrNull;
    if (entry != null) await widget.onEditBuiltin!(entry);
  }

  Future<void> cardMenu(PresetEntry e, Offset p) async {
    if (!usable) return;
    focus.requestFocus();
    if (!store.selection.ids.contains(e.id))
      update(() {
        store.selection.ids
          ..clear()
          ..add(e.id);
        store.selection.anchor = e.id;
      });
    final list = selected, editable = list.every((e) => !e.builtIn);
    final action = await menu(p, {
      if (list.length == 1 && editable) 'rename': '重命名',
      'copy': '复制',
      if (editable) 'move': '移动至分组',
      'export': '导出 .lmp',
      if (editable) 'delete': '删除'
    });
    if (!mounted) return;
    if (action == 'rename') await rename(list.single);
    if (action == 'copy') await copySelected();
    if (action == 'move') await moveSelected();
    if (action == 'export') await exportEntries(list);
    if (action == 'delete') await deleteSelected();
  }
}
