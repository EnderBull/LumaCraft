import 'package:flutter/material.dart';
import '../export/color_management.dart';
import 'workspace_dialog.dart';

class HeifInstallNotice extends StatelessWidget {
  final String message;
  const HeifInstallNotice(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message, textAlign: TextAlign.center, style: dialogBodyStyle),
        const SizedBox(height: 16),
        const HeifStoreButtons()
      ]));
}

class HeifStoreButtons extends StatelessWidget {
  const HeifStoreButtons({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget button(String label, String productId) => TextButton(
        style: TextButton.styleFrom(
            foregroundColor: scheme.onSurface,
            backgroundColor: scheme.surfaceContainerHighest,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
            textStyle: dialogActionStyle),
        onPressed: () => openMicrosoftStoreProduct(productId),
        child: Text(label, style: dialogActionStyle));
    return Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          button('安装 HEIF 图像扩展', heifStoreProductId),
          button('安装 HEVC 视频扩展', hevcStoreProductId)
        ]);
  }
}
