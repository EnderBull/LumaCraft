# 导出面板 · 第一阶段交互预览

2026-11-05。已获用户确认先制作控件截图，确认布局后再接入实际导出及sRGB色彩管理。本次不升级版本号、不打包，现有导出入口仍保持原状。

新增文件：
- D:/AI Agent/LumaCraft/app/lib/export/export_options.dart：导出参数、命名模块和变量目录。
- D:/AI Agent/LumaCraft/app/lib/ui/export/export_dialog.dart：独立标签、双列设置、滚动内容区和固定底部动作；JPG画质与PNG条件显示；拍摄信息与GPS独立开关。
- D:/AI Agent/LumaCraft/app/lib/ui/export/naming_template_editor.dart：可删除变量模块、可编辑普通文字、按光标位置插入变量、即时文件名示例。日期时间示例使用演示数据，不读取文件时间。
- D:/AI Agent/LumaCraft/app/build/export-preview/preview_test.dart：加载实际微软雅黑与Material图标字体，渲染截图并检查插入、删除、普通文字编辑和PNG隐藏画质。
- D:/AI Agent/LumaCraft/app/build/export-preview/export-panel.png：默认JPG面板截图。
- D:/AI Agent/LumaCraft/app/build/export-preview/export-panel-png.png：变量编辑后的PNG面板截图。
- D:/AI Agent/LumaCraft/app/build/export-preview/preview-final.log：最后一轮控件检查日志。

面板截图与交互检查通过；新增正式源码的代码分析通过。截图中sRGB提示表示本阶段确认的输出策略，尚未实现颜色转换、ICC嵌入或导出任务，不代表色彩管理已经完成。

待用户确认布局后继续：原生目录选择、导出参数持久化与校验、命名非法字符/重名/缺失字段处理、尺寸与质量、元数据/GPS、源图色彩识别与转换、ICC资源许可及JPG/PNG嵌入、任务进度/取消/失败重试、最后一轮核心导出验收和文件夹交付。

## 第二版预览 · 2026-11-05

用户确认：四角统一裁切；文件格式/成片尺寸/画质同排，PNG滑块保留并禁用；拍摄参数/GPS/sRGB同排，开关靠近标签；默认命名为{name}_LumaCraft，无默认序号。重名时由用户选择添加编号全部保留、替换、取消导出，不再自动决定。

修改上述导出面板、参数模型、预览验证；新增 D:/AI Agent/LumaCraft/app/lib/ui/export/export_conflict_dialog.dart，提供三个选择的共用面板，仅返回处理策略，尚未写入或替换实际文件。新增 D:/AI Agent/LumaCraft/app/build/export-preview/export-conflicts.png 重名面板截图。最后验证日志为 D:/AI Agent/LumaCraft/app/build/export-preview/preview-revised-final.log；检查覆盖默认模板无序号、圆角裁切、PNG滑块禁用及三种重名选择，已通过。代码分析无问题。

按确认范围，在 D:/AI Agent/LumaCraft/AGENTS.md 追加弹窗子内容不能遮住四角的通用纠正。仍等待截图确认后再接入导出和ICC，不升级版本、不打包。

## 第三版预览 · 2026-11-05

按用户补充调整：成片尺寸改为左侧长边/短边选择、右侧像素输入的同一控件，留空为原尺寸，输入后按所选成片边长等比例缩放（含边框）。参数模型改为sizeEdge及可空edgePixels。原先“不放大小图”的预览说明由本轮明确输入尺寸规则替代，实际缩放链路尚未接入。

新增 D:/AI Agent/LumaCraft/app/lib/ui/export/vertical_toggle.dart：28×46px竖向轨道、22px圆形，开上关下，圆形内对钩/叉号以一致圆角线条绘制；文字在右侧。支持点击、Space/Enter及状态语义，减少动态效果设置生效。修改导出面板、参数模型和预览验证。

重名按钮改为“取消导出 / 替换保存 / 全部保留”，说明保留“全部保留自动添加编号”；修改 D:/AI Agent/LumaCraft/app/lib/ui/export/export_conflict_dialog.dart。

更新截图：export-panel.png（默认空尺寸）、export-panel-short-edge.png（短边2400）、export-panel-png.png（禁用画质）、export-conflicts.png，均位于 D:/AI Agent/LumaCraft/app/build/export-preview/。日志preview-vertical-toggle.log同目录。交互检查覆盖空尺寸、短边输入、竖向开关、模块编辑、PNG禁用画质和三个重名返回值，已通过；新增源码代码分析无问题。依然只做预览，无实际导出、替换、ICC转换或打包。

## 对齐微调 · 2026-11-05

修改 D:/AI Agent/LumaCraft/app/lib/ui/export/export_dialog.dart：像素输入与左侧选择统一13px字号、1.5行高，使用明确的文字居中和行高约束，去除输入框额外纵向内边距。修改 D:/AI Agent/LumaCraft/app/lib/ui/export/export_conflict_dialog.dart：三按钮统一112×40px。同步修改预览验证，实测左右文字中心差小于1px，三按钮宽高一致；检查通过，日志为 D:/AI Agent/LumaCraft/app/build/export-preview/preview-alignment.log。上述四张截图已更新，仍未接正式导出或打包。

## 基线纠正与尺寸拖动 · 2026-11-05

用户指出按控件中心检查仍无法保证实际文字对齐。本轮将尺寸输入组合改为alphabetic文字基线对齐，不再用中心位置代替基线验收。修改同一导出面板并复用 D:/AI Agent/LumaCraft/app/lib/ui/editor/number_drag_input.dart（共用文件未修改），支持鼠标左键左右/上下拖动，沿用Shift加速、Alt精调；键盘输入和清空恢复原尺寸保留。像素按整数保存，最终导出数值校验仍在后续接入范围。

预览验证改为检查实际文字基线，同时覆盖横向/纵向鼠标拖动与清空。检查通过，日志 D:/AI Agent/LumaCraft/app/build/export-preview/preview-baseline-drag-final.log。截图已更新。实际系统缩放下的视觉观感等待用户确认，不把自动布局测量等同于所有显示环境的人工检查。

## 尺寸框字体统一 · 2026-11-05

根据用户反馈，尺寸框左右文字显式共用同一个微软雅黑UI、13px、常规字重、1.5行高样式，不仅设置相同字号。“原尺寸”提示不透明度设为40%，继续按文字基线对齐。修改导出面板；D:/AI Agent/LumaCraft/app/lib/ui/editor/prototype_controls.dart 增加可选textStyle覆盖，仅本次尺寸选择使用，其他选择框默认保持原样。预览验证增加字体、字号、字重及不透明度断言，连同基线和拖动操作检查通过，日志为 D:/AI Agent/LumaCraft/app/build/export-preview/preview-type-match.log。截图已更新；未接正式导出、未打包。

## 正式接入 · 0.7.0
2026-11-05：上述已确认界面已接入正式导出、重名处理、sRGB转换及JPG/PNG ICC嵌入；之前“仅预览”的记录描述当时阶段。最新行为、完整文件清单、验证与限制以 D:/AI Agent/LumaCraft/app/docs/windows-export-0.7.0.md 为准。


## 2026-11-05 · 命名模板紧凑输入（0.7.1）
修复空文字片段重复提示与按字符数估算宽度造成的间隔。末尾保留唯一输入提示，文字宽度按实际字体测量；整理空片段、合并相邻文字并保留光标和焦点。连续插入/删除、末尾输入与光标中间插入的核心流程通过；静态分析与Windows release编译通过。完整记录见 D:/AI Agent/LumaCraft/app/docs/windows-naming-fix-0.7.1.md。
