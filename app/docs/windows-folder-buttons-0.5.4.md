# LumaCraft 0.5.4 · 分组操作按钮统一

版本0.5.4+22，2026-11-04。

分组详情底部的重命名、导出、删除改用同一个 WorkspaceActionButton：高40px、圆角6px、水平内边距14px；文字明确采用微软雅黑UI及回退字体、13px、中等字重、1.4行高，不再依赖普通正文的14px常规字重。
重命名和导出使用现有中性色背景；删除使用淡红色背景及红色文字，分别适配深浅外观。忙碌时禁用，空分组仍禁用导出；回调、确认和分组逻辑保持不变。

修改清单：
- D:/AI Agent/LumaCraft/app/lib/ui/workspace_dialog.dart：新增共用操作文字样式和按钮。
- D:/AI Agent/LumaCraft/app/lib/ui/folder_manager.dart：三个操作入口复用共用按钮。
- D:/AI Agent/LumaCraft/app/test/preset_library_test.dart：检查字号、字重、圆角、40px高度、中性及红色背景，并跑通既有分组管理流程。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号。
- 本说明、D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：交付记录。

验证：代码分析无问题，三项相关核心验证通过，Windows release编译成功。未声称已消除所有系统缩放下的字体差异，实际清晰度和配色观感交用户确认，不扩大测试范围。
日志：D:/AI Agent/LumaCraft/app/build/folder-buttons-check.log、D:/AI Agent/LumaCraft/app/build/folder-buttons-build.log。
程序：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.5.4/lumacraft.exe。仅文件夹交付，保留DLL和data，旧版本保留。
