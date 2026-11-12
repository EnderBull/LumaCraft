part of 'editor_page.dart';

extension EditorPanels on _PresetEditorState {
  Widget symbol(IconData icon, {double size = 18, Color? color}) {
    final layer = {
      Icons.folder_copy_outlined: 'groupAction',
      Icons.folder_off_outlined: 'ungroup',
      Icons.vertical_align_top: 'arrowUp',
      Icons.vertical_align_bottom: 'arrowDown',
      Icons.add_box_outlined: 'add',
      Icons.image_outlined: 'image',
      Icons.local_post_office_outlined: 'postmark',
      Icons.interests_outlined: 'material',
      Icons.save_outlined: 'savePreset'
    };
    final ui = {
      Icons.undo_rounded: 'undo',
      Icons.redo_rounded: 'redo',
      Icons.restart_alt: 'restore',
      Icons.add: 'plus',
      Icons.tune_rounded: 'sliders',
      Icons.swap_horiz: 'swap',
      Icons.content_copy_outlined: 'duplicate',
      Icons.delete_outline: 'trash',
      Icons.format_align_left: 'alignLeft',
      Icons.format_align_center: 'alignCenter',
      Icons.format_align_right: 'alignRight',
      Icons.align_horizontal_left: 'alignLeft',
      Icons.align_horizontal_center: 'alignCenter',
      Icons.align_horizontal_right: 'alignRight',
      Icons.align_vertical_top: 'arrowUp',
      Icons.align_vertical_center: 'params',
      Icons.align_vertical_bottom: 'arrowDown'
    };
    if (layer.containsKey(icon))
      return PrototypeIcon(layer[icon]!, size: size, color: color);
    if (ui.containsKey(icon))
      return PrototypeIcon(ui[icon]!, size: size, color: color, ui: true);
    return Icon(icon, size: size, color: color);
  }

  Widget action(IconData icon, String tip, VoidCallback? onTap) => IconButton(
      tooltip: tip,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      icon: Opacity(
          opacity: onTap == null ? .35 : 1, child: symbol(icon, size: 19)));
  Widget neutral(String text, VoidCallback? onTap,
          {IconData? icon}) =>
      TextButton.icon(
          style: TextButton.styleFrom(
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
          onPressed: onTap,
          icon: Opacity(
              opacity: onTap == null ? .35 : 1,
              child: symbol(icon ?? Icons.circle_outlined, size: 16)),
          label: Text(text, style: const TextStyle(fontSize: 12)));
  String componentSymbol(String type) => type == 'place' ? 'location' : type;
  Widget componentIcon(String id) => PrototypeIcon(
      c.doc.node(id) == null
          ? (c.collapsed.contains(id) ? 'group' : 'groupOpen')
          : componentSymbol(c.doc.node(id)!.type),
      size: 21);
  List<(String, int)> layerRows() {
    final rows = <(String, int)>[];
    void walk(List<String> list, int depth) {
      for (final id in list.reversed) {
        rows.add((id, depth));
        if (c.doc.group(id) != null && !c.collapsed.contains(id))
          walk(c.doc.children(id), depth + 1);
      }
    }

    walk(c.doc.order, 0);
    return rows;
  }

  Widget layersPanel() {
    final rows = layerRows();
    return Column(children: [
      PrototypeTabs(
          labels: const ['图层', '目录'],
          selected: directoryTab ? 1 : 0,
          onSelect: (i) => update(() => directoryTab = i == 1),
          trailing: directoryTab
              ? null
              : Builder(
                  builder: (button) => action(
                      Icons.add_box_outlined, '添加组件', () => addMenu(button)))),
      if (directoryTab)
        Expanded(child: directoryContents())
      else ...[
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(children: [
              const Text('画布组件', style: TextStyle(fontSize: 12)),
              const Spacer(),
              Text('${c.doc.nodes.length} 个组件',
                  style: const TextStyle(fontSize: 12))
            ])),
        Expanded(
            child: SmoothScroll(
                key: layerViewport,
                controller: layerScroll,
                child: Scrollbar(
                    controller: layerScroll,
                    child: ListView(
                        controller: layerScroll,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          for (final row in rows)
                            layerRow(
                                row.$1, row.$2, rows.map((r) => r.$1).toList()),
                          Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 30, 12, 12),
                              child: Text(
                                  '点选组件编辑属性\n拖动画布中的组件调整位置\nCtrl 多选 · Shift 连选\n画布空白处拖动框选',
                                  style: EditorTypography.hint(context)
                                      .copyWith(
                                          color: EditorTypography.muted(context)
                                              .withValues(alpha: .75))))
                        ])))),
        Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Text('已选 ${c.selection.length} 项',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: neutral('分组',
                        c.selection.length < 2 || c.protected ? null : c.group,
                        icon: Icons.folder_copy_outlined)),
                const SizedBox(width: 5),
                Expanded(
                    child: neutral(
                        '取消分组',
                        c.selection.any((id) => c.doc.group(id) != null) &&
                                !c.protected
                            ? c.ungroup
                            : null,
                        icon: Icons.folder_off_outlined))
              ]),
              const SizedBox(height: 7),
              Row(children: [
                Expanded(
                    child: neutral('上移', () => c.stepOrder(true),
                        icon: Icons.vertical_align_top)),
                const SizedBox(width: 5),
                Expanded(
                    child: neutral('下移', () => c.stepOrder(false),
                        icon: Icons.vertical_align_bottom))
              ])
            ]))
      ]
    ]);
  }

  Widget layerRow(String id, int depth, List<String> rows) {
    final n = c.doc.node(id),
        g = c.doc.group(id),
        scheme = Theme.of(context).colorScheme;
    var buttonDown = false;
    Widget layerButton(Widget child) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => buttonDown = true,
        child: child);
    Widget row = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          if (buttonDown) {
            buttonDown = false;
            return;
          }
          if (layerRenameId == id) return;
          FocusManager.instance.primaryFocus?.unfocus();
          if (ctrl || shift || !c.selection.contains(id))
            c.select(id, toggle: ctrl, range: shift, rows: rows);
          update(() => panel = 2);
        },
        child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: EdgeInsets.only(
                left: 5 + depth * 12.0, right: 3, top: 7, bottom: 7),
            decoration: BoxDecoration(
                color: c.selection.contains(id)
                    ? scheme.primary.withValues(alpha: .1)
                    : g != null
                        ? scheme.onSurface.withValues(alpha: .025)
                        : null,
                borderRadius: BorderRadius.circular(6),
                border: c.selection.contains(id)
                    ? Border(left: BorderSide(color: scheme.primary, width: 2))
                    : null),
            child: Row(children: [
              const SizedBox(
                  width: 12,
                  child: PrototypeIcon('grip', size: 24, color: Colors.grey)),
              if (g != null)
                layerButton(SizedBox(
                    width: 18,
                    child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 15,
                        onPressed: () => update(() => c.collapsed.contains(id)
                            ? c.collapsed.remove(id)
                            : c.collapsed.add(id)),
                        icon: PrototypeIcon(
                            c.collapsed.contains(id)
                                ? 'arrowRight'
                                : 'chevronDown',
                            size: 14)))),
              componentIcon(id),
              const SizedBox(width: 7),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _LayerName(
                        key: ValueKey('layer-name:$id'),
                        id: id,
                        name: n?.name ?? g!.name,
                        onEditing: (active) =>
                            update(() => layerRenameId = active ? id : null),
                        onRename: (value) => c.edit(() {
                              final node = c.doc.node(id),
                                  group = c.doc.group(id);
                              if (node != null) {
                                node.name = value;
                              } else if (group != null) {
                                group.name = value;
                              }
                            })),
                    Text(
                        n == null
                            ? '${c.doc.leaves(id).length} 个组件'
                            : componentNames[n.type]!,
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).hintColor))
                  ])),
              layerButton(SizedBox(
                  width: 27,
                  child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: c.doc.visible(id) ? '隐藏' : '显示',
                      onPressed: () => c.edit(() {
                            if (n != null) {
                              n.visible = !n.visible;
                            } else {
                              g!.visible = !g.visible;
                            }
                          }),
                      icon: PrototypeIcon(c.doc.visible(id) ? 'eye' : 'eyeOff',
                          size: 18)))),
              layerButton(SizedBox(
                  width: 26,
                  child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: c.doc.locked(id) ? '解锁' : '锁定',
                      onPressed: () => c.edit(() {
                            if (n != null) {
                              n.locked = !n.locked;
                            } else {
                              g!.locked = !g.locked;
                            }
                          }),
                      icon: PrototypeIcon(
                          (n?.locked ?? g!.locked) ? 'lock' : 'unlock',
                          size: 18))))
            ])));
    late BuildContext dropContext;
    (String?, int, bool, bool, int) destination(Offset global) {
      final box = dropContext.findRenderObject() as RenderBox,
          local = box.globalToLocal(global);
      final before = local.dy < box.size.height * .35;
      final parent = c.doc.parent(id);
      if (g != null && !before && local.dx > 32 + depth * 12)
        return (
          id,
          local.dy > box.size.height * .7 ? 0 : g.children.length,
          true,
          false,
          depth + 1
        );
      if (parent != null &&
          !before &&
          c.doc.children(parent).first == id &&
          local.dx < 32 + depth * 12) {
        var target = parent, targetDepth = depth - 1;
        while (c.doc.parent(target) != null &&
            c.doc.children(c.doc.parent(target)).first == target &&
            local.dx < 32 + targetDepth * 12) {
          target = c.doc.parent(target)!;
          targetDepth--;
        }
        final outside = c.doc.parent(target);
        return (
          outside,
          c.doc.children(outside).indexOf(target),
          outside != null,
          false,
          targetDepth
        );
      }
      return (
        parent,
        c.doc.children(parent).indexOf(id) + (before ? 1 : 0),
        parent != null,
        before,
        depth
      );
    }

    return DragTarget<String>(
        onWillAcceptWithDetails: (d) => d.data != id,
        onMove: (d) {
          dragGlobal = d.offset;
          final dest = destination(d.offset);
          if (dropRow != id || dropLocation != dest)
            update(() {
              dropRow = id;
              dropLocation = dest;
            });
        },
        onLeave: (_) {
          if (dropRow == id) update(() => dropRow = null);
        },
        onAcceptWithDetails: (d) {
          final dest = destination(d.offset);
          c.reorderMany(
              c.selection.contains(d.data) ? c.orderedSelection() : [d.data],
              dest.$1,
              dest.$2);
          update(() => dropRow = null);
        },
        builder: (ctx, candidates, rejected) {
          dropContext = ctx;
          final active = candidates.isNotEmpty && dropRow == id,
              where = dropLocation;
          return Stack(clipBehavior: Clip.none, children: [
            _LayerDraggable(
                data: id,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                maxSimultaneousDrags:
                    c.doc.locked(id) || layerRenameId == id ? 0 : 1,
                onDragStarted: () {
                  dragTimer?.cancel();
                  dragTimer =
                      Timer.periodic(const Duration(milliseconds: 40), (_) {
                    final box =
                        layerViewport.currentContext?.findRenderObject();
                    if (box is! RenderBox ||
                        dragGlobal == null ||
                        !layerScroll.hasClients) return;
                    final local = box.globalToLocal(dragGlobal!);
                    final delta = local.dy < 35
                        ? -12.0
                        : local.dy > box.size.height - 35
                            ? 12.0
                            : 0.0;
                    if (delta != 0)
                      layerScroll.jumpTo((layerScroll.offset + delta)
                          .clamp(0, layerScroll.position.maxScrollExtent));
                  });
                },
                onDragEnd: (_) {
                  dragTimer?.cancel();
                  update(() => dropRow = null);
                },
                feedback: Material(
                    key: const ValueKey('layer-drag-feedback'),
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(n?.name ?? g!.name))),
                childWhenDragging: Opacity(opacity: .4, child: row),
                child: row),
            if (active && where != null)
              Positioned(
                  left: 7 + where.$5 * 12.0,
                  right: 7,
                  top: where.$4 ? 0 : null,
                  bottom: where.$4 ? null : 0,
                  child: IgnorePointer(
                      child: Row(children: [
                    Expanded(
                        child: Container(height: 2, color: scheme.primary)),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4)),
                        child: Row(children: [
                          PrototypeIcon(where.$3 ? 'dropInside' : 'dropOutside',
                              size: 17),
                          const SizedBox(width: 3),
                          Text(where.$3 ? '组内' : '组外',
                              style: TextStyle(
                                  fontSize: 11, color: scheme.primary))
                        ]))
                  ])))
          ]);
        });
  }

  Future<void> renameGroup(StyleGroup g) async {
    final input = TextEditingController(text: g.name);
    final result = await modal<String>((ctx) => AlertDialog(
            title: const Text('组名称'),
            content: TextField(controller: input, autofocus: true),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, input.text),
                  child: const Text('保存'))
            ]));
    if (result != null) c.edit(() => g.name = result);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      input.dispose();
    });
  }

  /// 编辑内置预设（制作版）时：把当前画布恢复为此版本的默认样式。
  /// 可撤销；点“保存预设”后才会写入制作版工作库。
  Future<void> restoreBuiltinDefault() async {
    final id = builtinTarget;
    final original = id == null ? null : widget.presets.builtinOriginal(id);
    if (original == null) return;
    finishInline();
    c.end();
    final yes = await modal<bool>((ctx) => WorkspaceDialog(
            title: const Text('恢复默认'),
            content: SizedBox(
                width: 400,
                child: Text(
                    '将“${original.style.name}”恢复为此版本的默认样式。当前未保存的修改会被替换，可用撤销找回；点“保存预设”后才会写入制作版工作库。')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('恢复默认'))
            ]));
    if (yes != true || !mounted) return;
    c.edit(() {
      c.doc = original.style.copy();
      c.doc.switchLayout(StyleDocument.orientation(ratio));
      c.selection.clear();
      resetOpenedPreset();
    });
    update(() => status = '已恢复默认：${original.style.name}（保存后生效）');
  }

  /// [anchor] 是触发按钮的上下文，菜单贴着它展开。
  void addMenu(BuildContext anchor) async {
    if (dialogOpen) return;
    dialogOpen = true;
    String? type;
    try {
      type = await showComponentPicker(anchor, [
        for (final e in componentNames.entries)
          ComponentChoice(e.key, e.value, componentSymbol(e.key)),
        const ComponentChoice('material', '内置素材', 'material')
      ]);
    } finally {
      dialogOpen = false;
    }
    if (type == 'image') {
      await addImageMark();
      return;
    }
    if (type == 'material') {
      if (!mounted) return;
      await addBuiltinMaterial(anchor);
      return;
    }
    if (type != null) {
      if (type == 'palette' && !await ensurePhotoPalette()) {
        update(() => status = paletteError ?? '照片已切换，请重新添加色卡');
        return;
      }
      if (!mounted) return;
      c.add(type, ratio);
      update(() => panel = 2);
    }
  }

  Widget inspectorPanel() => Column(children: [
        PrototypeTabs(
            labels: const ['预设', '画布', '组件'],
            selected: panel,
            expand: true,
            onSelect: (i) {
              finishInline();
              update(() => panel = i);
            }),
        Expanded(
            child: panel == 0
                ? presetsPanel()
                : SmoothScroll(
                    controller: propertyScroll,
                    child: Scrollbar(
                        controller: propertyScroll,
                        child: SingleChildScrollView(
                            controller: propertyScroll,
                            padding: const EdgeInsets.fromLTRB(18, 15, 18, 22),
                            child: panel == 1
                                ? canvasProperties()
                                : componentProperties())))),
        Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 14),
            child: Column(children: [
              Text(
                  builtinTarget != null && widget.presets.authoring
                      ? '正在维护内置预设 · 保存后更新制作版工作库'
                      : '草稿仅在确认应用后影响照片。',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: PrototypeActionButton(
                        label: '保存预设',
                        icon: 'savePreset',
                        onPressed: saving ? null : savePreset)),
                const SizedBox(width: 8),
                Expanded(
                    child: PrototypeActionButton(
                        label: '应用样式',
                        icon: 'applyStyle',
                        primary: true,
                        iconAfter: true,
                        onPressed:
                            applying || files.isEmpty ? null : applyStyle))
              ])
            ]))
      ]);
  InputDecoration fieldDecoration({String? suffix, Widget? prefix}) =>
      InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Theme.of(context).inputDecorationTheme.fillColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: .65))),
          suffixText: suffix,
          suffixStyle: EditorTypography.label(context),
          prefixIcon: prefix,
          prefixIconConstraints: prefix == null
              ? null
              : const BoxConstraints(minWidth: 40, maxWidth: 40));
  Widget section(String title, List<Widget> children) => Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.only(top: 13, bottom: 20),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: .075)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: EditorTypography.title(context)),
        const SizedBox(height: 14),
        ...children
      ]));
  Widget valueField(String name, String value, ValueChanged<String> change,
      {bool multiline = false,
      Widget? prefix,
      NumberDragSpec? number,
      String? Function()? onReset}) {
    final suffix = name.contains(' px')
        ? 'px'
        : name.contains(' %')
            ? '%'
            : null;
    final label = name.replaceAll(' px', '').replaceAll(' %', '');
    return Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: _ValueField(
            label: label,
            value: value,
            number: number,
            onReset: onReset,
            decoration: fieldDecoration(suffix: suffix, prefix: prefix),
            onChanged: (v) {
              if (c.protected && panel == 2) return;
              c.begin();
              change(v);
              c.update();
            },
            onDone: c.end,
            onCancel: () => c.end(cancel: true),
            multiline: multiline));
  }

  Widget numeric(String name, double value, ValueChanged<double> change,
          {double min = 0, double max = 100, double step = 1, double? reset}) =>
      valueField(name, numberInputText(value), (s) {
        final v = double.tryParse(s);
        if (v != null && v.isFinite) change(v.clamp(min, max));
      },
          number: NumberDragSpec(
              min: min, max: max, fallback: value, step: step, reset: reset));
  Future<void> pickColor(int value, ValueChanged<int> change) async {
    if (dialogOpen || (panel == 2 && c.protected)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    // Finish delayed field blur callbacks before opening the color transaction.
    FocusManager.instance.applyFocusChangesIfNeeded();
    c.end();
    saveTimer?.cancel();
    c.begin();
    colorPicking = true;
    var confirmed = false;
    var active = true;
    try {
      confirmed = await modal<bool>((context) => HsbColorPicker(
              initialColor: Color(value),
              onChanged: (color) {
                if (!mounted || !active) return;
                change(color.toARGB32());
                c.update();
              })) ==
          true;
    } finally {
      active = false;
      colorPicking = false;
      if (mounted) c.end(cancel: !confirmed);
    }
  }

  /// 只在确定后返回颜色，不边拖边改画布。邮戳换色用这个，避免每动一下都重画一张图。
  Future<int?> pickSolidColor(int value) async {
    if (dialogOpen || (panel == 2 && c.protected)) return null;
    FocusManager.instance.primaryFocus?.unfocus();
    FocusManager.instance.applyFocusChangesIfNeeded();
    c.end();
    var current = value;
    final confirmed = await modal<bool>((context) => HsbColorPicker(
            initialColor: Color(value),
            onChanged: (color) => current = color.toARGB32())) ==
        true;
    return confirmed ? current : null;
  }

  Widget colorField(String title, int value, ValueChanged<int> change,
          {bool mixed = false}) =>
      valueField(
          mixed ? '$title · 多个值' : title, mixed ? '' : colorHex(Color(value)),
          (s) {
        if (RegExp(r'^#[\da-fA-F]{6}$').hasMatch(s))
          change(int.parse('ff' + s.substring(1), radix: 16));
      },
          prefix: ColorSwatchButton(
              color: Color(value),
              mixed: mixed,
              label: title,
              onPressed: () => pickColor(value, change)));
  Widget borderField(String side, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: _ValueField(
          label: label,
          value:
              c.doc.borders[side]!.toString().replaceFirst(RegExp(r'\.0$'), ''),
          decoration: fieldDecoration(suffix: '%'),
          number: NumberDragSpec(
              min: 0,
              max: 40,
              fallback: c.doc.borders[side]!,
              step: .1,
              reset: const {
                'top': 3.0,
                'right': 3.0,
                'bottom': 16.0,
                'left': 3.0
              }[side]),
          onChanged: (s) {
            final v = double.tryParse(s);
            if (v != null && v.isFinite) {
              c.begin();
              c.border(side, v.clamp(0, 40), ratio, scene?.bounds ?? {});
            }
          },
          onDone: c.end,
          onCancel: () => c.end(cancel: true)));
  Widget pair(Widget left, Widget right) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right)
      ]);
  Widget opacityControl(List<StyleNode> nodes) {
    final mixed = nodes.map((n) => n.opacity).toSet().length > 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('不透明度', style: EditorTypography.label(context)),
        const Spacer(),
        Text(mixed ? '多个值' : '${nodes.first.opacity.round()}%',
            style: const TextStyle(fontSize: 12))
      ]),
      SliderTheme(
          data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12)),
          child: Slider(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
              value: nodes.first.opacity.clamp(0, 100),
              min: 0,
              max: 100,
              semanticFormatterCallback: (v) => '不透明度 ${v.round()}%',
              onChangeStart: (_) => c.begin(),
              onChanged: (v) {
                for (final n in nodes) {
                  n.opacity = v;
                }
                c.update();
              },
              onChangeEnd: (_) => c.end()))
    ]);
  }

  Widget canvasProperties() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        section('布局适配', [
          PrototypeSelect(
              value: c.doc.adaptive ? 'separate' : 'unified',
              options: const {'unified': '统一布局', 'separate': '横竖独立'},
              onChanged: (v) => c.edit(() {
                    c.doc.setAdaptive(v == 'separate');
                    if (c.doc.adaptive)
                      c.doc.switchLayout(StyleDocument.orientation(ratio));
                  })),
          if (c.doc.adaptive) ...[
            const SizedBox(height: 12),
            Text('正在编辑', style: EditorTypography.label(context)),
            const SizedBox(height: 8),
            PrototypeSelect(
                value: c.doc.editingLayout,
                options: StyleDocument.layoutNames,
                onChanged: (v) {
                  finishInline();
                  c.end();
                  update(() {
                    c.doc.switchLayout(v);
                    previewMode = v == 'general' ? 'original' : v;
                    zoom = 1;
                    pan = Offset.zero;
                  });
                }),
            const SizedBox(height: 12),
            Text(c.doc.hasLayoutChanges ? '此布局已独立设置' : '此布局跟随通用设置',
                style: EditorTypography.hint(context)),
            const SizedBox(height: 12),
            if (c.doc.editingLayout != 'general')
              Row(children: [
                Expanded(
                    child: WorkspaceActionButton(
                  label: '从通用复制',
                  onPressed: () => c.edit(c.doc.copyGeneralLayout),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: WorkspaceActionButton(
                        label: '恢复通用',
                        onPressed: c.doc.hasLayoutChanges
                            ? () => c.edit(c.doc.resetLayout)
                            : null))
              ]),
            const SizedBox(height: 8),
            Text('内容、字体、颜色与装饰共享；位置、尺寸、边框和可见性独立。方图使用通用布局。',
                style: EditorTypography.hint(context).copyWith(height: 1.8))
          ]
        ]),
        section('边框 · 照片短边比例', [
          Row(children: [
            SizedBox(
                width: 22,
                height: 28,
                child: Checkbox(
                    value: c.doc.linked,
                    onChanged: (v) => c.edit(() => c.doc.linked = v!),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
            const SizedBox(width: 7),
            const Text('四边联动', style: TextStyle(fontSize: 12))
          ]),
          const SizedBox(height: 9),
          pair(borderField('top', '上'), borderField('bottom', '下')),
          pair(borderField('left', '左'), borderField('right', '右')),
          const Text('四边为 0 时，组件可叠加在照片上。',
              style: TextStyle(fontSize: 12, height: 1.8))
        ]),
        backgroundProperties(),
        shadowProperties(),
        photoStrokeProperties(),
        filmProperties(),
      ]);
  Widget infoFieldEditor(StyleNode node) {
    if (files.isEmpty) {
      return Text('请先选择一张照片，再填写拍摄信息。', style: EditorTypography.hint(context));
    }
    final path = files[index].path;
    final keys = captureFieldsForComponent(node.type);
    final original = originalInformation[path];
    if (original == null) return const SizedBox.shrink();
    final pickPlace = widget.onPickPlace;
    return PhotoInfoForm(
      key: ValueKey('component-info-$path-${node.id}'),
      existing: original,
      manual: Map.of(information[path] ?? const {}),
      keys: keys,
      compact: true,
      directEdit: true,
      onChanged: (key, value) => queueField(path, key, value),
      onPickPlace: !keys.contains('place') || pickPlace == null
          ? null
          : () async {
              FocusScope.of(context).unfocus();
              final place = await pickPlace(context);
              if (mounted && place != null) queueField(path, 'place', place);
            },
    );
  }

  Widget photoInfoPanel() {
    if (files.isEmpty) {
      return const Text('选择照片后可以查看和补填拍摄信息', style: TextStyle(height: 2));
    }
    final path = files[index].path;
    return PhotoInfoForm(
        key: ValueKey('photo-info-panel-$path'),
        existing: originalInformation[path] ?? const {},
        manual: information[path] ?? const {},
        compact: true,
        onChanged: (key, value) => queueField(path, key, value));
  }

  void flushPhotoField() {
    final pending = fieldPending;
    fieldPending = null;
    if (pending != null) {
      final (path, key, value) = pending;
      widget.onSaveField?.call(path, key, value);
    }
  }

  void queueField(String path, String key, String value) {
    final text = value.trim();
    if (validateInfo(key, text) != null) return;
    final original = originalInformation[path]?[key] ?? '';
    final override = text == original ? '' : text;
    update(() {
      final info = information[path] ??= {};
      final effective = override.isEmpty ? original : override;
      if (effective.isEmpty) {
        info.remove(key);
      } else {
        info[key] = effective;
      }
    });
    final pending = fieldPending;
    if (pending != null && (pending.$1 != path || pending.$2 != key)) {
      flushPhotoField();
    }
    fieldPending = (path, key, override);
    fieldTimer?.cancel();
    fieldTimer = Timer(const Duration(milliseconds: 400), flushPhotoField);
  }

  Widget componentProperties() {
    final nodes = c.selectedNodes;
    if (c.selection.isEmpty) return photoInfoPanel();
    final single =
        c.selection.length == 1 ? c.doc.node(c.selection.first) : null;
    final common = nodes.isEmpty ? null : nodes.first;
    void batch(void Function(StyleNode) change) {
      for (final n in nodes) {
        change(n);
      }
    }

    bool mixed(Object Function(StyleNode) get) =>
        nodes.map(get).toSet().length > 1;
    String? restoreNumbers(
        double Function(StyleNode) get,
        void Function(StyleNode, double) set,
        double min,
        double max,
        double fallback) {
      c.edit(() {
        for (final n in List<StyleNode>.from(nodes)) {
          final base = initialNode(n.id);
          final raw = base == null ? fallback : get(base);
          set(n, raw.clamp(min, max));
        }
      });
      final values = nodes.map(get).toSet();
      if (values.length != 1) return '';
      return numberInputText(values.single);
    }

    Widget batchNumber(String label, double Function(StyleNode) get,
        void Function(StyleNode, double) set,
        {double min = 0, double max = 100, double? reset}) {
      final different = mixed(get), v = get(nodes.first);
      return valueField(
          different ? '$label · 多个值' : label,
          different
              ? ''
              : ((v * 10).round() / 10)
                  .toString()
                  .replaceFirst(RegExp(r'\.0$'), ''), (s) {
        final value = double.tryParse(s);
        if (value != null && value.isFinite)
          batch((n) => set(n, value.clamp(min, max)));
      },
          onReset: () => restoreNumbers(get, set, min, max, reset ?? v),
          number: NumberDragSpec(
              min: min,
              max: max,
              fallback: v,
              step: label.contains('字间距') ? .1 : 1));
    }

    return IgnorePointer(
        ignoring: c.protected,
        child: Opacity(
            opacity: c.protected ? .5 : 1,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (single != null)
                    section(componentNames[single.type]!, [
                      valueField('图层名称', single.name, (v) => single.name = v),
                      if (single.type == 'text')
                        valueField('内容', single.text, (v) => single.text = v,
                            multiline: true)
                      else if (captureFieldsForComponent(single.type)
                          .isNotEmpty)
                        infoFieldEditor(single)
                    ])
                  else
                    section('已选 ${c.selection.length} 项', [
                      const Text('共同属性只修改实际输入的项目',
                          style: TextStyle(fontSize: 12, height: 1.8))
                    ]),
                  if (single?.type == 'palette') paletteProperties(single!),
                  if (single?.type == 'image') imageProperties(single!),
                  if (single?.type == 'shape') shapeProperties(single!),
                  if (common != null &&
                      nodes.every((n) =>
                          !['palette', 'image', 'shape'].contains(n.type)))
                    section('文字样式', [
                      Text('字体', style: EditorTypography.label(context)),
                      const SizedBox(height: 8),
                      PrototypeSelect(
                          value: mixed((n) => n.font) ? null : common.font,
                          options: artworkFontOptions,
                          optionStyle: (id) => artworkTextStyle(id).copyWith(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface),
                          onChanged: (v) =>
                              c.edit(() => batch((n) => n.font = v))),
                      if (artworkFontNotice(common.font) != null) ...[
                        const SizedBox(height: 8),
                        Text(artworkFontNotice(common.font)!,
                            style: EditorTypography.hint(context)),
                      ],
                      const SizedBox(height: 17),
                      pair(
                          batchNumber('字号 px', (n) => n.fontSize,
                              (n, v) => n.fontSize = v,
                              min: 8, max: double.infinity, reset: 24),
                          batchNumber('字间距 px', (n) => n.spacing,
                              (n, v) => n.spacing = v,
                              max: 15, reset: 0)),
                      Padding(
                          padding: const EdgeInsets.only(bottom: 17),
                          child: Text('以照片短边 1000 px 为基准，等比例缩放。',
                              style: EditorTypography.hint(context))),
                      colorField('文字颜色', common.color,
                          (v) => batch((n) => n.color = v),
                          mixed: mixed((n) => n.color)),
                      Text('对齐', style: EditorTypography.label(context)),
                      const SizedBox(height: 7),
                      Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .inputDecorationTheme
                                  .fillColor,
                              borderRadius: BorderRadius.circular(5)),
                          child: Row(children: [
                            for (final a in ['left', 'center', 'right'])
                              Expanded(
                                  child: SizedBox(
                                      height: 29,
                                      child: TextButton(
                                          style: TextButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              backgroundColor:
                                                  !mixed((n) => n.align) &&
                                                          common.align == a
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .surfaceContainerHighest
                                                      : Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          4))),
                                          onPressed: () => c.edit(
                                              () => batch((n) => n.align = a)),
                                          child: PrototypeIcon(
                                              a == 'left'
                                                  ? 'alignLeft'
                                                  : a == 'right'
                                                      ? 'alignRight'
                                                      : 'alignCenter',
                                              ui: true,
                                              size: 17,
                                              color: !mixed((n) => n.align) &&
                                                      common.align == a
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : null))))
                          ])),
                      const SizedBox(height: 17),
                      opacityControl(nodes)
                    ]),
                  if (common != null &&
                      !['palette', 'image', 'shape'].contains(single?.type) &&
                      nodes.any((n) =>
                          ['palette', 'image', 'shape'].contains(n.type)))
                    section('共同属性', [opacityControl(nodes)]),
                  if (single != null)
                    section('位置与锚点', [
                      Text('相对区域', style: EditorTypography.label(context)),
                      const SizedBox(height: 8),
                      PrototypeSelect(
                          value: single.anchor,
                          options: const {
                            'bottom': '下边框',
                            'photo': '照片区域',
                            'canvas': '整个画布'
                          },
                          onChanged: (v) => c.changeAnchor(single, v, ratio)),
                      const SizedBox(height: 15),
                      pair(
                          numeric('X · 水平 %', single.x, (v) => single.x = v,
                              min: double.negativeInfinity,
                              max: double.infinity,
                              reset: initialNum(single.id, (n) => n.x, 50)),
                          numeric('Y · 垂直 %', single.y, (v) => single.y = v,
                              min: double.negativeInfinity,
                              max: double.infinity,
                              reset: initialNum(single.id, (n) => n.y, 50))),
                      Text('锚点仅用于尺寸适配，坐标可超出 0～100%。切换区域保持位置，Alt 临时关闭吸附。',
                          style: EditorTypography.hint(context))
                    ]),
                  componentActions(),
                  Container(
                      padding: const EdgeInsets.only(top: 13, bottom: 20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              Text('组件对齐',
                                  style: EditorTypography.title(context)),
                              const Spacer(),
                              Text(c.selection.length > 1 ? '相对选区' : '相对画布',
                                  style: EditorTypography.label(context))
                            ]),
                            const SizedBox(height: 13),
                            Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .inputDecorationTheme
                                        .fillColor,
                                    borderRadius: BorderRadius.circular(6)),
                                child: Row(children: [
                                  for (int i = 0; i < 6; i++)
                                    Expanded(
                                        child: SizedBox(
                                            height: 30,
                                            child: IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                        minWidth: 0,
                                                        minHeight: 0),
                                                tooltip: [
                                                  '左对齐',
                                                  '水平居中',
                                                  '右对齐',
                                                  '上对齐',
                                                  '垂直居中',
                                                  '下对齐'
                                                ][i],
                                                onPressed: () =>
                                                    alignSelection(i),
                                                icon: PrototypeIcon(
                                                    [
                                                      'alignLeft',
                                                      'alignCenter',
                                                      'alignRight',
                                                      'arrowUp',
                                                      'params',
                                                      'arrowDown'
                                                    ][i],
                                                    ui: true,
                                                    size: 17))))
                                ]))
                          ]))
                ])));
  }

  Widget componentActions() {
    final scheme = Theme.of(context).colorScheme;
    Widget button(String label, String icon, VoidCallback action,
        {bool danger = false}) {
      final color = danger ? const Color(0xffe49b8c) : scheme.onSurface;
      return SizedBox(
          height: 32,
          child: TextButton(
              style: TextButton.styleFrom(
                  backgroundColor: scheme.surfaceContainerHighest,
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6))),
              onPressed: action,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                PrototypeIcon(icon, ui: true, size: 16, color: color),
                const SizedBox(width: 7),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500))
              ])));
    }

    return Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.only(top: 12, bottom: 20),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: scheme.onSurface.withValues(alpha: .075)))),
        child: Row(children: [
          Expanded(child: button('复制', 'duplicate', c.duplicate)),
          const SizedBox(width: 8),
          Expanded(child: button('删除', 'trash', c.remove, danger: true))
        ]));
  }

  Widget presetSaveCard(String name, StyleDocument? style, bool selected,
          VoidCallback onTap) =>
      InkWell(
          onTap: onTap,
          child: Container(
              width: 155,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent)),
              child: Column(children: [
                SizedBox(
                    height: 95,
                    child: style == null
                        ? const Icon(Icons.add, size: 28)
                        : PresetThumbnail(
                            style: style,
                            child: photo == null
                                ? const Icon(Icons.photo_outlined)
                                : StylePreview(
                                    photoPath: files.isEmpty
                                        ? null
                                        : files[index].path,
                                    photo: photo!,
                                    document: style,
                                    fields: fields))),
                const SizedBox(height: 7),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        // Spelled out: the card sits on a tinted background,
                        // and this text used to fall back to a near-white.
                        color: Theme.of(context).colorScheme.onSurface))
              ])));
  Widget presetsPanel() => PresetPanel(
      store: widget.presets,
      activeId: widget.presets.selection.primary ?? builtinTarget,
      settings: widget.settings,
      photo: photo,
      photoPath: files.isEmpty ? null : files[index].path,
      fields: fields,
      onEditBuiltin: widget.presets.authoring
          ? (entry) async {
              finishInline();
              builtinTarget = entry.id;
              c.edit(() {
                c.doc = entry.style.copy();
                c.doc.switchLayout(StyleDocument.orientation(ratio));
                c.selection.clear();
                resetOpenedPreset();
              });
              status = '正在维护内置预设：${entry.style.name}';
            }
          : null,
      onApply: (entry) async {
        builtinTarget =
            widget.presets.authoring && entry.builtIn ? entry.id : null;
        finishInline();
        c.end();
        c.edit(() {
          c.doc = entry.style.copy();
          c.doc.switchLayout(StyleDocument.orientation(ratio));
          c.selection.clear();
          resetOpenedPreset();
        });
      },
      onNew: () {
        builtinTarget = null;
        finishInline();
        widget.presets.selection.clear();
        c.edit(() {
          c.doc = StyleDocument(name: '空白样式');
          c.selection.clear();
          resetOpenedPreset();
        });
      });

  Widget photosPanel() => _PhotoFocus(
      child: WorkspaceFilmstrip(
          notice: '载入只改变草稿，应用样式后才修改照片。',
          relinkCount: widget.relinkCount,
          onRelink: widget.onRelink,
          autoRelinkCount: widget.autoRelinkCount,
          onShowAutoRelink: widget.onShowAutoRelink,
          files: files,
          selected: selectedPhotos,
          current: index,
          controller: photoScroll,
          edited: {...widget.edited, ...appliedSnapshots.keys},
          onSelect: (i, control, shift) =>
              pickPhoto(i, toggle: control, range: shift),
          onSelectAll: () =>
              update(() => selectedPhotos = files.map((f) => f.path).toSet()),
          onClear: () => update(() => selectedPhotos.clear())));
}

class _ValueField extends StatefulWidget {
  final String label, value;
  final ValueChanged<String> onChanged;
  final VoidCallback onDone;
  final VoidCallback? onCancel;
  final NumberDragSpec? number;
  final String? Function()? onReset;
  final bool multiline;
  final InputDecoration? decoration;
  const _ValueField(
      {required this.label,
      required this.value,
      required this.onChanged,
      required this.onDone,
      this.onCancel,
      this.number,
      this.onReset,
      this.multiline = false,
      this.decoration});
  @override
  State<_ValueField> createState() => _ValueFieldState();
}

class _ValueFieldState extends State<_ValueField> {
  late final input = TextEditingController(text: widget.value);
  late final FocusNode focus = FocusNode()
    ..addListener(() {
      if (!focus.hasFocus) finish();
    });
  void finish() {
    final number = widget.number;
    if (number != null) {
      final value = double.tryParse(input.text);
      if (value == null || !value.isFinite) {
        input.text = widget.value;
      } else {
        final text = numberInputText(value.clamp(number.min, number.max));
        if (text != input.text) {
          input.text = text;
          widget.onChanged(text);
        }
      }
    }
    widget.onDone();
  }

  @override
  void didUpdateWidget(covariant _ValueField old) {
    super.didUpdateWidget(old);
    if (!focus.hasFocus && input.text != widget.value)
      input.text = widget.value;
  }

  @override
  void dispose() {
    input.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.label, style: EditorTypography.label(context)),
        const SizedBox(height: 7),
        if (widget.number != null)
          NumberDragInput(
              controller: input,
              focusNode: focus,
              spec: widget.number!,
              onReset: widget.onReset,
              decoration: widget.decoration,
              style: EditorTypography.value(context),
              onChanged: widget.onChanged,
              onDone: finish,
              onCancel: widget.onCancel ?? widget.onDone)
        else
          TextField(
              controller: input,
              decoration: widget.decoration,
              focusNode: focus,
              maxLines: widget.multiline ? 3 : 1,
              style: EditorTypography.value(context),
              onChanged: widget.onChanged,
              onSubmitted: (_) => widget.onDone(),
              onTapOutside: (_) => focus.unfocus())
      ]);
}

class _LayerName extends StatefulWidget {
  final String id, name;
  final ValueChanged<String> onRename;
  final ValueChanged<bool> onEditing;
  const _LayerName(
      {super.key,
      required this.id,
      required this.name,
      required this.onRename,
      required this.onEditing});
  @override
  State<_LayerName> createState() => _LayerNameState();
}

class _LayerNameState extends State<_LayerName> {
  final input = TextEditingController(), focus = FocusNode();
  bool editing = false;
  @override
  void initState() {
    super.initState();
    focus.addListener(() {
      if (!focus.hasFocus && editing) finish();
    });
  }

  void start() {
    setState(() {
      editing = true;
      input.text = widget.name;
      input.selection =
          TextSelection(baseOffset: 0, extentOffset: input.text.length);
    });
    widget.onEditing(true);
    focus.requestFocus();
  }

  void finish({bool cancel = false}) {
    if (!editing) return;
    final value = input.text.trim();
    setState(() => editing = false);
    if (!cancel && value.isNotEmpty && value != widget.name)
      widget.onRename(value);
    widget.onEditing(false);
    focus.unfocus();
  }

  @override
  void dispose() {
    focus.dispose();
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => editing
      ? Focus(
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              finish(cancel: true);
              return KeyEventResult.handled;
            }
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter) {
              finish();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
              key: ValueKey('layer-name-edit:${widget.id}'),
              controller: input,
              focusNode: focus,
              maxLines: 1,
              style: const TextStyle(fontSize: 13, height: 1.3),
              decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 4, vertical: 3)),
              onSubmitted: (_) => finish(),
              onTapOutside: (_) => finish()))
      : GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: start,
          child: Text(widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13)));
}

/// 图层行按下后先只选中。挪开大约 20 像素才开始拖。
///
/// 拖动识别器常常是这场手势里唯一的参赛者，系统会在按下后立刻判它获胜。
/// 获胜不等于开始拖：没挪开约 20 像素之前，只记下“可以拖”，并不抬起浮层。
class _LayerDraggable extends Draggable<String> {
  const _LayerDraggable({
    required super.child,
    required super.feedback,
    super.data,
    super.childWhenDragging,
    super.dragAnchorStrategy,
    super.maxSimultaneousDrags,
    super.onDragStarted,
    super.onDragEnd,
  });
  @override
  MultiDragGestureRecognizer createRecognizer(
          GestureMultiDragStartCallback onStart) =>
      _LayerDragRecognizer()..onStart = onStart;
}

class _LayerDragRecognizer extends MultiDragGestureRecognizer {
  _LayerDragRecognizer() : super(debugOwner: null);
  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      _LayerPointerState(event.position, event.kind, gestureSettings);
  @override
  String get debugDescription => 'layer drag';
}

class _LayerPointerState extends MultiDragPointerState {
  _LayerPointerState(super.initialPosition, super.kind, super.gestureSettings);
  static const _distance = 20.0;
  GestureMultiDragStartCallback? _starter;
  bool _started = false, _dead = false;

  bool get _movedEnough =>
      pendingDelta != null && pendingDelta!.distance > _distance;

  void _begin() {
    if (_dead || _started || _starter == null || pendingDelta == null) return;
    _started = true;
    final starter = _starter!;
    _starter = null;
    starter(initialPosition);
  }

  /// 挪开够了才开始拖。还没被判赢时，先去争取；已经被提前判赢时，直接开始。
  void _claimOrStart() {
    if (_dead || _started || !_movedEnough) return;
    if (_starter != null) {
      _begin();
    } else {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void checkForResolutionAfterMove() => _claimOrStart();

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    _starter = starter;
    _claimOrStart();
  }

  @override
  void rejected() {
    _dead = true;
    _starter = null;
    super.rejected();
  }

  @override
  void dispose() {
    _dead = true;
    _starter = null;
    super.dispose();
  }
}
