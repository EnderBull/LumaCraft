# LumaCraft 0.4.0 · 图片标识与背景装饰

版本：0.4.0+16。日期：2026-11-04。

## 使用

- 编辑模式 → 添加组件 → 图片标识：选择 PNG/JPG。支持透明 PNG、替换素材、等比宽高、不透明度、拖动缩放、图层顺序、分组和对齐。
- 素材副本随草稿、预设、照片样式保存，不依赖源文件路径。单次导入上限 12 MB，最长边超过 2048 px 等比缩小；PNG 保留透明，JPG 保持压缩存储。
- 画布 → 背景填充：纯色、双色渐变、照片模糊。渐变支持两种颜色、方向和交换；纯色及渐变可使用照片提色。颜色块使用已有 HSB 取色板。
- 照片模糊：模糊强度 0～100，明暗 -100～100，对比度和饱和度 0～200%；对比度/饱和度 100% 为原值。仅调整背景，前景不变，背景跟随当前照片。
- 画布 → 胶片打孔：与填充分开，可叠加使用；左右或上下双侧排列，调孔宽高、间距、圆角、距外缘距离、孔色。排列沿边缘延伸并裁出半孔，不强制两端对称留白。
- 孔洞为模拟装饰，不挖空成透明像素；只绘制在边框内。对应边框空间不足或为零时暂不显示该侧，保留设置并提示。
- 胶片和组件尺寸以照片短边 1000 px 为基准。沿用数值拖动、一次撤销、HSB、两列参数排版和已确认的模式动画。

## 文件清单

新增：

- D:/AI Agent/LumaCraft/app/lib/editor/background_style.dart：背景和胶片参数。
- D:/AI Agent/LumaCraft/app/lib/editor/background_render.dart：共用背景、调色和孔洞绘制。
- D:/AI Agent/LumaCraft/app/lib/editor/image_mark.dart：素材导入、内嵌存储、解码缓存及使用期保护。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/background_panel.dart：填充和装饰属性。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/image_panel.dart：图片标识导入、替换和属性。
- D:/AI Agent/LumaCraft/app/assets/ui/layer-image.svg、D:/AI Agent/LumaCraft/app/assets/ui/ui-swap.svg：同风格图标。
- D:/AI Agent/LumaCraft/app/test/image_background_test.dart：核心流程及异步资源回归验证。
- D:/AI Agent/LumaCraft/app/docs/superpowers/plans/2026-11-04-image-background.md：实施计划与记录。
- 本说明文件。

修改：

- D:/AI Agent/LumaCraft/app/lib/editor/style_document.dart：兼容旧样式的扩展字段。
- D:/AI Agent/LumaCraft/app/lib/editor/style_render.dart：共用预览与导出，图片预加载及资源保护。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart：素材加载和快速切换处理。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_panels.dart：新属性入口、图标与混合选择。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_canvas.dart：图片等比缩放和加载提示。
- D:/AI Agent/LumaCraft/app/test/editor_core_test.dart：精确定位背景取色控件，适配新增快捷色。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号。
- D:/AI Agent/LumaCraft/框印工坊-LumaCraft-产品设计方案.md：已确认的背景、打孔及图片素材规则。
- D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：交付记录。

## 验证与边界

代码分析无问题。核心验证覆盖旧格式读取、素材随预设重载、透明区域及不透明度、渐变、背景去饱和及前景不变、边缘半孔和零边框、无效素材显式报错、现有编辑保存应用及 JPG/PNG EXIF。

审查发现并修复快速切换漏载和缩略图挤掉当前素材两项问题；新增真实编辑器快速切换及 20 份素材的缓存压力验证通过。日志：D:/AI Agent/LumaCraft/app/build/image-background-check.log、D:/AI Agent/LumaCraft/app/build/image-background-resource-check.log。

此次接入 Windows 软件，浏览器原型未同步新增功能。预设分享文件的导入导出仍在后续范围，当前素材已随本地预设保存。剩余真实照片效果与鼠标手感由用户试用，不继续扩大测试。

程序：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.4.0/lumacraft.exe。
压缩包：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.4.0-windows-x64.zip。
解压后保留 DLL 和 data 文件夹，旧版本保留。
