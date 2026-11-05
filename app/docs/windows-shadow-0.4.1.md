# LumaCraft 0.4.1 · 照片投影与自由定位

版本：0.4.1+17。日期：2026-11-04。

## 本次修改

- 画布面板按“背景填充 → 照片投影 → 胶片打孔”排列。
- 投影可开关，颜色默认黑色，使用已有 HSB 取色板。角度 0～360°、距离 0～200px、大小 0～100px、不透明度及羽化程度 0～100%；大小表示扩展范围，羽化表示边缘柔和程度。角度采用光源方向，投影朝反方向偏移。尺寸以照片短边 1000px 为基准。
- 投影位于照片下方，限制在最终成片范围内；随预设和照片样式保存，预览与导出一致。旧样式默认不启用。
- 模糊背景“明暗”改为“明度”；明度、对比度、饱和度同一行三列。
- 胶片孔宽、孔高、圆角同一行三列；孔间距、距外缘同一行两列。
- 移除画布底部尺寸说明和添加组件按钮，保留上方添加组件入口和必要状态提示。
- 锚点不再限制组件位置。组件可跨越照片、边框及画布区域，X/Y 可为负值或超过100%。单选、多选、编组、方向键、对齐与复制沿用该规则，移动时保留原锚点；锚点只决定尺寸适配的换算基准。
- 切换锚点换算坐标保持位置；零高度下边框使用照片区域作为稳定换算基准。保留原有边框归零时将对应组件移入照片区域的功能。
- 后续交付只输出可运行文件夹，不额外生成压缩包，已记录根目录执行约束。

## 文件清单

修改：

- D:/AI Agent/LumaCraft/app/lib/editor/background_style.dart：投影参数。
- D:/AI Agent/LumaCraft/app/lib/editor/background_render.dart：投影共用绘制。
- D:/AI Agent/LumaCraft/app/lib/editor/style_document.dart：投影存储、自由坐标和零高度基准。
- D:/AI Agent/LumaCraft/app/lib/editor/style_render.dart：投影位于背景之后、照片之前。
- D:/AI Agent/LumaCraft/app/lib/editor/editor_controller.dart：移除移动与复制的锚点区域限制。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/background_panel.dart：投影属性、三列/两列排版和文字。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_panels.dart：属性输入范围、区块顺序及移除底部入口。
- D:/AI Agent/LumaCraft/app/test/image_background_test.dart：投影像素、颜色与撤销、排版及移除项验证。
- D:/AI Agent/LumaCraft/app/test/editor_core_test.dart：跨区域移动、混合锚点编组、切换锚点、复制、零高度和极薄边框验证。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号。
- D:/AI Agent/LumaCraft/AGENTS.md：仅文件夹交付偏好。
- D:/AI Agent/LumaCraft/框印工坊-LumaCraft-产品设计方案.md：本次已确认规则。
- D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：交付记录。

新增：本说明及 D:/AI Agent/LumaCraft/app/docs/superpowers/plans/2026-11-04-photo-shadow.md。

## 验证与交付

代码分析无问题。核心流程验证通过：投影颜色/半透明/羽化、前景不变、取色撤销、属性排版、自由移动与编组、预设存储、原有编辑应用、JPG/PNG 导出与 EXIF。只读代码审查未发现阻断问题，不扩大测试范围。剩余真实照片观感和鼠标体验交用户试用。

日志：D:/AI Agent/LumaCraft/app/build/photo-shadow-check.log、D:/AI Agent/LumaCraft/app/build/free-anchor-check.log、D:/AI Agent/LumaCraft/app/build/photo-shadow-build.log。

运行：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.4.1/lumacraft.exe。
保留同目录 DLL 和 data 文件夹，旧版本保留。本次不生成压缩包，浏览器原型未同步新增内容。
