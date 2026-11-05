# ADR-009 · 既定原型与一致的桌面操作

状态：按当前代码及保留记录重建，2026-11-05。历史缺少决策证据的部分明确标注，不臆造。

## 背景

此前反复出现小字、标签重叠、图标及正式Flutter界面与HTML原型不一致。

## 决策

共用顶栏/底栏、控件与文字样式；文字下划线标签页、阴影层级、暖金强调；外部标签，菜单无动效；Ctrl/Shift/框选，Ctrl+J复制、Ctrl+D按焦点取消。

## 被否决/未采用的备选与证据边界

用户否决勾选框常规选择、过小文字、混用Flutter原生下拉外观、Ctrl+D复制及冗余设置面板。

## 代价与影响

必须核实际Windows字体/缩放，不以代码分析代替视觉核对；组件的艺术字体与UI字体分别管理。

## 影响文件/核实入口

根AGENTS.md；app/ui-prototype；lib/ui/workspace_dialog.dart、editor/prototype_controls.dart、workspace_chrome.dart。
