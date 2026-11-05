import 'package:flutter/material.dart';

const dialogActionStyle = TextStyle(
    fontFamily: 'Microsoft YaHei UI',
    fontFamilyFallback: ['Microsoft YaHei', 'Segoe UI'],
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0);

class WorkspaceActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool danger;
  const WorkspaceActionButton(
      {super.key, required this.label, this.onPressed, this.danger = false});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final red = dark ? const Color(0xffefb0a6) : const Color(0xffa84d43);
    return SizedBox(
        height: 40,
        child: TextButton(
            style: TextButton.styleFrom(
                textStyle: dialogActionStyle,
                foregroundColor: danger ? red : scheme.onSurface,
                backgroundColor: danger
                    ? red.withValues(alpha: dark ? .14 : .12)
                    : scheme.surfaceContainerHighest,
                disabledForegroundColor:
                    scheme.onSurface.withValues(alpha: .35),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6))),
            onPressed: onPressed,
            child: Text(label, style: dialogActionStyle)));
  }
}

const dialogBodyStyle = TextStyle(
    fontFamily: 'Microsoft YaHei UI',
    fontFamilyFallback: ['Microsoft YaHei', 'Segoe UI'],
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0);
const dialogTitleStyle = TextStyle(
    fontFamily: 'Microsoft YaHei UI',
    fontFamilyFallback: ['Microsoft YaHei', 'Segoe UI'],
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0);

class WorkspaceDialog extends AlertDialog {
  const WorkspaceDialog({super.key, super.title, super.content, super.actions})
      : super(
            titleTextStyle: dialogTitleStyle,
            contentTextStyle: dialogBodyStyle);
}

class WorkspaceTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? error;
  final int? maxLength;
  final bool autofocus;
  const WorkspaceTextField(
      {super.key,
      required this.label,
      required this.controller,
      this.error,
      this.maxLength,
      this.autofocus = false});
  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label,
                style: dialogBodyStyle.copyWith(
                    fontSize: 13, color: Theme.of(context).hintColor)),
            const SizedBox(height: 8),
            TextField(
                controller: controller,
                autofocus: autofocus,
                maxLength: maxLength,
                style: dialogBodyStyle,
                decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                    counterText: '')),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(error!,
                      style: dialogBodyStyle.copyWith(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error))),
          ]);
}
