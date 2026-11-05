# LumaCraft 0.6.2 · 构图角标底板微调

2026-11-05，版本 0.6.2+25。

采用用户看过样式截图后确认的参数：构图角标深色底板不透明度55%，边缘使用2.5px高斯柔化。只柔化底板，横图/竖图图标保持清晰，尺寸、位置和选择逻辑沿用0.6.1。

## 修改文件

- D:/AI Agent/LumaCraft/app/lib/ui/preset_panel.dart：角标底板拆为独立柔化背景层；不透明度0.55，模糊sigmaX/sigmaY均为2.5。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号0.6.2+25。
- 本说明、D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：记录确认参数和交付。
- D:/AI Agent/LumaCraft/app/build/badge-preview/preview_test.dart：样式预览工具，加载实际中文、衬线和图标字体，使用软件共用预设面板渲染截图；不随软件交付。

## 检查记录

确认截图：D:/AI Agent/LumaCraft/app/build/badge-preview/after-55-feather-2p5.png。
截图渲染检查通过；打包前代码分析无问题。最终编译日志：D:/AI Agent/LumaCraft/app/build/badge-feather-build-0.6.2.log。沿用已通过的预设核心流程，不扩大本次微调的测试范围。

## 使用

程序：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.6.2/lumacraft.exe。保留整个文件夹使用，不单独移动EXE。仅提供可运行文件夹，不额外生成压缩包，旧版本保留。
