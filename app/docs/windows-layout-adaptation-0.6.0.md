# LumaCraft 0.6.0 · 横竖独立布局

版本 0.6.0+23，2026-11-05。仅输出可运行文件夹，不生成压缩包。

## 使用

编辑模式 → 右侧“画布” → “布局适配”。默认统一布局，旧预设保持原来效果。启用“横竖独立”后，可编辑通用、横图、竖图布局。主画布上方同步显示当前布局，面板显示是否已独立设置。

- 内容、字体、颜色、不透明度、图片素材、背景、投影、打孔样式及图层结构共用。
- 组件位置、锚点、字号、文字对齐、字间距、色卡尺寸/间距/圆角/缩放、图片宽度、可见性、四边边框及联动状态可分别设置。分组可见性也分别设置。
- 未设置的横竖参数跟随通用布局；方图使用通用布局。修改通用参数会更新仍在跟随的项目。
- “从通用复制”用当前通用参数生成独立快照；“恢复通用”移除当前方向差异并重新跟随。均可撤销。
- 添加、删除、分组、排序在所有布局共用；复制组件带上各个方向的尺寸与位置，并作小幅位置偏移。
- 底部构图检查用于模拟，不修改原始照片或实际导出比例。组件越界、文字宽于画布会提示，不自动移动或缩小。
- 保存预设时可选横竖通用、横图优先、竖图优先标记，预设面板可按标记筛选。标记不限制应用对象。
- 草稿、预设、照片样式和 .lmp 均保存配置。分享包声明 adaptiveLayout 能力，不支持的旧软件会拒绝导入，避免静默丢失布局。

## 修改文件

- D:/AI Agent/LumaCraft/app/lib/editor/style_document.dart：共享基础、方向差异、布局解析、继承、复制与序列化。
- D:/AI Agent/LumaCraft/app/lib/editor/editor_controller.dart：复制组件和组时保留方向布局。
- D:/AI Agent/LumaCraft/app/lib/editor/style_render.dart：预览和导出共用方向解析，编辑画布使用当前正在编辑的布局。
- D:/AI Agent/LumaCraft/app/lib/editor/preset_package.dart：分享能力声明和方向布局严格校验。
- D:/AI Agent/LumaCraft/app/lib/editor/preset_store.dart：构图筛选状态。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart：加载方向、保存构图标记。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_panels.dart：布局适配控件、状态说明、复制/恢复，以及载入预设时选择方向。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_canvas.dart：构图检查切换方向、当前布局标记及越界提示。
- D:/AI Agent/LumaCraft/app/lib/ui/preset_panel.dart：共用构图筛选与卡片标记。
- D:/AI Agent/LumaCraft/app/test/layout_adaptation_test.dart：核心流程和界面验证。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号。
- D:/AI Agent/LumaCraft/app/docs/superpowers/plans/2026-11-05-layout-adaptation.md：已确认方案。
- 本说明、D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：交付记录。

## 验证与边界

三项新增核心验证通过：独立编辑/共享属性/复制撤销/保存重开/离线分享；横竖方三种照片真实 PNG 导出与预览尺寸一致；布局控件切换和恢复。受影响的九项既有编辑与预设验证通过。发现并修复布局复制映射类型问题，失败项重跑通过。

最终界面控件验证通过，使用实际微软雅黑字体生成截图核对标签、字号、输入框、说明和按钮间距。代码分析无问题，Windows release 编译成功。未将控件截图检查等同于所有 Windows 缩放比例下的人工体验检查，具体手感交用户试用。

日志：D:/AI Agent/LumaCraft/app/build/layout-adaptation-test.log（首轮含失败记录）、layout-adaptation-recheck.log（核心修复后通过）、layout-ui-check-final.log（最终控件通过）、layout-adaptation-windows-final.log（最终编译）。后面三个文件同在该 build 目录。

程序：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.6.0/lumacraft.exe。整个文件夹共同使用，不单独移动 EXE；旧版本保留。
