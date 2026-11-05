# HSB标签排版与色卡描边间距

用户已确认本轮方案。使用 writing-plans / executing-plans 技能实施。

- H/S/B与HEX标签独立放在输入框上方7px，H/S/B同排等高、行间留白；保持取色功能。
- 新增strokeGap，范围0～10，默认0，步进0.1，按照片短边1000px规则并随整体缩放。
- 0保留原内描边；正值为色块与外描边之间的透明间隙。独立色块间距按含描边外轮廓计算，选框/吸附/对齐边界包含描边。连续色条保持六色相接，每块模式的内部五条分隔线原位不变，只外轮廓留间隙。
- 颜色、圆角、透明度、旧预设、取消/撤销兼容；不改已确认模式动画。

修改：palette_style.dart、palette_render.dart、palette_panel.dart、hsb_color_picker.dart及针对性检查、版本0.3.3与交付记录。只进行一轮核心检查及必要问题复现，不删除旧文件。

- [x] 属性存储与描边外扩绘制、选区几何。
- [x] 原生属性及HSB独立标签排版。
- [x] 核心像素/布局/旧功能检查、只读审查和打包。


## 2026-11-04 · 0.3.3 HSB排版与描边间距
按用户确认，H/S/B与HEX改为独立标签，间隔7px，输入框40px等高并调整内边距；非法HEX提示独立显示。色卡新增描边间距0～10px、默认0、步进0.1，随整体缩放；0保留内描边，正值形成外侧描边环及透明间隙。独立色块按含描边轮廓计算间距，连续色条只在外轮廓留间隙，内部五条分隔线原位。
共用paletteSize包含描边，六边形计入尖角外扩；独立saveLayer中的清除不擦除底层照片。原预设默认0兼容。六项核心一轮全部通过，含四形态间隙alpha/描边不截断/填充大小/连续色条内部alpha、存储范围、HSB标签7px与框高40px、既有取色/拖动/编辑导出及EXIF；最终HSB布局检查通过。代码检查无问题，Windows release编译成功，只读审查未发现确定的重要回归。
完整清单：D:/AI Agent/LumaCraft/app/docs/windows-stroke-gap-0.3.3.md；核心日志：D:/AI Agent/LumaCraft/app/build/stroke-gap-check.log；布局日志：D:/AI Agent/LumaCraft/app/build/hsb-layout-check.log。剩余真实照片与鼠标体验交用户试用，不扩大测试范围。
