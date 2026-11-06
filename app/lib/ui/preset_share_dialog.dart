import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';

import '../editor/preset_code.dart';
import '../editor/style_document.dart';
import '../editor/style_render.dart';
import 'editor/prototype_controls.dart';
import 'workspace_dialog.dart';

/// Result of the share panel: the user may have exported a `.lmp` file.
class SharePresetResult {
  final bool exported;
  const SharePresetResult({this.exported = false});
}

/// One panel for every way of handing a preset to someone else.
///
/// A `.lmp` file carries everything, including the picture markers. A code
/// carries the same preset without the pictures, which is what makes it small
/// enough for a QR code (measured: 424 characters for a plain frame).
Future<SharePresetResult?> showSharePreset(
        BuildContext context,
        {required StyleDocument style,
        required ui.Image? photo,
        required String? photoPath,
        required Map<String, String> fields,
        required Future<bool> Function() exportLmp}) =>
    showDialog<SharePresetResult>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => _SharePresetDialog(
            style: style,
            photo: photo,
            photoPath: photoPath,
            fields: fields,
            exportLmp: exportLmp));

class _SharePresetDialog extends StatefulWidget {
  final StyleDocument style;
  final ui.Image? photo;
  final String? photoPath;
  final Map<String, String> fields;

  /// Writes the `.lmp` file and reports whether it was really saved.
  final Future<bool> Function() exportLmp;
  const _SharePresetDialog(
      {required this.style,
      required this.photo,
      required this.photoPath,
      required this.fields,
      required this.exportLmp});
  @override
  State<_SharePresetDialog> createState() => _SharePresetDialogState();
}

class _SharePresetDialogState extends State<_SharePresetDialog> {
  /// Fixed proportions. The panel must look the same whatever shape the app
  /// window has, so it is laid out at one size and scaled down whole when the
  /// screen is smaller — never stretched.
  static const panelWidth = 1090.0;
  static const panelHeight = 732.0;
  static const cornerRadius = 14.0;
  static const sideWidth = 360.0;
  static const gap = 30.0;

  /// Off by default: a code with pictures never fits in a QR code, so the
  /// panel opens ready to scan instead of showing a size error.
  bool includeImages = false;
  String code = '';
  String? codeError;
  String? notice;
  bool copied = false;
  bool busy = false;

  /// True only for the instant the picture is taken. Some things belong on
  /// screen but not in a file sent to someone else: the marker switch is a
  /// control, and the paste hint only matters while this window is open.
  bool capturing = false;
  final captureKey = GlobalKey();

  bool get dark => Theme.of(context).brightness == Brightness.dark;

  /// Panels separate their areas with faint fills, not outlines: a screen full
  /// of hairlines reads as clutter.
  Color get softFill => Theme.of(context)
      .colorScheme
      .onSurface
      .withValues(alpha: dark ? .055 : .045);

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  void _rebuild() {
    try {
      final built =
          encodePresetCode(widget.style, includeImages: includeImages);
      setState(() {
        code = built;
        codeError = null;
      });
    } catch (e) {
      setState(() {
        code = '';
        codeError = '这个预设暂时无法生成文本代码：$e';
      });
    }
  }

  int get codeBytes => presetCodeBytes(code);
  bool get tooLarge => code.isNotEmpty && presetCodeTooLarge(code);

  String get bytesLabel {
    if (code.isEmpty) return '';
    final size = codeBytes < 1024
        ? '$codeBytes 字节'
        : '${(codeBytes / 1024).toStringAsFixed(1)} KB';
    return '${code.length} 字符 · $size';
  }

  Future<void> copyCode() async {
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() {
      copied = true;
      notice = '已复制完整代码，可以直接发给对方';
    });
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => copied = false);
  }

  /// Captures everything above the action bar. The bottom corners are rounded
  /// afterwards on the pixels: on screen that edge is mid-panel and square,
  /// but the saved picture ends there and must look like a finished card.
  Future<Uint8List?> _capture() async {
    final boundary =
        captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final ratio = math.max(2.0, MediaQuery.of(context).devicePixelRatio);
    final image = await boundary.toImage(pixelRatio: ratio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      return _roundBottomCorners(
          data.buffer.asUint8List(), (cornerRadius * ratio).round());
    } finally {
      image.dispose();
    }
  }

  Future<void> saveImage() async {
    setState(() {
      busy = true;
      notice = null;
      // Hide the controls and the paste hint for the capture, then put them
      // back; the saved picture should not carry UI chrome.
      capturing = true;
    });
    Uint8List? bytes;
    try {
      // Let the frame with the hidden widgets render before taking the shot.
      await WidgetsBinding.instance.endOfFrame;
      bytes = await _capture();
    } catch (e) {
      if (mounted) setState(() => notice = '保存图片失败：$e');
    } finally {
      if (mounted) setState(() => capturing = false);
    }
    try {
      if (bytes == null || !mounted) return;
      final name = widget.style.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final location = await getSaveLocation(
          suggestedName: '$name-分享.png',
          acceptedTypeGroups: const [
            XTypeGroup(label: 'PNG 图片', extensions: ['png'])
          ]);
      // Cancelling the save dialog keeps this panel open, same as exporting.
      if (location == null) return;
      final path = location.path.toLowerCase().endsWith('.png')
          ? location.path
          : '${location.path}.png';
      await File(path).writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      // A file really landed on disk: close the panel like the .lmp export.
      Navigator.pop(context, const SharePresetResult(exported: true));
    } catch (e) {
      if (mounted) setState(() => notice = '保存图片失败：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> exportLmpFile() async {
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final written = await widget.exportLmp();
      // Only close when a file was written; cancelling that dialog must leave
      // this panel where it was.
      if (written && mounted)
        Navigator.pop(context, const SharePresetResult(exported: true));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
        backgroundColor: scheme.surface,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(cornerRadius)),
        child: FittedBox(
            // Whole-panel scaling keeps the proportions on a small screen
            // instead of squeezing the columns.
            fit: BoxFit.scaleDown,
            child: SizedBox(
                width: panelWidth,
                height: panelHeight,
                child: DefaultTextStyle(
                    style: dialogBodyStyle.copyWith(color: scheme.onSurface),
                    child: Column(children: [
                      // Everything above the action row goes into the saved
                      // picture; the row itself is deliberately outside.
                      Expanded(
                          child: RepaintBoundary(
                              key: captureKey,
                              child: DecoratedBox(
                                  decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: dark
                                              ? const [
                                                  Color(0xff2b2a27),
                                                  Color(0xff232221)
                                                ]
                                              : const [
                                                  Color(0xfffaf7f2),
                                                  Color(0xfff4f0e9)
                                                ])),
                                  child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          28, 22, 28, 22),
                                      child: Column(children: [
                                        _header(),
                                        const SizedBox(height: 18),
                                        Expanded(child: _body())
                                      ]))))),
                      _actions()
                    ])))));
  }

  /// Brand left, the panel title centred on the panel (not on the leftover
  /// space), then the marker switch and the preset chip on the right.
  ///
  /// The three outer slots share the width equally, so the middle slot sits
  /// exactly over the centre line however wide the brand or the right group
  /// gets. The switch keeps a reserved slot while capturing instead of being
  /// removed, so hiding it cannot shift the right-hand group.
  Widget _header() {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(child: Align(alignment: Alignment.centerLeft, child: _brand())),
      Expanded(
          child: Center(
              child: Text('分享预设',
                  style: dialogTitleStyle.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.2)))),
      Expanded(
          child: Align(
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Opacity(opacity: capturing ? 0 : 1, child: _imageSwitch()),
                const SizedBox(width: 16),
                Flexible(child: _titleChip())
              ])))
    ]);
  }

  Widget _brand() {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      // Enlarged: the mark is the first thing read in the corner, so it carries
      // the identity on its own now that the bottom strip is gone.
      ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.asset('assets/branding/lumacraft-icon-1024.png',
              width: 44, height: 44, filterQuality: FilterQuality.high)),
      const SizedBox(width: 13),
      Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('LumaCraft',
                style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    letterSpacing: .9,
                    color: scheme.onSurface)),
            const SizedBox(height: 3),
            Text('框印工坊',
                style: TextStyle(
                    fontSize: 12,
                    height: 1.15,
                    letterSpacing: 2.7,
                    color: scheme.onSurface
                        .withValues(alpha: EditorTypography.dimOpacity)))
          ])
    ]);
  }

  /// The preset being shared, as a chip against the right edge.
  Widget _titleChip() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: softFill, borderRadius: BorderRadius.circular(6)),
        child: Text(widget.style.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                letterSpacing: .1,
                color: scheme.onSurface
                    .withValues(alpha: EditorTypography.dimOpacity))));
  }

  Widget _imageSwitch() {
    final scheme = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('包含图片标识',
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              letterSpacing: .1,
              color: scheme.onSurface)),
      const SizedBox(width: 6),
      SizedBox(
          height: 21,
          child: FittedBox(
              fit: BoxFit.contain,
              child: Switch(
                  value: includeImages,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) {
                    setState(() => includeImages = v);
                    _rebuild();
                  }))),
      const SizedBox(width: 7),
      Tooltip(
          message: includeImages
              ? '带上图片后预设会变很大，二维码装不下'
              : '关闭时对方拿到空白图片位，可自己替换',
          child: Icon(Icons.info_outline_rounded,
              size: 14, color: scheme.onSurface.withValues(alpha: .38)))
    ]);
  }

  /// Columns share one top edge, so the preview and the QR card line up.
  Widget _body() =>
      Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: _preview()),
        const SizedBox(width: gap),
        SizedBox(width: sideWidth, child: _sideColumn())
      ]);

  Widget _preview() {
    final scheme = Theme.of(context).colorScheme;
    final photo = widget.photo;
    return Container(
        decoration: BoxDecoration(
            // A soft block instead of an outline: the photo sits in a pool of
            // slightly different tone, which reads calmer than a frame.
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [Color(0xff333230), Color(0xff292826)]
                    : const [Color(0xfff1ece2), Color(0xffe9e3d8)]),
            borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.all(26),
        child: Center(
            child: photo == null
                ? Icon(Icons.image_outlined,
                    size: 40, color: scheme.onSurface.withValues(alpha: .28))
                : Container(
                    decoration: BoxDecoration(boxShadow: [
                      // Soft and low: two wide, faint layers read as light
                      // falling on paper, not as a black halo.
                      BoxShadow(
                          color:
                              Colors.black.withValues(alpha: dark ? .18 : .07),
                          blurRadius: 10,
                          offset: const Offset(0, 3)),
                      BoxShadow(
                          color:
                              Colors.black.withValues(alpha: dark ? .16 : .055),
                          blurRadius: 26,
                          spreadRadius: 2,
                          offset: const Offset(0, 9))
                    ]),
                    child: FittedBox(
                        child: SizedBox(
                            width: photo.width.toDouble(),
                            height: photo.height.toDouble(),
                            child: StylePreview(
                                photo: photo,
                                photoPath: widget.photoPath,
                                document: widget.style,
                                fields: widget.fields))))));
  }

  /// Right column: the QR card starts on the same line as the preview and the
  /// code block ends on the same line as the preview.
  ///
  /// The only flexible gap sits around the divider, so the two regions are
  /// pushed apart just enough to read as separate blocks. Everything else is a
  /// fixed gap, which keeps the grouping stable whatever the window height is.
  Widget _sideColumn() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _qrCard(),
        const SizedBox(height: 14),
        _caption(),
        Expanded(child: Center(child: _divider())),
        // Kept in the saved picture: without it the space above the code box
        // reads as a gap rather than a caption.
        _codeHint(),
        const SizedBox(height: 10),
        _codeLabel(),
        const SizedBox(height: 9),
        _codeBox()
      ]);

  /// A hairline that separates the two ways of sharing without becoming a
  /// visual object of its own.
  ///
  /// Fades out at both ends so the line does not butt against the panel edges
  /// — a hard-ended rule reads as a table border, while a faded one reads as a
  /// quiet break between two groups.
  Widget _divider() {
    final line =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: dark ? .13 : .15);
    return Container(
        height: 1,
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
          line.withValues(alpha: 0),
          line,
          line,
          line.withValues(alpha: 0)
        ], stops: const [0, .18, .82, 1])));
  }

  Widget _caption() {
    final scheme = Theme.of(context).colorScheme;
    final base = EditorTypography.hint(context)
        .copyWith(fontSize: 12, height: 1.5, letterSpacing: .1);
    if (tooLarge)
      return Text('体积超出二维码容量', textAlign: TextAlign.center, style: base);
    return Text.rich(
        TextSpan(children: [
          TextSpan(text: '用', style: base),
          // The product name is the one thing here worth remembering, so it
          // carries the accent colour and a heavier weight.
          TextSpan(
              text: '框印工坊',
              style: base.copyWith(
                  fontWeight: FontWeight.w700, color: scheme.primary)),
          TextSpan(text: '扫码导入', style: base)
        ]),
        textAlign: TextAlign.center);
  }

  Widget _codeHint() => Text('在导入预设时粘贴这段代码即可使用',
      style: EditorTypography.hint(context).copyWith(fontSize: 11.5, height: 1.6));
  Widget _codeLabel() {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Text('文本代码',
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: .3,
              color: scheme.onSurface)),
      const Spacer(),
      Text(bytesLabel,
          style: EditorTypography.hint(context).copyWith(fontSize: 11.5))
    ]);
  }

  /// White card behind the code.
  ///
  /// Tried bare modules in the theme colour for a while: it looked airier but
  /// weaker, and a white code on a dark panel is also the harder case for
  /// scanners. Back to a plain white face with no shadow and no outline — the
  /// contrast against the panel already separates it.
  ///
  /// The card is a square and the grid is sized from the card itself, so the
  /// Builds the code at the full available size.
  ///
  /// An earlier attempt shrank the grid to a whole number of pixels per
  /// module. It read marginally better but left a dense code visibly small
  /// with a wide white ring around it, which looked wrong. Instead the grid
  /// fills the card and the painter snaps each module edge to a pixel, so the
  /// squares stay crisp without giving up the size.
  ///
  /// White card behind the code.
  ///
  /// Tried bare modules in the theme colour for a while: it looked airier but
  /// weaker, and a white code on a dark panel is also the harder case for
  /// scanners. Back to a plain white face with no shadow and no outline — the
  /// contrast against the panel already separates it.
  ///
  /// The card is a square and the grid is sized from the card itself, so the
  /// quiet zone is the same on all four sides.
  Widget _qrCard() {
    final usable = code.isNotEmpty && !tooLarge;
    return AspectRatio(
        aspectRatio: 1,
        child: Container(
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.all(14),
            child: Center(
                child: usable
                    ? LayoutBuilder(
                        builder: (context, box) {
                          final side =
                              math.min(box.maxWidth, box.maxHeight);
                          return SizedBox.square(
                              dimension: side,
                              child: CustomPaint(painter: _QrPainter(code)));
                        })
                    : codeError != null
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(codeError!,
                                textAlign: TextAlign.center,
                                style: EditorTypography.hint(context)
                                    .copyWith(fontSize: 12)))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.qr_code_2_rounded,
                                  size: 46, color: Color(0xffa29b90)),
                              const SizedBox(height: 12),
                              Text('带图片标识的预设体积太大，\n装不进二维码',
                                  textAlign: TextAlign.center,
                                  style: EditorTypography.hint(context)
                                      .copyWith(
                                          fontSize: 12,
                                          height: 1.7,
                                          color: const Color(0xff6f6860)))
                            ]))));
  }

  /// The code itself with its copy button inside the same filled block.
  Widget _codeBox() {
    final scheme = Theme.of(context).colorScheme;
    final has = code.isNotEmpty;
    return Container(
        height: 46,
        decoration: BoxDecoration(
            color: Theme.of(context).inputDecorationTheme.fillColor,
            borderRadius: BorderRadius.circular(7)),
        child: Row(children: [
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.only(left: 13),
                  child: Text(has ? code : '—',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Consolas',
                          fontFamilyFallback: const [
                            'Courier New',
                            'monospace'
                          ],
                          fontSize: 12,
                          letterSpacing: .2,
                          color: scheme.onSurface
                              .withValues(alpha: has ? .86 : .35))))),
          if (has) ...[
            Container(
                width: 1,
                height: 22,
                color: scheme.onSurface.withValues(alpha: .08)),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: TextButton.icon(
                    onPressed: copied ? null : copyCode,
                    icon: Icon(
                        copied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 14),
                    label: Text(copied ? '已复制' : '复制',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    style: TextButton.styleFrom(
                        foregroundColor: scheme.primary,
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)))))
          ]
        ]));
  }

  /// Kept outside the capture: the saved picture ends above it, with rounded
  /// corners added to the pixels.
  Widget _actions() {
    final scheme = Theme.of(context).colorScheme;
    Widget accent(String label, VoidCallback? onPressed) => SizedBox(
        height: 40,
        child: FilledButton(
            style: FilledButton.styleFrom(
                textStyle: dialogActionStyle,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6))),
            onPressed: busy ? null : onPressed,
            child: Text(label)));
    return Container(
        padding: const EdgeInsets.fromLTRB(28, 15, 28, 19),
        decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(cornerRadius)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .26 : .07),
                  blurRadius: 18,
                  offset: const Offset(0, -4))
            ]),
        child: Row(children: [
          Expanded(
              child: Text(notice ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EditorTypography.hint(context).copyWith(
                      fontSize: 11.5,
                      color: notice == null
                          ? Colors.transparent
                          : scheme.primary))),
          const SizedBox(width: 12),
          accent('导出 .lmp', exportLmpFile),
          const SizedBox(width: 10),
          accent('保存图片', saveImage),
          const SizedBox(width: 10),
          accent('复制代码', code.isEmpty ? null : copyCode),
          const SizedBox(width: 12),
          WorkspaceActionButton(
              label: '取消', onPressed: () => Navigator.pop(context))
        ]));
  }
}

/// Clears the pixels outside the rounded bottom corners of a saved panel.
///
/// Capturing a widget inside the dialog cannot inherit the dialog's rounding,
/// and clipping on screen would notch the middle of the panel. Rounding the
/// finished pixels gives the saved card the corners it needs without changing
/// how the panel looks in the window.
Uint8List _roundBottomCorners(Uint8List png, int radius) {
  final image = img.decodePng(png);
  if (image == null || radius <= 0) return png;
  if (radius * 2 >= image.width || radius * 2 >= image.height) return png;
  // A capture without an alpha channel cannot be made transparent, so
  // convert first; the saved picture needs real transparency in the corners.
  final canvas = image.hasAlpha ? image : image.convert(numChannels: 4);
  final width = canvas.width, height = canvas.height;
  final cy = height - 1 - radius;
  for (var y = height - radius; y < height; y++) {
    final dy = y - cy;
    for (var x = 0; x < radius; x++) {
      final dx = x - radius;
      if (dx * dx + dy * dy > radius * radius)
        canvas.setPixelRgba(x, y, 0, 0, 0, 0);
      final rx = width - 1 - x - (width - 1 - radius);
      if (rx * rx + dy * dy > radius * radius)
        canvas.setPixelRgba(width - 1 - x, y, 0, 0, 0, 0);
    }
  }
  return Uint8List.fromList(img.encodePng(canvas));
}

/// Draws the module grid to fill the given square.
///
/// Each module's edges are snapped outward to whole device pixels with
/// anti-aliasing off: a half-covered pixel would blur the boundary, and a
/// dense code has almost no clean squares left. Snapping keeps the code at
/// full size — shrinking it to land on an integer grid made it look small.
class _QrPainter extends CustomPainter {
  final String data;
  _QrPainter(this.data);
  @override
  void paint(Canvas canvas, Size size) {
    final image = QrImage(QrCode(
        payload: QrPayload.fromString(data),
        errorCorrectLevel: QrErrorCorrectLevel.medium));
    final count = image.moduleCount;
    final paint = Paint()
      ..color = const Color(0xff14110d)
      ..isAntiAlias = false;
    final cell = math.min(size.width, size.height) / count;
    // Centre the grid in case the box is not exactly square.
    final originX = (size.width - cell * count) / 2;
    final originY = (size.height - cell * count) / 2;
    for (var y = 0; y < count; y++) {
      for (var x = 0; x < count; x++) {
        if (!image.isDark(y, x)) continue;
        // floor/ceil rather than a fixed overdraw: edges land on whole pixels
        // whatever the module size happens to be.
        final left = (originX + x * cell).floorToDouble();
        final top = (originY + y * cell).floorToDouble();
        final right = (originX + (x + 1) * cell).ceilToDouble();
        final bottom = (originY + (y + 1) * cell).ceilToDouble();
        canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter old) => old.data != data;
}
