# ADR-008 · OFL字体、官方精简版本与兼容键

状态：按当前代码及保留记录重建，2026-11-05。历史缺少决策证据的部分明确标注，不臆造。

## 背景

需要有衬线/无衬线/手写中英文，离线可用且控制包体。

## 决策

8款OFL官方原文件；中文区域/Lite及单字重，英文小型可变文件；同类中文回退；保留旧Georgia/微软雅黑键；菜单沿用现有下拉并用对应字体。

## 被否决/未采用的备选与证据边界

用户取消Futura；不按示例文字裁字，不用重做字体选择独立界面。

## 代价与影响

字体约35.90MiB；简体/Lite不覆盖所有Unicode生僻字；旧系统字体保留历史表现，不把所有回退当完全同字形。

## 影响文件/核实入口

app/assets/fonts/sources.json及OFL；lib/fonts/font_catalog.dart；pubspec.yaml；lib/ui/editor/prototype_controls.dart。
