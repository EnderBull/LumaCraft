part of 'editor_page.dart';

extension EditorCanvas on _PresetEditorState {
  Offset world(Offset p) => (p - origin) / canvasScale;
  String? hit(Offset point) {
    final s = scene;
    if (s == null) return null;
    for (final n in c.doc.painted.reversed) {
      if (n.type == 'shape') {
        // 形状按自身旋转后的局部范围判断，避免倾斜的长线条误选到旁边的组件。
        if (!c.doc.visible(n.id)) continue;
        final local =
            shapeToLocal(s.geometry.point(n), n.shape.rotation, point);
        final grow = math.max(4 / canvasScale, n.shape.stroke ? n.shape.strokeWidth / 2 : 0.0);
        if (Rect.fromCenter(
                center: Offset.zero,
                width: n.shape.width,
                height: n.shape.height)
            .inflate(grow)
            .contains(local)) return n.id;
        continue;
      }
      if (c.doc.visible(n.id) &&
          (s.bounds[n.id]?.inflate(4 / canvasScale).contains(point) ?? false))
        return n.id;
    }
    return null;
  }

  Rect? selectedBounds() {
    Rect? result;
    for (final id in c.selection) {
      final r = scene?.objectBounds(id);
      if (r != null) result = result == null ? r : result.expandToInclude(r);
    }
    return result;
  }

  StyleNode? selectedShape() {
    if (c.selection.length != 1 || c.protected) return null;
    final n = c.doc.node(c.selection.first);
    return n != null && n.type == 'shape' && c.doc.visible(n.id) ? n : null;
  }

  /// 命中形状抓点：返回（抓点, 是否为旋转抓点）。
  (ShapeGrip?, bool)? shapeGripAt(Offset point) {
    final n = selectedShape();
    if (n == null || scene == null) return null;
    final center = scene!.geometry.point(n), s = n.shape;
    final reach = 9 / canvasScale, pad = 16 / canvasScale;
    final rotate = shapeToWorld(
        center, s.rotation, shapeRotateGrip(s, 30 / canvasScale));
    if ((rotate - point).distance < reach) return (null, true);
    final grips = shapeGrips(s, pad);
    for (final type in ['adjust', 'radius', 'size']) {
      for (final g in grips.where((g) => g.type == type)) {
        if ((shapeToWorld(center, s.rotation, g.local) - point).distance <
            reach) return (g, false);
      }
    }
    return null;
  }

  void dragShapeGrip(PointerMoveEvent e) {
    final old = originals?.values.first;
    if (old == null || scene == null) return;
    final n = c.doc.node(old.id);
    if (n == null) return;
    final g = StyleGeometry(c.doc, ratio);
    final p = world(e.localPosition), center = g.point(old);
    if (shapeRotating) {
      final v = p - center;
      var rotation = shapeRotationStart +
          (math.atan2(v.dy, v.dx) - shapeAngleStart) * 180 / math.pi;
      if (shift) rotation = (rotation / 15).round() * 15.0;
      rotation %= 360;
      n.shape.rotation = rotation < 0 ? rotation + 360 : rotation;
    } else if (shapeGrip != null) {
      final grip = shapeGrip!;
      final local = shapeToLocal(center, old.shape.rotation, p);
      switch (grip.type) {
        case 'size':
          final r = resizeShapeByGrip(
              center: center,
              rotation: old.shape.rotation,
              width: old.shape.width,
              height: old.shape.height,
              sx: grip.sx,
              sy: grip.sy,
              pointer: p,
              keepRatio: shift);
          n.shape.width = r.width;
          n.shape.height = r.height;
          g.reanchor(n, old.anchor, point: r.center);
        case 'radius':
          dragShapeRadius(n.shape, local, 16 / canvasScale);
        case 'adjust':
          dragShapeAdjust(n.shape, local);
      }
    }
    c.update();
  }

  void pointerDown(PointerDownEvent e) {
    if (e.buttons != kPrimaryMouseButton) return;
    finishInline();
    resizingNode = false;
    FocusManager.instance.primaryFocus?.unfocus();
    down = e.localPosition;
    handDrag = space;
    panStart = pan;
    moved = false;
    guides = [];
    if (handDrag) return;
    final gripHit = shapeGripAt(world(e.localPosition));
    if (gripHit != null) {
      final shape = selectedShape()!;
      c.begin();
      originals = {shape.id: shape.copy()};
      shapeGrip = gripHit.$1;
      shapeRotating = gripHit.$2;
      if (shapeRotating) {
        final v = world(e.localPosition) - scene!.geometry.point(shape);
        shapeAngleStart = math.atan2(v.dy, v.dx);
        shapeRotationStart = shape.shape.rotation;
      }
      update(() => panel = 2);
      return;
    }
    final selected = selectedBounds();
    final knob = c.selection.length == 1 &&
        c.doc.node(c.selection.first) != null &&
        selected != null &&
        (world(e.localPosition) - selected.bottomRight).distance <
            9 / canvasScale;
    final leaf = knob ? c.selection.first : hit(world(e.localPosition));
    resizingNode = knob;
    if (leaf == null) {
      if (!ctrl && !shift) c.select(null);
      originals = null;
      return;
    }
    final id = c.selection.contains(leaf) ? leaf : c.doc.root(leaf);
    if (ctrl || shift) {
      c.select(id, toggle: true);
      down = null;
      update(() => panel = 2);
      return;
    }
    if (!c.selection.contains(id)) c.select(id);
    update(() => panel = 2);
    if (c.protected) {
      down = null;
      return;
    }
    c.begin();
    originals = {for (final n in c.selectedNodes) n.id: n.copy()};
    movingBounds = selectedBounds();
    if (resizingNode)
      resizeDistance = math.max(
          1,
          (world(down!) -
                  StyleGeometry(c.doc, ratio).point(c.selectedNodes.first))
              .distance);
  }

  void pointerMove(PointerMoveEvent e) {
    if (down == null) return;
    final delta = e.localPosition - down!;
    if (!moved && delta.distance < 3) return;
    moved = true;
    if (handDrag) {
      update(() => pan = panStart + delta);
      return;
    }
    if (shapeRotating || shapeGrip != null) {
      dragShapeGrip(e);
      return;
    }
    if (originals == null) {
      final a = world(down!), b = world(e.localPosition);
      update(() => marquee = Rect.fromPoints(a, b));
      return;
    }
    if (resizingNode) {
      final old = originals!.values.first, n = c.doc.node(old.id)!;
      final distance =
          (world(e.localPosition) - StyleGeometry(c.doc, ratio).point(old))
              .distance;
      if (n.type == 'palette') {
        n.palette.scale =
            (old.palette.scale * distance / resizeDistance).clamp(.1, 6);
      } else if (n.type == 'image') {
        n.image.width =
            (old.image.width * distance / resizeDistance).clamp(4, 2000);
      } else {
        final value = old.fontSize * distance / resizeDistance;
        if (value.isFinite) n.fontSize = math.max(8, value);
      }
      c.update();
      return;
    }
    var movement = delta / canvasScale;
    guides = [];
    if (c.snap &&
        !HardwareKeyboard.instance.isAltPressed &&
        movingBounds != null) {
      final excluded = originals!.keys.toSet(), g = StyleGeometry(c.doc, ratio);
      final refs = [
        g.photo,
        Offset.zero & g.size,
        ...scene!.bounds.entries
            .where((e) => !excluded.contains(e.key))
            .map((e) => e.value)
      ];
      final r = movingBounds!.shift(movement), limit = 6 / canvasScale;
      double bestX = limit, bestY = limit;
      double? gx, gy;
      double dx = 0, dy = 0;
      for (final ref in refs) {
        for (final pair in [
          (r.left, ref.left),
          (r.right, ref.right),
          (r.center.dx, ref.center.dx),
          (r.left, ref.right),
          (r.right, ref.left)
        ]) {
          final d = pair.$2 - pair.$1;
          if (d.abs() < bestX) {
            bestX = d.abs();
            dx = d;
            gx = pair.$2;
          }
        }
        for (final pair in [
          (r.top, ref.top),
          (r.bottom, ref.bottom),
          (r.center.dy, ref.center.dy),
          (r.top, ref.bottom),
          (r.bottom, ref.top)
        ]) {
          final d = pair.$2 - pair.$1;
          if (d.abs() < bestY) {
            bestY = d.abs();
            dy = d;
            gy = pair.$2;
          }
        }
      }
      movement += Offset(dx, dy);
      if (gx != null) guides.add((true, gx));
      if (gy != null) guides.add((false, gy));
    }
    c.moveNodes(originals!, movement, ratio);
  }

  void pointerUp(PointerUpEvent e) {
    if (down == null) return;
    if (handDrag) {
      update(() {
        down = null;
        handDrag = false;
      });
      return;
    }
    if (marquee != null) {
      final hits = c.doc.order.where((id) {
        final r = scene?.objectBounds(id);
        return c.doc.visible(id) &&
            !c.isProtected(id) &&
            r != null &&
            marquee!.contains(r.topLeft) &&
            marquee!.contains(r.bottomRight);
      }).toList();
      if (!ctrl && !shift) c.selection.clear();
      c.selection.addAll(hits);
      c.update();
    }
    c.end();
    update(() {
      down = null;
      originals = null;
      marquee = null;
      guides = [];
      shapeGrip = null;
      shapeRotating = false;
    });
  }

  void alignSelection(int direction) {
    if (c.selection.isEmpty || c.protected || scene == null) return;
    final rects = {for (final id in c.selection) id: scene!.objectBounds(id)};
    Rect? union;
    for (final r in rects.values.whereType<Rect>()) {
      union = union == null ? r : union.expandToInclude(r);
    }
    if (union == null) return;
    final target =
        c.selection.length == 1 ? Offset.zero & scene!.geometry.size : union;
    c.edit(() {
      for (final id in c.selection) {
        final r = rects[id];
        if (r == null) continue;
        final delta = switch (direction) {
          0 => Offset(target.left - r.left, 0),
          1 => Offset(target.center.dx - r.center.dx, 0),
          2 => Offset(target.right - r.right, 0),
          3 => Offset(0, target.top - r.top),
          4 => Offset(0, target.center.dy - r.center.dy),
          _ => Offset(0, target.bottom - r.bottom)
        };
        c.moveNodes(
            {for (final key in c.doc.leaves(id)) key: c.doc.node(key)!.copy()},
            delta,
            ratio);
      }
    });
  }

  Widget canvasPanel() => Column(children: [
        SizedBox(
            height: 45,
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          files.isEmpty
                              ? '示意画布（未选择照片） · ${c.doc.name}'
                              : '${files[index].uri.pathSegments.last} · ${c.doc.name}',
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: .60)),
                          overflow: TextOverflow.ellipsis)),
                  action(Icons.undo_rounded, '撤销 Ctrl+Z',
                      c.canUndo ? c.undo : null),
                  action(Icons.redo_rounded, '重做 Ctrl+Shift+Z',
                      c.canRedo ? c.redo : null),
                  neutral('添加组件', addMenu, icon: Icons.add),
                  Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Tooltip(
                          message: '拖动组件时对齐画布、照片与其他组件的边缘和中心线；按住 Alt 临时关闭。',
                          child: Semantics(
                              toggled: c.snap,
                              child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                      backgroundColor: c.snap
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: .12)
                                          : Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                      foregroundColor: c.snap
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6))),
                                  onPressed: () =>
                                      update(() => c.snap = !c.snap),
                                  icon: PrototypeIcon('snap', size: 18),
                                  label: Text(c.snap ? '吸附：开' : '吸附：关',
                                      style: const TextStyle(fontSize: 12)))))),
                  action(
                      Icons.restart_alt,
                      '恢复编辑前样式',
                      () => c.edit(() {
                            c.doc = entry.copy();
                            c.selection.clear();
                          }))
                ]))),
        Container(
            margin: const EdgeInsets.only(top: 3, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(7)),
            child: Text(
                '${c.doc.adaptive ? '${StyleDocument.layoutNames[c.doc.editingLayout]} · ' : ''}${files.isNotEmpty && styleEquals(appliedSnapshots[files[index].path], c.doc) ? '● 当前照片已应用此样式' : '● 草稿预览 · 尚未应用'}',
                style: TextStyle(fontSize: 14))),
        Expanded(
            child: photo == null || marksLoading
                ? Center(
                    child: Text(
                        marksLoading ? '正在加载图片标识…' : loadError ?? '正在加载照片…'))
                : LayoutBuilder(builder: (ctx, box) {
                    scene?.dispose();
                    scene = StyleScene(c.doc, photo!, fields,
                        hiddenId: inlineId,
                        ratioOverride: ratio,
                        resolveLayout: false,
                        showMissingInfo: true);
                    final g = scene!.geometry,
                        fit = math.min((box.maxWidth - 64) / g.size.width,
                            (box.maxHeight - 54) / g.size.height);
                    canvasScale = fit * zoom;
                    origin = Offset(
                            (box.maxWidth - g.size.width * canvasScale) / 2,
                            (box.maxHeight - g.size.height * canvasScale) / 2) +
                        pan;
                    final outside = scene!.bounds.entries
                        .where((e) =>
                            !(Offset.zero & g.size)
                                .inflate(.5)
                                .contains(e.value.topLeft) ||
                            !(Offset.zero & g.size)
                                .inflate(.5)
                                .contains(e.value.bottomRight))
                        .toList();
                    final wideText = scene!.painters.entries
                        .where((e) => e.value.width > g.size.width)
                        .length;
                    return Stack(children: [
                      Positioned.fill(
                          child: IgnorePointer(
                              child: CustomPaint(
                                  painter: _CanvasShadowPainter(
                                      g.size, origin, canvasScale)))),
                      Positioned(
                          left: origin.dx,
                          top: origin.dy,
                          width: g.size.width * canvasScale,
                          height: g.size.height * canvasScale,
                          child: IgnorePointer(
                              child: WorkspaceCanvas(
                                  child: SizedBox(
                                      width: g.size.width,
                                      height: g.size.height,
                                      child: CustomPaint(
                                          painter: StylePainter(c.doc.copy(),
                                              photo!, Map.of(fields),
                                              hiddenId: inlineId,
                                              resolveLayout: false,
                                              showMissingInfo: true,
                                              ratioOverride: ratio)))))),
                      Positioned.fill(
                          child: ClipRect(
                              child: MouseRegion(
                                  cursor: handDrag
                                      ? SystemMouseCursors.grabbing
                                      : space
                                          ? SystemMouseCursors.grab
                                          : SystemMouseCursors.basic,
                                  onExit: (_) {
                                    if (down == null && space)
                                      update(() => space = false);
                                  },
                                  child: Listener(
                                      behavior: HitTestBehavior.opaque,
                                      onPointerDown: pointerDown,
                                      onPointerMove: pointerMove,
                                      onPointerUp: pointerUp,
                                      onPointerCancel: (_) {
                                        if (handDrag) pan = panStart;
                                        handDrag = false;
                                        resizingNode = false;
                                        shapeGrip = null;
                                        shapeRotating = false;
                                        c.end(cancel: true);
                                        update(() {
                                          down = null;
                                          originals = null;
                                          marquee = null;
                                          guides = [];
                                        });
                                      },
                                      onPointerSignal: (event) {
                                        if (event is! PointerScrollEvent ||
                                            down != null) return;
                                        GestureBinding
                                            .instance.pointerSignalResolver
                                            .register(event, (_) async {
                                          if (!await DesktopWindow
                                                  .wheelAltPressed() ||
                                              !mounted) return;
                                          final next = (zoom *
                                                      math.exp(-event
                                                              .scrollDelta.dy *
                                                          .0015))
                                                  .clamp(.1, 8.0),
                                              factor = next / zoom;
                                          final center = Offset(
                                              box.maxWidth / 2,
                                              box.maxHeight / 2);
                                          update(() {
                                            pan = (pan +
                                                        center -
                                                        event.localPosition) *
                                                    factor +
                                                event.localPosition -
                                                center;
                                            zoom = next;
                                          });
                                        });
                                      },
                                      child: GestureDetector(
                                          onDoubleTapDown: (d) {
                                            final id =
                                                hit(world(d.localPosition));
                                            if (id != null) textEdit(id);
                                          },
                                          child: CustomPaint(
                                              size: Size.infinite,
                                              painter: _CanvasPainter(
                                                  scene!,
                                                  origin,
                                                  canvasScale,
                                                  c.selection,
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  guides,
                                                  marquee,
                                                  rotating: shapeRotating,
                                                  editable: !c.protected))))))),
                      if (inlineId != null)
                        inlineEditor(box.maxWidth, box.maxHeight),
                      if (outside.isNotEmpty || wideText > 0)
                        Positioned(
                            top: 8,
                            right: 18,
                            child: Tooltip(
                                message: outside
                                    .map((e) => c.doc.node(e.key)?.name ?? '')
                                    .join('、'),
                                child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                        '适配提示 · ${outside.length} 项越界${wideText > 0 ? ' · $wideText 项文字过宽' : ''}',
                                        style:
                                            const TextStyle(fontSize: 12))))),
                    ]);
                  })),
        SizedBox(
            height: 60,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: Row(children: [
                  Tooltip(
                      message: '适配检查不裁改原照片。Alt + 滚轮缩放，空格 + 拖动平移',
                      child: SizedBox(
                          width: 136,
                          child: PrototypeSelect(
                              value: previewMode,
                              options: const {
                                'original': '原图',
                                'landscape': '横图检查',
                                'portrait': '竖图检查',
                                'square': '方图检查'
                              },
                              onChanged: (v) {
                                finishInline();
                                finishInline();
                                c.end();
                                update(() {
                                  previewMode = v;
                                  c.doc.switchLayout(
                                      StyleDocument.orientation(ratio));
                                });
                              }))),
                  const SizedBox(width: 8),
                  // 提示文字占满剩余空间，缩放比例和“适合窗口”才会紧贴右侧。
                  Expanded(
                      child: Text('Alt 滚轮 · 空格拖动',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).hintColor))),
                  Text('${(zoom * 100).round()}%',
                      style: const TextStyle(fontSize: 12)),
                  TextButton(
                      onPressed: () => update(() {
                            zoom = 1;
                            pan = Offset.zero;
                          }),
                      child: const Text('适合窗口', style: TextStyle(fontSize: 12)))
                ])))
      ]);
  Widget inlineEditor(double width, double height) {
    final n = c.doc.node(inlineId!)!, r = scene!.bounds[n.id];
    if (r == null) return const SizedBox.shrink();
    final w = (r.width * canvasScale + 24)
            .clamp(180.0, math.max(180.0, width - 20)),
        p = origin + r.topLeft * canvasScale;
    return Positioned(
        left: (p.dx - 7).clamp(8.0, math.max(8.0, width - w - 8)),
        top: (p.dy - 6).clamp(8.0, math.max(8.0, height - 130)),
        width: w.toDouble(),
        child: Material(
            elevation: 8,
            color: Color(c.doc.background),
            borderRadius: BorderRadius.circular(4),
            child: Focus(
                onKeyEvent: (_, e) {
                  if (e is! KeyDownEvent) return KeyEventResult.ignored;
                  if (e.logicalKey == LogicalKeyboardKey.escape) {
                    finishInline(cancel: true);
                    return KeyEventResult.handled;
                  }
                  if (e.logicalKey == LogicalKeyboardKey.enter && ctrl) {
                    finishInline();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: inlineInput,
                      focusNode: inlineFocus,
                      maxLines: null,
                      minLines: 1,
                      onTapOutside: (_) => finishInline(),
                      style: artworkTextStyle(n.font).copyWith(
                          fontSize: math.max(14, n.fontSize * canvasScale),
                          letterSpacing: n.spacing * canvasScale,
                          color: Color(n.color)),
                      decoration: const InputDecoration(
                          contentPadding: EdgeInsets.all(7))),
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 4),
                      color: const Color(0xff30291f),
                      child: const Text('Enter 换行 · Ctrl+Enter 完成 · Esc 取消',
                          style: TextStyle(color: Colors.white, fontSize: 11)))
                ]))));
  }
}

/// The artwork covers the shadow's interior. Selection and guides remain above.
class _CanvasShadowPainter extends CustomPainter {
  final Size artworkSize;
  final Offset origin;
  final double scale;
  _CanvasShadowPainter(this.artworkSize, this.origin, this.scale);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    canvas.drawShadow(
        Path()..addRect(Offset.zero & artworkSize), Colors.black, 15, true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CanvasShadowPainter oldDelegate) =>
      artworkSize != oldDelegate.artworkSize ||
      origin != oldDelegate.origin ||
      scale != oldDelegate.scale;
}

class _CanvasPainter extends CustomPainter {
  final StyleScene scene;
  final Offset origin;
  final double scale;
  final Set<String> selection;
  final Color accent;
  final List<(bool, double)> guides;
  final Rect? marquee;
  final bool rotating, editable;
  _CanvasPainter(this.scene, this.origin, this.scale, this.selection,
      this.accent, this.guides, this.marquee,
      {this.rotating = false, this.editable = true});

  void _paintShapeGrips(Canvas canvas, StyleNode n, Paint pen) {
    final s = n.shape, center = scene.geometry.point(n);
    Offset world(Offset local) => shapeToWorld(center, s.rotation, local);
    final fill = Paint()..color = Colors.white;
    final rotateAt = world(shapeRotateGrip(s, 30 / scale));
    canvas.drawLine(world(shapeRotateGrip(s, 0)), rotateAt, pen);
    canvas.drawCircle(rotateAt, 5.5 / scale, fill);
    canvas.drawCircle(rotateAt, 5.5 / scale, pen);
    if (rotating) return;
    for (final grip in shapeGrips(s, 16 / scale)) {
      final at = world(grip.local);
      if (grip.type == 'size') {
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate(s.rotation * math.pi / 180);
        final box = Rect.fromCenter(
            center: Offset.zero, width: 7 / scale, height: 7 / scale);
        canvas.drawRect(box, fill);
        canvas.drawRect(box, pen);
        canvas.restore();
      } else {
        canvas.drawCircle(at, 5 / scale, Paint()..color = const Color(0xffd7aa59));
        canvas.drawCircle(
            at,
            5 / scale,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2 / scale);
      }
    }
  }
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    final pen = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / scale;
    Rect? union;
    for (final id in selection) {
      final r = scene.objectBounds(id);
      if (r == null) continue;
      union = union == null ? r : union.expandToInclude(r);
      final isShape = scene.document.node(id)?.type == 'shape';
      // 旋转过程中隐藏选择框，松手后重新显示外接矩形。
      if (!(rotating && isShape)) canvas.drawRect(r.inflate(4 / scale), pen);
    }
    final single =
        selection.length == 1 ? scene.document.node(selection.first) : null;
    if (single != null &&
        single.type == 'shape' &&
        editable &&
        scene.bounds.containsKey(single.id)) {
      _paintShapeGrips(canvas, single, pen);
    }
    if (union != null &&
        selection.length == 1 &&
        single != null &&
        single.type != 'shape') {
      canvas.drawRect(
          Rect.fromCenter(
              center: union.bottomRight, width: 7 / scale, height: 7 / scale),
          Paint()..color = accent);
    }
    if (union != null && selection.length > 1)
      canvas.drawRect(union.inflate(7 / scale), pen);
    for (final line in guides) {
      if (line.$1) {
        canvas.drawLine(Offset(line.$2, 0),
            Offset(line.$2, scene.geometry.size.height), pen);
      } else {
        canvas.drawLine(Offset(0, line.$2),
            Offset(scene.geometry.size.width, line.$2), pen);
      }
    }
    if (marquee != null) {
      canvas.drawRect(marquee!, Paint()..color = accent.withValues(alpha: .1));
      canvas.drawRect(marquee!, pen);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) => true;
}
