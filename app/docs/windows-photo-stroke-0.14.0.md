# LumaCraft 0.14.0 · 照片描边、内置素材、预设分组与几处操作修正（制作版）

2026-11-06，版本 0.14.0+41。此交付为制作版，沿用 0.13.0 的全部功能。内置预设已换成你在 0.13.0 制作版里保存的版本。

## 新功能

### 照片描边
- 画布页新增“照片描边”，画在照片或整张画布的边上，换横图、竖图、方图时线会跟着走。
- 可调：参照（照片边缘 / 画布外缘）、粗细、偏移、不透明度、颜色。
- 偏移：正数往里缩，负数往外扩，0 压在边上。
- 下面 4 款预设里原来用形状画死的外框，已改成照片描边，不同长宽比不会再对不齐：
  - 双线相框：线跟着整张画布，在边内约 22。
  - 波点糖果：白线整条都在照片外面。
  - 扫描线 HUD：青色线在照片里面，半透明。
  - 大理石画廊：金线在照片外面。原来的金色短线还在。

### 内置素材
- 添加组件的菜单里多了一格“内置素材”。点它直接选邮戳，不必先从电脑里找一张图片。
- 已经放好的图片，旁边的按钮也改名为“内置素材”，可以换成邮戳。本地图片仍用“替换图片”。
- 目前只有“邮戳”一类（航空邮戳、波浪注销线、椭圆邮戳，灰 / 蓝 / 红 / 黑）。以后加别的素材，还是进这个入口。
- 选中邮戳后，下面仍有“邮戳墨色”，点一下就能换色。

### 色卡描边不透明度
- 色卡打开描边后，可以单独调描边的不透明度。原来的预设默认是 100，看起来和以前一样。

## 内置预设

- 已换成你在 0.13.0 制作版里保存的版本，并去掉“拉丝金属”。现在是 41 款。
- 分组改成：

| 分组 | 里面有什么 |
|---|---|
| 简约 | 画廊签名、旅行记录、极简黑框、网格极简、双线相框、展览标牌、磨砂黑卡、大理石画廊 |
| 胶片 | 胶片档案、底片孔洞、宝丽来 |
| 旅行 | 邮票·模糊背景、车票、票根、复古邮票、牛皮纸邮票 |
| 纸张手帐 | 宣纸题印、牛皮纸信笺、水彩手账、亚麻画布、诗集扉页、自然诗篇 |
| 色卡 | 色板边框、色带边框、色卡标签 |
| 模糊氛围 | 模糊相框·居中、模糊相框·底栏、暮色渐变、模糊色卡 |
| 可爱 | 波点糖果、星星便签、野餐格纹 |
| 科技 | 蜂窝科技、扫描线 HUD、电路板 |
| 手机水印 | 原来的 6 款手机版式。名称改了，内容和以前一样，仍然不含品牌 Logo |

- 旅行记录仍留在“简约”。
- 制作版里还可以继续改这些预设。定稿后告诉我，我再打包发行版。

## 操作修正

- 编辑时打开“预设”页，会滚到当前选中的那一张；没选中、但正在改某一款内置预设时，滚到那一款；都没有就停在最上面。
- 选中了组件时，方向键只移动组件（按住 Shift 步子更大）。没有选中组件时，左右方向键仍切换照片。
- 可以拖动改数字的输入框，双击回到这项一开始的默认值，并且只记一步撤销。不透明度滑块和颜色框不在此列。
- 选中“拍摄地点”，而这张照片没有地点时，属性里可以直接填写。只记在这张照片上，不会写进预设，也不会把照片标成已改样式。
- 图层列表里单击只是选中。鼠标挪开大约 6 像素才开始拖动，避免一点就拖走。
- 预设卡片上右键弹出的菜单，出现在鼠标所在的位置。

## 兼容性

- 分享成 `.lmp` 时，用到新功能会加标记：
  - 照片描边：`photoStrokeV1`。
  - 色卡描边不透明度不是 100：`paletteStrokeOpacity`。
- 旧版软件导入这些预设时会明确提示不支持，不会悄悄画错。
- 没有用到这两项的预设，旧版仍可导入。

## 验证

- 新增 `test/photo_stroke_test.dart`：描边的保存与读取、旧文件默认关闭、分享标记、横图和竖图上线都跟着照片走且照片中间不变、画布外缘的线落在画布内侧。
- 色卡描边不透明度的默认值和分享标记。
- 双击数字框回到默认值，并且只撤销这一步。
- 完整 Flutter 测试全部通过。测试使用单独的数据目录，没有动你正在用的照片和预设。
- 弹出菜单和小字在 Windows 实际缩放下是否清晰，需要你在真机上确认。

## 文件清单

新增：
- D:/AI Agent/LumaCraft/app/assets/ui/layer-material.svg
- D:/AI Agent/LumaCraft/app/test/photo_stroke_test.dart
- D:/AI Agent/LumaCraft/app/build/0.14.0/regroup_library.py
- D:/AI Agent/LumaCraft/app/docs/windows-photo-stroke-0.14.0.md
- D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.14.0-Authoring/（旧版本目录保留未动）

修改：
- D:/AI Agent/LumaCraft/app/lib/editor/background_style.dart、background_render.dart、style_document.dart、style_render.dart、preset_package.dart、palette_style.dart、palette_render.dart、builtin_library.dart
- D:/AI Agent/LumaCraft/app/lib/ui/editor/background_panel.dart、palette_panel.dart、editor_panels.dart、editor_page.dart、image_panel.dart、number_drag_input.dart、shape_panel.dart、postmark_picker.dart、component_picker.dart
- D:/AI Agent/LumaCraft/app/lib/ui/preset_panel.dart、preset_actions.dart
- D:/AI Agent/LumaCraft/app/lib/main.dart
- D:/AI Agent/LumaCraft/app/assets/builtins/library.json
- D:/AI Agent/LumaCraft/app/local/builtin-working.json（与上面的内置库同步，否则制作版仍会显示旧的工作副本）
- D:/AI Agent/LumaCraft/app/test/builtin_fonts_test.dart、number_drag_test.dart、refinements_test.dart
- D:/AI Agent/LumaCraft/app/pubspec.yaml（版本 0.14.0+41）
- D:/AI Agent/LumaCraft/项目台账.md

未改：你的照片、`editor-presets.json`、`photo-state.json`、`workspace.json`，以及以前的制作版目录。旧的邮戳图标文件还留在原处，只是界面不再使用它。

## 交付

D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.14.0-Authoring/lumacraft.exe。请保留完整目录，不要单独移动 EXE。
