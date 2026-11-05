# LumaCraft 0.3.2 · 连续色条与 HSB 取色板

版本：0.3.2+13。日期：2026-11-04。

## 本次修复与新增
- 连续色条改为一次绘制六段颜色，消除各色块单独抗锯齿在小数位置与缩放时产生的细缝。整体圆角、描边、不透明度保持原有功能。
- 点击文字颜色、背景颜色或描边颜色旁的圆角方块，可打开共用HSB取色板。
- 取色板提供饱和度/亮度二维区域、色相条、H/S/B数值及HEX输入；H/S/B数值继续支持鼠标拖动。
- 同时显示原颜色与当前颜色，调整时实时预览。确定产生一次撤销；取消、Esc或点击外部恢复原色。
- 多选不同颜色显示“多个值”，确认后统一应用，取消时逐项恢复原来的颜色。
- 颜色方块使用4px小圆角、细描边与40px点击区域，沿用明暗主题。
- 取色预览期间暂停草稿自动保存；关闭后保存最终确认或恢复的状态。防止关闭时的失焦回调再次写入已取消颜色。
- 打开前先完成原属性输入框的失焦提交，避免延迟回调提前结束取色事务；正在键入HEX时点击颜色方块也能正确取消和撤销。

## 使用
程序：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.3.2/lumacraft.exe。
完整包：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.3.2-windows-x64.zip。
保留全部DLL与data文件夹。旧版本保留，原照片不修改。

## 文件清单
- D:/AI Agent/LumaCraft/app/lib/editor/palette_render.dart：色条连续绘制。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/hsb_color_picker.dart：新增HSB取色板、圆角颜色方块。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_panels.dart：共用颜色入口、多选及预览/确认/取消事务。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart：取色预览期间暂停自动保存。
- D:/AI Agent/LumaCraft/app/test/hsb_picker_test.dart：HSB/HEX同步、取色面、确认撤销、取消及Esc恢复。
- D:/AI Agent/LumaCraft/app/test/palette_core_test.dart：小数缩放及不透明度下整条像素接缝检查。
- D:/AI Agent/LumaCraft/app/test/editor_core_test.dart：真实面板颜色入口、预览草稿隔离及确认撤销。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号。
- 本说明、D:/AI Agent/LumaCraft/app/docs/superpowers/plans/2026-11-04-hsb-color.md、D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：计划与交付记录。

## 验证
色条检查先复现拼接处alpha114而内部应为128，修复后整条内部alpha一致。
HSB检查覆盖颜色模型和HEX同步、取色面、数字键入、非法HEX、实时预览、确定单次撤销、取消和Esc恢复；实际编辑器检查确认预览颜色不会自动写入草稿。
最终六项核心检查全部通过，日志：D:/AI Agent/LumaCraft/app/build/hsb-color-check.log。代码检查无问题，编译结果及只读审查记录见technical-validation.md。
其余真实照片与鼠标体验交用户试用。已确认的260ms模式切换和数值拖动保持现有方案。
