# ADR-007 · 内置工作库与发行只读隔离

状态：按当前代码及保留记录重建，2026-11-05。历史缺少决策证据的部分明确标注，不臆造。

## 背景

用户要在制作阶段直接修改内置样式，再封成最终不可修改的内置资源。

## 决策

资源library.json为封包基线；AUTHORING=true读取独立builtin-working.json并提供维护入口；默认false发行不读取工作稿。导出内置库，再以新资源和编译参数封包。

## 被否决/未采用的备选与证据边界

用户否决制作阶段只能复制成用户预设、无法直接维护内置的工作流；最终发行仍保留用户复制修改通道。

## 代价与影响

保存工作库不等于已写回assets或已封包；数据目录定位与最终导出文件必须明确，避免遗漏用户作品。

## 影响文件/核实入口

app/lib/editor/builtin_library.dart、preset_store.dart；ui/builtin_manager.dart、builtin_folder_select.dart；ui/editor/editor_page.dart；tools/prepare_builtin_release.ps1。
