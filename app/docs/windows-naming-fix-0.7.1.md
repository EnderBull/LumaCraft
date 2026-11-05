# LumaCraft 0.7.1 · 命名模板修复

版本 0.7.1+30，2026-11-05。

## 本次修复

- “输入文字…”仅在命名模板末尾显示一次，中间的空文字片段不再重复显示提示。
- 按实际字体测量文字宽度，缩短文字与变量模块之间多余的空白；长文字保留输入框内滚动。
- 整理空片段并合并相邻文字；连续插入、删除模块和光标中间插入时保留文字顺序与输入焦点。
- 默认模板继续为{name}_LumaCraft。导出、重名处理与sRGB色彩管理沿用0.7.0。

## 修改与生成文件

- D:/AI Agent/LumaCraft/app/lib/ui/export/naming_template_editor.dart：提示、宽度测量、片段整理与光标处理。
- D:/AI Agent/LumaCraft/app/build/export-preview/preview_test.dart：扩充当前核心交互验证及真实字体截图。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号。
- D:/AI Agent/LumaCraft/app/docs/windows-naming-fix-0.7.1.md：本说明。
- D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/docs/export-panel-preview.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：追加修复记录。

## 验证

静态分析无问题。核心控件流程通过：连续插入3个序号变量仅保留一个末尾提示，文字宽度随实际字体收缩，删除变量后文字正确合并，末尾输入保持焦点，光标中间连续插入日期和时间变量保留正确顺序。原有尺寸拖动、基线、PNG质量禁用与重名按钮检查一并通过。

截图：D:/AI Agent/LumaCraft/app/build/export-preview/naming-compact.png。
验证日志：D:/AI Agent/LumaCraft/app/build/naming-compact-final.log。
编译日志：D:/AI Agent/LumaCraft/app/build/export-release-0.7.1.log。
本次没有修改导出管线，也未重复全量测试。实际使用体验交用户试用。

## 运行

D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.7.1/lumacraft.exe。
保留完整目录，包括lumacraft_color_tool.exe、DLL和data。只输出可运行文件夹，无压缩包，旧版保留。
