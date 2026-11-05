part of 'editor_page.dart';

extension ImagePanel on _PresetEditorState {
  Future<ImageMark?> chooseImageMark() async {
    if (dialogOpen) return null;
    dialogOpen = true;
    try {
      final file = await openFile(acceptedTypeGroups: [
        const XTypeGroup(label: '图片标识', extensions: ['png', 'jpg', 'jpeg'])
      ]);
      if (file == null) return null;
      final mark = await importImageMark(file.path);
      await prepareImageMarks([mark]);
      return mark;
    } catch (e) {
      if (mounted) update(() => status = '图片导入失败：$e');
      return null;
    } finally {
      dialogOpen = false;
    }
  }

  Future<void> addImageMark() async {
    finishInline();
    FocusManager.instance.primaryFocus?.unfocus();
    FocusManager.instance.applyFocusChangesIfNeeded();
    c.end();
    final mark = await chooseImageMark();
    if (!mounted || mark == null) return;
    c.edit(() {
      final node = StyleNode(
          type: 'image',
          name: '图片标识',
          text: '',
          image: mark,
          anchor: c.doc.borders['bottom'] == 0 ? 'photo' : 'bottom');
      c.doc.nodes.add(node);
      c.doc.order.add(node.id);
      c.selection
        ..clear()
        ..add(node.id);
    });
    update(() => panel = 2);
  }

  Future<void> replaceImageMark(String id) async {
    FocusManager.instance.primaryFocus?.unfocus();
    FocusManager.instance.applyFocusChangesIfNeeded();
    c.end();
    final mark = await chooseImageMark();
    if (!mounted || mark == null) return;
    final node = c.doc.node(id);
    if (node == null || c.doc.locked(id)) return;
    c.edit(() {
      mark.width = node.image.width;
      node.image = mark;
    });
  }

  Widget imageProperties(StyleNode node) => section('图片素材', [
        if (imageMarkReady(node.image.data) && node.image.data.isNotEmpty)
          Container(
              height: 90,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Theme.of(context).inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(6)),
              child: Image.memory(base64Decode(node.image.data),
                  fit: BoxFit.contain, cacheWidth: 256)),
        const SizedBox(height: 10),
        Text(node.image.filename,
            overflow: TextOverflow.ellipsis,
            style: EditorTypography.hint(context)),
        if (marksError != null)
          Text(marksError!, style: EditorTypography.hint(context)),
        const SizedBox(height: 10),
        neutral('替换图片', () => replaceImageMark(node.id),
            icon: Icons.image_outlined),
        const SizedBox(height: 14),
        pair(
            numeric('宽度 px', node.image.width, (v) => node.image.width = v,
                min: 4, max: 2000),
            numeric('高度 px', node.image.width / node.image.ratio,
                (v) => node.image.width = (v * node.image.ratio).clamp(4, 2000),
                min: 4 / node.image.ratio, max: 2000 / node.image.ratio)),
        Text('锁定原始比例。支持透明 PNG；导入素材最长边保留至 2048 px，随样式保存。',
            style: EditorTypography.hint(context)),
        const SizedBox(height: 14),
        opacityControl([node]),
      ]);
}
