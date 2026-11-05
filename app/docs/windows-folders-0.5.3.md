# LumaCraft 0.5.3 · 分组管理与浏览交互

版本0.5.3+21，2026-11-04。

## 本次功能
- 保存、移动、预设筛选三处分组下拉框共用FolderSelect，均可直接“＋新建分组”；创建成功后选中，取消保留原选择。重复名称提示，存储失败不提前选中。
- 筛选下拉框右侧新增文件夹/调节线图标，直接打开分组管理。
- 新的管理面板：顶栏图标、名称及统计，右上角X关闭；分组概览显示各组缩略图和名称摘要。进入详情显示完整预设网格，提供返回、重命名、整组导出及删除；返回保留概览滚动位置。删除仍由用户选择保留或连带删除，默认保留。
- 预设框选范围包含两侧留白；卡片位置与滚动内容坐标统一；滚动条保留自身操作。
- 浏览画布支持Alt+滚轮缩放（10%～800%）、空格+拖动平移、“适合窗口”复位，保留完整构图。
- 浏览目录树Ctrl增减、Shift按可见顺序连选；合并目录照片，含子目录对全部所选根生效，完整路径统一分隔符和大小写后去重。切换时取消旧扫描，目录集合跨浏览/编辑切换保留。
- 目录焦点Ctrl+D取消目录选择并清空当前浏览列表，已保存编辑记录保留；照片区Ctrl+D仅清照片选区；预设区仅清预设选区。
- 编辑画布底部适配检查选框宽136px，工具区高60px并增加底部留白。
- 预设底部空白按钮/管理按钮切换为260ms、8px上下轻移叠加淡入淡出，并平滑调整高度；遵循系统减少动态效果设置。
- 吸附按钮改为磁铁/参考线图标，显示“吸附：开/关”，开启轻强调底色，悬停解释吸附对象及Alt临时关闭。点击只切开关，不移动组件。

## 文件清单
新增：
- D:/AI Agent/LumaCraft/app/lib/ui/folder_select.dart：统一分组下拉与创建弹窗。
- D:/AI Agent/LumaCraft/app/lib/ui/folder_manager.dart：两级分组管理。
- D:/AI Agent/LumaCraft/app/lib/ui/browse_viewport.dart：浏览缩放/平移。
- D:/AI Agent/LumaCraft/app/assets/ui/layer-manageFolders.svg、D:/AI Agent/LumaCraft/app/assets/ui/layer-snap.svg：同风格图标。
- D:/AI Agent/LumaCraft/app/test/browse_controls_test.dart：多目录、扫描取消、目录选择/快捷键及画布手势。
修改：
- D:/AI Agent/LumaCraft/app/lib/ui/preset_panel.dart：管理入口、留白框选、操作区动画。
- D:/AI Agent/LumaCraft/app/lib/ui/preset_actions.dart：共用分组选择及管理。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart：保存分组选框及多目录交接。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_canvas.dart：工具区及吸附按钮。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/mode_transition.dart：返回状态携带目录集合。
- D:/AI Agent/LumaCraft/app/lib/ui/directory_panel.dart：目录多选与焦点快捷键。
- D:/AI Agent/LumaCraft/app/lib/directory_browser.dart：多根扫描、重叠去重。
- D:/AI Agent/LumaCraft/app/lib/main.dart：浏览操作及多目录状态。
- D:/AI Agent/LumaCraft/app/test/preset_library_test.dart：详情返回/关闭、两侧框选与下拉创建验证。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本。
- 本说明、产品方案及app/docs/technical-validation.md、app/ui-prototype/design-notes.md：确认需求和交付记录。

## 验证及交付
代码分析无问题，十二项核心验证通过；其中发现并修复混合路径分隔符造成的重叠扫描重复。覆盖新组自动选择、管理详情返回/删除/关闭、左右边缘框选、Alt滚轮/空格拖动/复位、目录Ctrl/Shift/Ctrl+D、多根扫描去重与过期任务取消，以及既有编辑应用、图层即时开关/改名、导出EXIF。
日志：D:/AI Agent/LumaCraft/app/build/folder-browse-check.log、D:/AI Agent/LumaCraft/app/build/folder-browse-build.log。
剩余Windows实际鼠标手感、动画观感及大目录体验交用户试用；浏览器原型未同步本批功能。
程序：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.5.3/lumacraft.exe。仅输出文件夹，保留DLL和data，旧版本保留。
