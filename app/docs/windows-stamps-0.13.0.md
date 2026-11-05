# LumaCraft 0.13.0 · 邮票 / 车票边框、内置邮戳、纹理改为填充方式（制作版）

2026-11-05，版本0.13.0+40。此交付为制作版，沿用0.12.0的全部功能。

## 新功能

### 纹理改为一种填充方式
- “背景填充 → 填充方式”现在有四项：纯色、双色渐变、照片模糊、纹理。纹理不再和渐变、照片模糊叠加。
- 选“纹理”后，下方依次是：底色；纹理风格 + 纹理（并排）；不透明度；大小 + 纹理颜色（并排）。
- “纹理”选择框改成缩略图网格，和添加组件、编辑形状的下拉一样。缩略图用你当前的底色、纹理颜色和大小实时画出来。
- 原来单独的“边框纹理”区已取消。
- 0.12.0 保存的“纯色 + 纹理”预设读入时会自动变成纹理填充，画面不变。

### 边框造型：邮票打孔、车票样式
- 原“胶片打孔”区改名“边框造型”，用下拉选择：不启用 / 胶片打孔 / 邮票打孔。两种造型一次只能选一种。
- 邮票打孔可调：
  - 打孔位置：四边 / 上下 / 左右 / 短边（短边：横图打在左右，竖图打在上下）。
  - 纸张颜色。
  - 孔径、孔间距、外侧留白。孔数自动取整，均匀排满每条边，四角对称。
- 邮票纸比画布小一圈，纸外和孔里露出背景填充。外侧留白超过边框宽度时，纸边自动贴住照片。
- 开启邮票打孔时，如果填充方式选了纹理，纹理铺在邮票纸上，纸外只留底色。
- 车票样式开关打开后，可以再调：
  - 分割方向：横向（照片下方）、纵向（右侧票根）。
  - 分割线距照片的距离、线宽、虚线长、虚线间隔、颜色。
  - 两端半圆缺口的直径。

### 内置邮戳
- 3 款邮戳全部用代码画成矢量，内置在软件里，没有外部图片和版权问题：
  - 航空邮戳：双圈环形字、飞机、波浪线。
  - 波浪注销线。
  - 椭圆邮戳。
- 墨色有灰、蓝、红、黑四种，带随机做旧斑驳。
- 使用方法：选中任意图片组件，在“图片素材”里点“内置邮戳”，从缩略图中选一款。
  - 选中邮戳后会多出“邮戳墨色”，点一下就能换色。
  - 只换墨色时保持当前大小；换样式时用该样式的默认大小。
- 邮戳作为普通图片组件保存：可以移动、缩放、调不透明度，分享给别人时也会一起带上。

## 内置预设：创意边框新增 6 款

| 名称 | 说明 |
|---|---|
| 邮票·模糊背景 | 仿参考图1：模糊背景上一张四边打孔的白色邮票纸，左下标题、地点、时间，右下灰色航空邮戳 |
| 车票 | 仿参考图2：上下打孔，照片下方虚线分割，两端半圆缺口 |
| 自然诗篇 | 仿参考图3：顶部标题和“PHOTOGRAPHED IN · 拍摄时间”，底部左边色带，右边机型、参数、地点（用地点组件代替坐标） |
| 牛皮纸邮票 | 牛皮纸纹理铺在邮票纸上，红色椭圆邮戳 |
| 票根 | 纵向分割，右侧票根上放机型、地点、时间和蓝色波浪戳 |
| 复古邮票 | 奶油色纸，照片角上印面值，红色航空戳压住照片右下角 |

- 6 款都排在“创意边框”分组末尾，并分别排好了横图、竖图、方图版面。
- 原有 16 款纹理预设已改成新的“纹理”填充方式，画面不变。
- 制作版里可以直接修改这些内置预设。定稿后告诉我，我再打包发行版。

## 兼容性

- 分享成 `.lmp` 时会按实际用到的功能加标记：
  - 纹理填充：`textureFill`。
  - 邮票 / 车票：`stampV1`。
- 旧版软件导入这些预设时会明确提示不支持，不会悄悄画错。
- 0.12.0 导出的带纹理 `.lmp` 仍可正常导入。

## 验证

- 新增 `test/stamp_test.dart` 共 5 项：
  - 四种打孔位置的孔洞落点，以及短边随横竖图切换。
  - 留白超过边框时纸边贴住照片；横向和纵向两种车票分割线。
  - 邮票参数的保存与读取；开启邮票后不再画胶片孔；分享文件的新标记，以及拒绝无效的打孔位置。
  - 实际出图检查：纸、孔洞、分割线都在边框里，照片像素不变。
  - 3 款 × 4 色邮戳都能生成透明 PNG，并能从文件名认出。
- `test/texture_film_test.dart` 已按新的纹理填充方式更新，并新增 0.12.0 旧数据转换的检查。
- 完整 Flutter 测试共 59 项，全部通过。
- 面板截图检查（测试环境）：纹理填充面板、纹理缩略图下拉、车票参数面板、造型下拉、内置邮戳选择和换墨色。截图在 `D:/AI Agent/LumaCraft/app/build/stamp-presets/panel/`。
- 弹出菜单和小字在 Windows 实际缩放下是否清晰，需要你在真机上确认。

## 文件清单

新增：
- D:/AI Agent/LumaCraft/app/lib/editor/postmark.dart
- D:/AI Agent/LumaCraft/app/lib/ui/editor/texture_picker.dart
- D:/AI Agent/LumaCraft/app/lib/ui/editor/postmark_picker.dart
- D:/AI Agent/LumaCraft/app/assets/ui/layer-postmark.svg
- D:/AI Agent/LumaCraft/app/test/stamp_test.dart
- D:/AI Agent/LumaCraft/app/build/stamp-presets/drafts_test.dart、panel_test.dart、merge_into_library.py、drafts.json、out/、panel/
- D:/AI Agent/LumaCraft/app/build/new-presets/texture_fill_migrate.py
- D:/AI Agent/LumaCraft/app/docs/windows-stamps-0.13.0.md
- D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.13.0-Authoring/（旧版本目录保留未动）

修改：
- D:/AI Agent/LumaCraft/app/lib/editor/background_style.dart、background_render.dart、style_document.dart、preset_package.dart
- D:/AI Agent/LumaCraft/app/lib/ui/editor/background_panel.dart、editor_panels.dart、editor_page.dart、image_panel.dart
- D:/AI Agent/LumaCraft/app/assets/builtins/library.json（16 款改为纹理填充；新增 6 款）
- D:/AI Agent/LumaCraft/app/test/texture_film_test.dart
- D:/AI Agent/LumaCraft/app/build/new-presets/drafts_test.dart（纹理改为填充方式）
- D:/AI Agent/LumaCraft/app/pubspec.yaml（版本 0.13.0+40）
- D:/AI Agent/LumaCraft/项目台账.md

## 交付

D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.13.0-Authoring/lumacraft.exe。请保留完整目录，不要单独移动 EXE。
