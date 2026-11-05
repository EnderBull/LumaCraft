# LumaCraft 0.3.0 · 照片色卡

版本：0.3.0+11。日期：2026-11-04。

## 使用入口
进入编辑模式 → 添加组件 → 照片色卡。组件属性中可设置：
- 展示形式：独立色块 / 连续色条。
- 独立色块形状：圆形、圆角矩形、六边形。
- 圆形直径；矩形宽高；六边形边长；独立色块间距。
- 矩形、六边形或连续色条的圆角，按形状尺寸限制有效范围。
- 描边开关、粗细和颜色；连续色条可选整体或每块描边。
- 六色顺序反转、整体缩放、透明度、位置和锚点。

支持画布选择、拖动、右下角手柄等比缩放、复制、图层排序、分组、锁定、对齐、吸附、撤销和重做。多选包含不同类型组件时只显示共同属性。

## 提色与保存
- 从原照片最长边96px的小图采样，在后台按占比和颜色差异选择六种代表色，按明度排序。
- 提色结果缓存按文件路径、修改时间和长度区分；拖动及修改外观不重复提色。
- 预览、预设缩略图和导出读取同一套原文件提色结果，边框和组件不参与提色。
- 单色或颜色很少的照片允许出现重复、相近颜色，不生成额外色相。
- 预设保存提色规则和组件外观，套用到其他照片时自动使用那张照片的配色。
- 整体缩放同时缩放色块、间距、圆角及描边。描边位于内部，连续色条分隔线只画一次。
- 透明度作用于整组，避免描边与填充叠加变浓。提色失败显示提示，可重试。

现有260ms模式切换与下拉菜单即时展开保持原样。新增色卡预设请使用0.3.0或更新版本打开。

## 运行与交付
程序：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.3.0/lumacraft.exe。
完整包：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.3.0-windows-x64.zip。
请保留所有DLL及data文件夹。旧版本保留，原照片不修改。

## 文件清单
- D:/AI Agent/LumaCraft/app/lib/editor/photo_palette.dart：原文件提色、后台代表色计算及缓存。
- D:/AI Agent/LumaCraft/app/lib/editor/palette_style.dart：色卡属性与JSON存储。
- D:/AI Agent/LumaCraft/app/lib/editor/palette_render.dart：四种形态、圆角、内描边与统一透明度。
- D:/AI Agent/LumaCraft/app/lib/editor/style_document.dart：照片色卡节点。
- D:/AI Agent/LumaCraft/app/lib/editor/style_render.dart：共享画布、缩略图及导出接入。
- D:/AI Agent/LumaCraft/app/lib/main.dart：工作台预览传递照片来源。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart：异步提色及错误状态。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_canvas.dart：色卡等比缩放。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_panels.dart：添加入口、属性分流及预设缩略图。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/palette_panel.dart：原生色卡属性面板。
- D:/AI Agent/LumaCraft/app/assets/ui/layer-palette.svg：新增色卡图标。
- D:/AI Agent/LumaCraft/app/test/palette_core_test.dart：色卡核心验证。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号。
- 本说明、D:/AI Agent/LumaCraft/app/docs/superpowers/plans/2026-11-04-photo-palette.md、D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：计划与交付记录。

## 验证
代码检查与最终一轮核心检查记录见 technical-validation.md；日志：D:/AI Agent/LumaCraft/app/build/palette-core-check.log。
已检查六色/单色提取、存储撤销、形状绘制、整组透明度、实际PNG色块逐通道与原文件提色一致，以及旧版编辑→保存→应用→模式返回、JPG/PNG EXIF流程。
原生窗口已核对添加色卡、三种形状选项、圆形到六边形切换及对应边长/间距/圆角属性。使用项目内独立样片与记录，未改用户照片或预设。

剩余真实照片观感由用户试用。图片标识与背景填充按已确认顺序留到下一批，不包含在本包。
