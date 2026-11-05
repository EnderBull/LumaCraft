# LumaCraft 0.2.5 · 修复编辑画布变暗

版本：0.2.5+10。日期：2026-11-04。

## 修复
共享画布拆分后，画布阴影曾留在照片上方的交互绘制层，导致照片内部被黑色阴影压暗。本次将阴影移到独立底层，照片在其上方绘制；选择框、缩放手柄、框选和辅助线仍在最上方。

用户已确认过渡动画效果。保留现有侧栏轻滑加淡入淡出、260 毫秒时长和画布适配，不修改动画。下拉菜单继续无动画。

## 使用
程序：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.2.5/lumacraft.exe。
完整包：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.2.5-windows-x64.zip。
保留同目录全部 DLL 和 data 文件夹。旧版不删除，原照片不修改。

## 文件清单
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_canvas.dart：阴影、照片、交互辅助标记的绘制层级。
- D:/AI Agent/LumaCraft/app/test/editor_core_test.dart：现有核心流程加入实际画布像素检查，防止照片亮度再次被覆盖。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号。
- 本说明及 D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：交付记录与用户动画确认。

## 验证
先由实际画布像素检查复现变暗（测试照片红色通道应为 77，实际为 56）；修复后同一检查验证各颜色通道与原照片相符，允许 2 级取整差异。代码检查和单轮核心三项结果见 technical-validation.md；日志：D:/AI Agent/LumaCraft/app/build/editor-core-check-0.2.5.log。
不扩大测试范围，其余体验交用户试用。
