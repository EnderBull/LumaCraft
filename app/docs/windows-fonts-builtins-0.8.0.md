# LumaCraft 0.8.0 · 字体与内置预设制作版

2026-11-05，版本0.8.0+31。此交付为制作版，开启内置预设维护入口。

## 使用入口

- 字体：编辑模式 → 选择文字组件 → 组件 → 文字样式 → 字体。每个菜单名称使用对应字体显示，沿用原下拉控件，无下拉动画。
- 新内置样式：预设面板 → 内置 → 创意边框。包含04画廊签名、05旅行记录、06胶片档案，横图/竖图有布局配置，方图使用通用布局。
- 内置维护：预设面板搜索框右侧“…” → 内置预设维护。选中预设后“编辑样式”，或双击预设卡片。编辑后右下角“保存预设”打开“保存内置预设”，可直接更新本机工作库，也能另存用户预设。
- 维护面板支持创建预设/分组、调整名称与分组、恢复此版本封包原稿、载入与导出内置库。所有分组选择控件均提供新建入口，所属用户库与内置库分开。
- 未选择照片也可维护，用标明“示意画布”的简单图形占位；真实EXIF相关组件显示缺失提示，色卡提色及应用到照片需要先选择真实照片。
- “手机经典”分组已建立，目前为空；品牌经典样式仍处于后续参考收集/视觉确认阶段，未假称已经完成品牌复刻或标识授权核实。

## 字体与包体

内置：思源黑体CN Regular、得意黑、思源宋体CN Regular、霞鹜文楷Lite Regular、Jost、Manrope、Playfair Display、Caveat。Futura不收录。

字体文件均为官方原文件，未按示例文本裁字。思源采用官方简体中文区域版本；文楷采用官方Lite版本；中文先仅收一个字重；英文可变字体体积很小，保留官方单文件。保留中英文、数字、摄影符号的自由输入能力，未收录字符依赖回退字体，不能保证所有Unicode生僻字都有同一字形。英文选项对中文使用同类内置字体回退，并在属性面板提示。

| 文件 | 原始体积 |
|---|---|
| SourceHanSansCN-Regular.otf | 8.04 MiB |
| SourceHanSerifCN-Regular.otf | 11.09 MiB |
| SmileySans-Oblique.ttf | 2.51 MiB |
| LXGWWenKaiLite-Regular.ttf | 13.30 MiB |
| Jost.ttf | 0.13 MiB |
| Manrope.ttf | 0.16 MiB |
| PlayfairDisplay.ttf | 0.29 MiB |
| Caveat.ttf | 0.38 MiB |

合计35.90 MiB。Jost+Manrope合计约293 KiB。未打包日/韩/繁体全套字库或中文全部字重。字体已随程序字体资源封装，正常使用不需要在线下载或系统安装；旧的Georgia/微软雅黑字体键保留原有表现及回退。

所有OFL许可与来源、下载地址和SHA-256记录在 D:/AI Agent/LumaCraft/app/assets/fonts/sources.json 及同目录的*-OFL.txt；交付目录额外提供licenses/fonts供离线查阅。未修改原字体，不触发裁字后的保留名称处理。

新字体.lmp包含bundledFontsV1能力声明，当前版本可往返，旧版会拒绝不认识的能力；旧版.lmp继续可用。不将字体二进制重复塞进每个预设。

## 制作稿与发行封包

内置工作库为用户数据目录中的builtin-working.json，与editor-presets.json用户库独立。保存后重新打开软件仍可读取；写入成功前不更新活跃库。请在最终封包前从维护面板“导出内置库”，保存为JSON。

制作入口由编译开关LUMACRAFT_AUTHORING控制，默认false；发行构建不读取制作稿。交付版编译时明确设为true。

准备封包：运行 D:/AI Agent/LumaCraft/app/tools/prepare_builtin_release.ps1，并传入-InputLibrary导出的JSON路径。工具创建新的assets/builtins/release-时间.json，保留原资源和工作库，并打印使用LUMACRAFT_BUILTIN_ASSET的发行构建命令。此脚本仅准备资源，不生成正式发行安装包；运行时仍会完整校验预设结构。发行版只能复制内置样式为用户预设后修改。

## 验证

四项新增核心检查通过：8款官方字体/许可离线加载及.lmp往返；内置工作库保存重开、恢复原稿与发行只读隔离；3款预设横/竖/方画布及边界；字体菜单使用实际字体。原有预设管理及编辑核心流程9项通过。维护界面新增1项真实字体交互截图流程通过，覆盖保存内置并读取结果。共14项不同核心检查；没有反复跑全量测试。

首次既有编辑检查因旧选项名称变化失败，已恢复旧显示名称并通过；截图流程最初只固定等待120ms，未等到串行文件写入完成，已按实际完成状态等待并通过。没有通过降低断言掩盖错误。

Windows实际窗口核对了维护面板和新建分组表单的字体/标签/间距；随后电脑操作收到物理Esc而停止，没有保存本机预设。字体菜单和保存面板使用真实字体的Flutter截图另已核对。没有声称核对全部Windows缩放档位。

日志：D:/AI Agent/LumaCraft/app/build/builtin-ui-check.log（原有9项及新增4项通过，早期截图等待失败记录保留）、builtin-preview-final.log（同目录，维护保存流程通过）、builtin-release-0.8.0.log（同目录，编译成功）。截图在D:/AI Agent/LumaCraft/app/build/builtin-preview。

## 文件清单

新增：
- D:/AI Agent/LumaCraft/app/lib/fonts/font_catalog.dart：字体清单、映射、同类回退与菜单说明。
- D:/AI Agent/LumaCraft/app/lib/editor/builtin_library.dart：内置库结构、校验及构建开关。
- D:/AI Agent/LumaCraft/app/lib/ui/builtin_manager.dart：维护面板。
- D:/AI Agent/LumaCraft/app/lib/ui/builtin_folder_select.dart：内置分组选择与新建共用控件。
- D:/AI Agent/LumaCraft/app/assets/builtins/library.json：三款横竖适配样式及手机经典分组。
- D:/AI Agent/LumaCraft/app/assets/fonts/：8个字体、8份OFL、sources.json，具体文件见上表。
- D:/AI Agent/LumaCraft/app/tools/acquire_fonts.py：官方字体资源获取及来源记录。
- D:/AI Agent/LumaCraft/app/tools/prepare_builtin_release.ps1：制作库准备为独立发行资源。
- D:/AI Agent/LumaCraft/app/test/builtin_fonts_test.dart：核心验证。
- D:/AI Agent/LumaCraft/app/build/builtin-preview/preview_test.dart：界面流程与截图。
- D:/AI Agent/LumaCraft/app/docs/superpowers/plans/2026-11-05-fonts-builtins.md：实施记录。
- D:/AI Agent/LumaCraft/app/docs/windows-fonts-builtins-0.8.0.md：本说明。

修改：
- D:/AI Agent/LumaCraft/app/lib/editor/preset_store.dart：资源库加载、独立工作稿保存及恢复。
- D:/AI Agent/LumaCraft/app/lib/editor/preset_package.dart：新字体校验与能力标记。
- D:/AI Agent/LumaCraft/app/lib/editor/style_render.dart：画布/预览/成片共用字体样式。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/prototype_controls.dart：下拉项目可指定文字样式。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_panels.dart：字体菜单、内置编辑目标及保存提示。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_canvas.dart：内联文字字体一致、示意画布标识。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart：内置目标保存及无照片示意图。
- D:/AI Agent/LumaCraft/app/lib/ui/preset_panel.dart、D:/AI Agent/LumaCraft/app/lib/ui/preset_actions.dart：内置分组筛选与维护入口。
- D:/AI Agent/LumaCraft/app/lib/ui/folder_select.dart：浏览筛选显示内置分组，用户保存仅选择用户分组。
- D:/AI Agent/LumaCraft/app/lib/main.dart：浏览页进入内置维护编辑。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：字体、许可、库资源及版本；pubspec.lock由Flutter解析保持同步。
- D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：追加本轮记录。

## 交付与待办

D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.8.0-Authoring/lumacraft.exe。请保留完整目录，不单独移动EXE。只提供可运行文件夹，无压缩包，旧版本保留。

下一阶段：各手机品牌经典边框的参考/具体版本确认、品牌与联名标识素材来源核实及制作；最终预设视觉由用户继续在维护入口调整。实际照片组合、其它显示缩放及长时间使用体验交用户试用。字体完整OFL文本优先于本说明中的简述。
