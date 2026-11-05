# LumaCraft 0.11.0 · 组件整理与恢复默认（制作版）

2026-11-05，版本0.11.0+37。此交付为制作版，开启内置预设维护入口，沿用0.10.1的全部功能。

## 1. 移除“作者签名”组件

- 作者签名与自由文字本质相同，已从“添加组件”里移除，现在共 9 种组件：自由文字、拍摄参数、相机型号、镜头型号、拍摄时间、拍摄地点、照片色卡、图片标识、形状。
- 内置预设中原来用作者签名的 3 处改成自由文字，内容、字体、位置、颜色不变，画面不变，图层名改为“签名”：画廊签名、胶片档案、手机经典·签名边框。
- 兼容旧数据：旧的用户预设、照片记录、别人发来的 `.lmp` 里如果还有作者签名，读入时自动按自由文字处理，不会打不开。

## 2. 添加组件：轻量下拉菜单，图标平铺

- 不再弹窗。点“添加组件”（画布顶部按钮或图层面板标题栏的“+”），菜单贴着按钮展开，直接打开和关闭、无动画，点击外部或按 Esc 关闭，点选后立即添加。
- 图标在上、名称在下，一行 3 个，9 个组件正好 3 × 3。
- 列数是唯一的可调参数：`app/lib/ui/editor/component_picker.dart` 里的 `componentPickerColumns`（现为 3），行数按组件数量自动计算。以后新增组件，在组件列表里加一项即可，需要时再调整这个列数。

## 3. 字体列表

最早添加的三个字体只保留字体名：微软雅黑、Georgia、Georgia Italic。字体本身与已有预设的引用不变。

## 4. 画布上方的状态提示

去掉圆点和“·”，只用文字、颜色和一条细竖线：

| 状态 | 显示 |
|---|---|
| 草稿 | 横图布局 ｜ **草稿**（橙色） |
| 已应用到当前照片 | 横图布局 ｜ **已应用**（绿色） |

预设不分横竖布局时只显示状态词。鼠标悬停显示完整说明：“草稿预览，尚未应用到照片”“当前照片已应用此样式”。

## 5. 制作版：恢复默认（三处）

“默认”指软件这个版本封包时的内置预设。

1. 编辑内置预设时，画布顶部工具条出现“恢复默认”按钮：把当前这款恢复为默认样式，可撤销，点“保存预设”后才写入制作版工作库。
2. 预设面板里内置预设卡片的右键菜单“恢复默认”（可多选，选中的全是内置预设时出现）：确认后直接恢复，不可撤销。
3. 内置预设维护面板：原来的“恢复原稿”改名为“恢复默认”，并新增“全部恢复默认”——整个内置库回到封包状态，本机新建的内置预设和分组会被删除。

发行版没有这些入口，也不会改内置库。

## 验证

- 新增 `test/refinements_test.dart` 共 4 项：作者签名已移除且旧数据/旧 `.lmp` 自动转自由文字、内置预设无作者签名且 3 处签名内容字体不变、三个旧字体名、制作版恢复默认（单款、全部、重开后仍是默认、发行版不可用）、添加组件下拉菜单（3 列自动 3 行、行列对齐、行数随数量增加、点选返回类型、Esc 关闭）。
- 完整 Flutter 测试共 47 项通过；原有测试仅一处因字体改名更新了选择文字。
- 真实界面：`build/phone-preview/ui_test.dart` 在编辑内置预设的真实页面里依次验证：状态提示无圆点、添加组件菜单 9 项且无作者签名、点选形状后图层变为 7 个、点“恢复默认”确认后恢复为 6 个、卡片右键菜单有“恢复默认”，并截图核对。
- 未验证：各 Windows 缩放档位下新菜单与提示框的文字清晰度，请使用时确认。

## 文件清单

新增：
- D:/AI Agent/LumaCraft/app/lib/ui/editor/component_picker.dart
- D:/AI Agent/LumaCraft/app/test/refinements_test.dart
- D:/AI Agent/LumaCraft/app/build/phone-preview/author_to_text.py（一次性转换脚本，记录了内置预设的改动）
- D:/AI Agent/LumaCraft/app/docs/windows-refinements-0.11.0.md
- D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.11.0-Authoring/（旧版本目录保留未动）

修改：
- D:/AI Agent/LumaCraft/app/lib/editor/style_document.dart、editor_controller.dart、style_render.dart、preset_package.dart、preset_store.dart
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_canvas.dart、editor_panels.dart、editor_page.dart
- D:/AI Agent/LumaCraft/app/lib/ui/builtin_manager.dart、preset_actions.dart
- D:/AI Agent/LumaCraft/app/lib/fonts/font_catalog.dart
- D:/AI Agent/LumaCraft/app/assets/builtins/library.json
- D:/AI Agent/LumaCraft/app/test/editor_core_test.dart、build/phone-preview/ui_test.dart、build/phone-preview/drafts_test.dart
- D:/AI Agent/LumaCraft/app/pubspec.yaml（版本0.11.0+37）
- D:/AI Agent/LumaCraft/项目台账.md

## 交付

D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.11.0-Authoring/lumacraft.exe。请保留完整目录，不单独移动EXE。只提供可运行文件夹，无压缩包。
