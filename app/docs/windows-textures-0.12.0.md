# LumaCraft 0.12.0 · 边框纹理、胶片沿长边、新增 27 款创意边框（制作版）

2026-11-05，版本0.12.0+39。此交付为制作版，沿用0.11.1的全部功能。

## 新功能

### 胶片打孔：沿长边
编辑器“胶片打孔 → 排列位置”新增“沿长边”：横图、方图的孔洞排在上下，竖图排在左右。孔宽、孔高按横图填写，竖图自动转向。横竖图的不同版面只用来调整文字和边框位置。

### 边框纹理
编辑器“背景填充”下方新增“边框纹理”。先选纹理风格，再选具体纹理，共18种：

| 风格 | 纹理 |
|---|---|
| 纸张 | 细纹纸、牛皮纸、宣纸、水彩纸 |
| 织物 | 亚麻布、帆布 |
| 简洁 | 细点阵、细斜纹、细网格 |
| 高级 | 大理石、磨砂颗粒、拉丝金属 |
| 可爱 | 波点、小星星、格纹 |
| 科技 | 电路线、蜂窝、扫描线 |

- 可调不透明度、大小（50%～300%）和纹理颜色；纯色、渐变、照片模糊三种背景都能叠加。
- 纹理只铺在边框上，不画到照片上。
- 全部由软件自己生成，不用外部图片，没有版权问题。
- 纸张、织物、大理石、磨砂、拉丝这类材质纹理第一次使用时会在后台生成，预览会稍晚一点出现；导出时一定等生成完再画。

## 内置预设：创意边框新增27款

| 编号 | 名称 | 编号 | 名称 | 编号 | 名称 |
|---|---|---|---|---|---|
| 1 | 模糊相框·居中 | 10 | 宣纸题印 | 19 | 星星便签 |
| 2 | 模糊相框·底栏 | 11 | 牛皮纸信笺 | 20 | 蜂窝科技 |
| 3 | 宝丽来 | 12 | 水彩手账 | 21 | 扫描线 HUD |
| 4 | 底片孔洞 | 13 | 亚麻画布 | 22 | 大理石画廊 |
| 5 | 展览标牌 | 14 | 诗集扉页 | 23 | 网格极简 |
| 6 | 色板边框 | 15 | 色带边框 | 24 | 野餐格纹 |
| 7 | 极简黑框 | 16 | 色卡标签 | 25 | 电路板 |
| 8 | 暮色渐变 | 17 | 模糊色卡 | 26 | 拉丝金属 |
| 9 | 双线相框 | 18 | 波点糖果 | 27 | 磨砂黑卡 |

- 都排在“创意边框”分组里，接在原有3款之后。每款都分别排好了横图、竖图、方图版面。
- 4号底片孔洞：孔洞沿长边；竖图只留左右两条带孔黑边，帧号、机型、参数直接叠在照片底部。
- 制作版里可以直接修改这些内置预设，定稿后告诉我封发行版。

## 兼容性

用了“沿长边”或边框纹理的预设，分享成 `.lmp` 时会带上新标记（`filmLongEdge`、`textureV1`）。旧版软件导入时会明确提示不支持，不会悄悄画错。

## 验证

- 新增 `test/texture_film_test.dart` 共5项：沿长边在横、竖、方图上的位置与孔洞转向；纹理参数保存读取；分享文件新标记与未知纹理拒绝；9种材质图块都有明暗变化；18种纹理只改边框、不改照片。
- 完整 Flutter 测试共54项通过。
- 查明 `export_workspace_flow_test` 偶发失败的原因：测试会在数据目录里留下导出文件，重复使用同一个测试数据目录时，第二次运行会误报。换新目录即全部通过，与软件功能无关。

## 文件清单

新增：
- D:/AI Agent/LumaCraft/app/lib/editor/texture_render.dart
- D:/AI Agent/LumaCraft/app/test/texture_film_test.dart
- D:/AI Agent/LumaCraft/app/build/new-presets/textures_test.dart、merge_into_library.py
- D:/AI Agent/LumaCraft/app/docs/windows-textures-0.12.0.md
- D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.12.0-Authoring/（旧版本目录保留未动）

修改：
- D:/AI Agent/LumaCraft/app/lib/editor/background_style.dart、background_render.dart、style_render.dart、preset_package.dart
- D:/AI Agent/LumaCraft/app/lib/ui/editor/background_panel.dart、editor_page.dart、editor_panels.dart
- D:/AI Agent/LumaCraft/app/assets/builtins/library.json（新增27款）
- D:/AI Agent/LumaCraft/app/build/new-presets/drafts_test.dart、drafts.json
- D:/AI Agent/LumaCraft/app/pubspec.yaml（版本0.12.0+39）
- D:/AI Agent/LumaCraft/项目台账.md

## 交付

D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.12.0-Authoring/lumacraft.exe。请保留完整目录，不单独移动EXE。
