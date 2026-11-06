import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft/ui/app_theme.dart';
import 'package:lumacraft/ui/editor/prototype_controls.dart';
import 'package:lumacraft/ui/workspace_dialog.dart';

/// 检查文字和它的底色差得够不够，浅色模式下尤其容易出问题。
///
/// 按用户 2026-11-06 决定：这个测试**只报告、不拦截**。不合格的会打印出来，
/// 但不会让整套测试失败——有些地方是设计上有意为之（如邮戳预览的浅色纸），
/// 强行拦截会误伤。发现新的不合格项时，人工确认是 bug 还是正常设计。
void main() {
  // WCAG AA 对正文的最低要求。
  const minimum = 4.5;

  double _luminance(Color color) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  double contrast(Color a, Color b) {
    final la = _luminance(a), lb = _luminance(b);
    final hi = math.max(la, lb), lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// 把界面上每一段文字都取出来，和**它实际所在的底色**比一比。
  ///
  /// 只用主题里的颜色判断，不渲染截图：这样跑得快，也不受字体渲染影响。
  /// 关键是每个前景色必须配上它真正的背景，否则算出来是假的
  /// （比如按钮上的文字要配按钮底色，不是面板块底色）。
  void check(String label, ThemeData theme) {
    final scheme = theme.colorScheme;
    final panel = theme.dialogTheme.backgroundColor ?? scheme.surface;
    final fill = theme.inputDecorationTheme.fillColor ?? panel;
    final card = scheme.surfaceContainerHighest;
    final page = theme.scaffoldBackgroundColor;
    // (说明, 前景色, 背景色)
    final pairs = <(String, Color, Color)>[
      ('正文', scheme.onSurface, panel),
      ('正文 · 卡片底', scheme.onSurface, card),
      ('正文 · 输入框底', scheme.onSurface, fill),
      ('正文 · 页面底', scheme.onSurface, page),
      ('次级文字',
          scheme.onSurface.withValues(alpha: EditorTypography.dimOpacity),
          panel),
      ('次级文字 · 卡片底',
          scheme.onSurface.withValues(alpha: EditorTypography.dimOpacity),
          card),
      ('强调色当文字', scheme.primary, panel),
      // 按钮上的文字要配按钮底色。
      ('强调按钮文字', scheme.onPrimary, scheme.primary),
      ('半透明文字 · 输入框', scheme.onSurface.withValues(alpha: .82), fill),
    ];
    for (final (name, color, background) in pairs) {
      // 半透明文字先和底色混合，再比较，否则算出来偏高。
      final blended =
          color.a < 1 ? Color.alphaBlend(color, background) : color;
      final ratio = contrast(blended, background);
      if (ratio < minimum) {
        // 只打印，不 fail。
        // ignore: avoid_print
        print('CONTRAST 不足 $label / $name = '
            '${ratio.toStringAsFixed(2)}:1（要求 ≥ $minimum:1）');
      }
    }
  }

  test('浅色与深色主题的文字对比度', () {
    check('深色', workspaceTheme(true));
    check('浅色', workspaceTheme(false));
  });

  testWidgets('浅色模式面板里没有漏掉颜色的文字', (tester) async {
    // 保存预设面板曾出现白字压浅底。这里在浅色主题下打开一个真实面板，
    // 逐个检查每段文字最终拿到的颜色是否和面板底色撞了。
    await tester.pumpWidget(MaterialApp(
        theme: workspaceTheme(false),
        home: Builder(
            builder: (context) => Scaffold(
                body: Center(
                    child: TextButton(
                        onPressed: () => showDialog<void>(
                            context: context,
                            builder: (ctx) => const WorkspaceDialog(
                                    title: Text('保存预设'),
                                    content: Text('选择新建，或选择一个用户预设覆盖保存'),
                                    actions: [TextButton(onPressed: null, child: Text('取消'))])),
                        child: const Text('打开')))))));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final background = workspaceTheme(false).dialogTheme.backgroundColor ??
        workspaceTheme(false).colorScheme.surface;
    // 只检查面板正文里的文字；按钮自带底色，不能拿面板块底色去比。
    for (final element in find.byType(Text).evaluate()) {
      final widget = element.widget as Text;
      if (widget.data == '取消') continue; // 按钮文字，底色是按钮不是面板
      final style = widget.style;
      final inherited = DefaultTextStyle.of(element);
      final color = style?.color ?? inherited.style.color;
      if (color == null) continue;
      final blended = color.a < 1 ? Color.alphaBlend(color, background) : color;
      final ratio = contrast(blended, background);
      if (ratio < minimum) {
        // ignore: avoid_print
        print('CONTRAST 面板文字「${widget.data}」= '
            '${ratio.toStringAsFixed(2)}:1（要求 ≥ $minimum:1）');
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}
