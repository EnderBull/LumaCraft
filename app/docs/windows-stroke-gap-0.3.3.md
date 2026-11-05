# LumaCraft 0.3.3 · 取色板排版与描边间距

版本：0.3.3+14。日期：2026-11-04。

## 本次调整
- H/S/B与HEX标签独立放在输入框上方，标签与框体间隔7px。H/S/B同排，数值框等高40px，单位与数值对齐；HEX错误提示单独显示在框体下方。
- 色卡启用描边后新增“描边间距”：0～10px，默认0，步进0.1，支持拖动与Alt精细调整。
- 间距为0保留原内描边；大于0时外移描边，中间露出透明空隙，显示下方背景或照片。
- 独立色块按包含描边的外轮廓计算色块间距，避免描边相撞；色块尺寸保持原值，整个组件仍围绕原锚点居中。
- 连续色条仅外轮廓留空隙。“每块描边”内部五条分隔线保持原位，六色仍连续相接。
- 选框、框选、对齐与吸附范围包含外侧描边。间距、描边粗细及外轮廓随整体缩放。
- 旧预设没有该属性时按0读取，保持原有外观。预设保存、撤销和导出沿用现有流程。

## 使用
色卡组件属性 → 启用描边 → 描边间距。
程序：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.3.3/lumacraft.exe。
完整包：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.3.3-windows-x64.zip。
保留全部DLL与data文件夹，旧版本保留。

## 文件清单
- D:/AI Agent/LumaCraft/app/lib/ui/editor/hsb_color_picker.dart：标签、输入框高度、间距和错误提示排版。
- D:/AI Agent/LumaCraft/app/lib/editor/palette_style.dart：描边间距属性、默认值、范围与存储。
- D:/AI Agent/LumaCraft/app/lib/editor/palette_render.dart：外侧描边环、透明间隙和组件边界。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/palette_panel.dart：描边间距输入与说明。
- D:/AI Agent/LumaCraft/app/test/palette_core_test.dart：四形态透明间隙、描边边界、连续色条及属性存储检查。
- D:/AI Agent/LumaCraft/app/test/hsb_picker_test.dart：标签与框体7px间隔、40px输入高度及取色流程。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号。
- 本说明、D:/AI Agent/LumaCraft/app/docs/superpowers/plans/2026-11-04-stroke-gap.md、D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：计划与交付记录。

## 验证
六项核心检查已通过，覆盖四种形态外描边的透明间隙、完整边界、填充尺寸、色条内部连续、默认值与范围，以及HSB排版/取色、数值拖动、编辑保存应用和EXIF导出。日志：D:/AI Agent/LumaCraft/app/build/stroke-gap-check.log。
最终代码检查、编译及只读审查记录见technical-validation.md；其余鼠标操作与视觉观感交用户试用。
