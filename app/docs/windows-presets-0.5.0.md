# LumaCraft 0.5.0 · 预设管理与 .lmp 分享

版本0.5.0+18，2026-11-04。

## 使用
- 浏览与编辑模式右侧使用同一预设面板；支持搜索、全部/内置/我的/收藏及分组筛选。
- 单击选择并套用首项；Ctrl增减、Shift连选、空白处拖框多选，后续增减只改变管理选区，不反复套用。无选区框选松鼠标后应用显示顺序首项。普通单击重新应用；应用期间仍可继续选择，连续普通点击只排队最新一项。
- 未选中卡片悬停显示半透明强调色框，选中使用实色框。
- 卡片更多按钮、右键菜单或底部操作可重命名、复制、移动、导出、删除；多选没有重命名。含内置时禁止移动与删除，内置可复制为用户预设。
- 顶部“预设管理”菜单可新建空白样式、导入、导出整组、新建与管理分组。删除分组时默认保留预设并移至未分组，也可主动选择连带删除。删除前展示对象并确认。
- 保存预设对话框可选择所属分组。管理和删除不会改变已应用到照片的效果。
- 单个、选中批量、整个分组均导出 .lmp；包含样式、内嵌图片及分组名称，不包含照片、拍摄参数、草稿和本地路径。素材附带EXIF/文字元数据剥离但不重编码像素。
- 导入先校验并展示缩略图和数量；同名可保留两份、覆盖、跳过，默认保留两份。覆盖保留本地身份、分组与收藏，导入不自动应用。
- 当前每包最多200个预设、64MB；素材最长边2048px。未知功能、版本或损坏素材拒绝导入，失败不写入库。二维码与文本分享尚未实现。

## 修改文件
新增：
- D:/AI Agent/LumaCraft/app/lib/editor/preset_selection.dart：管理多选与首选逻辑。
- D:/AI Agent/LumaCraft/app/lib/editor/preset_package.dart：.lmp编解码、素材验证、元数据清除、冲突合并。
- D:/AI Agent/LumaCraft/app/lib/ui/preset_panel.dart：共用面板、虚拟化缩略图、悬停及框选。
- D:/AI Agent/LumaCraft/app/lib/ui/preset_actions.dart：管理菜单、分组、分享与确认对话框。
- D:/AI Agent/LumaCraft/app/test/preset_library_test.dart：选择、文件往返、分组与真实面板验证。
- D:/AI Agent/LumaCraft/app/docs/superpowers/plans/2026-11-04-preset-library.md：实施计划。
- 本说明。
修改：
- D:/AI Agent/LumaCraft/app/lib/editor/preset_store.dart：分组和原子保存，兼容旧库。
- D:/AI Agent/LumaCraft/app/lib/main.dart：浏览共用面板与空白编辑入口。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart：保存分组及键盘作用域。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_panels.dart：编辑共用面板。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本。
- D:/AI Agent/LumaCraft/框印工坊-LumaCraft-产品设计方案.md：确认需求。
- D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：交付记录。

## 验证与限制
九项核心流程通过；新增面板针对性验证通过，代码分析无问题。覆盖多选/框选回调次数、分组两种删除、草稿与库并发保存、素材和半透明往返、同名处理、坏结构拒绝、既有编辑应用及EXIF。首次布局滚动尺寸尚未就绪的问题已修复。
独立审查工具受额度限制未完成；已自行核对实现及计划。剩余真实照片、系统文件选择框和鼠标体验交用户试用，浏览器原型未同步此批新功能。
日志：D:/AI Agent/LumaCraft/app/build/preset-library-final-check.log；D:/AI Agent/LumaCraft/app/build/preset-library-ui-check.log；D:/AI Agent/LumaCraft/app/build/preset-library-build.log。
程序：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.5.0/lumacraft.exe。保留同目录DLL和data文件夹，本次不生成压缩包，旧版本保留。
