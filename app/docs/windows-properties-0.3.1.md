# LumaCraft 0.3.1 · 属性面板与数值拖动

版本：0.3.1+12。日期：2026-11-04。

## 调整
- 色卡外观改为形式/形状、宽度/高度、间距/圆角三组两列。圆形与六边形的单尺寸项铺满整行；圆形只显示间距。连续色条按可用属性排列，不留空格。
- 所有组件属性统一使用“不透明度”文案；色卡、文字及混合多选共用滑块和百分比。浏览器原型同步文案。
- 描边开关视觉尺寸30×16，点击区域42×32。
- 编辑器中的尺寸、字号、字间距、边框、坐标、圆角、描边粗细和整体缩放等数值框统一支持左键拖动调值。

## 数值输入操作
点击数值可选中并键盘输入；按住数值框拖动，向右/上增加，向左/下减少。经过4px起动阈值后锁定横轴或纵轴，斜向移动不会双倍叠加。
Shift加速十倍，Alt精细至十分之一；各参数保留原有上下限，支持小数。一次拖动只产生一次编辑撤销，拖动结束释放文本焦点，Ctrl+Z交给编辑器撤销整次操作。指针取消会回滚本次拖动。
文字、名称及颜色色值输入框继续正常编辑，不参与数值拖动。

## 使用
程序：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.3.1/lumacraft.exe。
完整包：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.3.1-windows-x64.zip。
保留同目录所有DLL及data文件夹。旧版本保留。

## 文件清单
- D:/AI Agent/LumaCraft/app/lib/ui/editor/number_drag_input.dart：新增共用数值拖动输入和手势处理。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_panels.dart：数值框接入、提交规范值、撤销事务、共用不透明度滑块。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/palette_panel.dart：两列排版、不透明度滑块、小描边开关。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart：引入共用数值输入。
- D:/AI Agent/LumaCraft/app/ui-prototype/editor/editor.js、D:/AI Agent/LumaCraft/app/ui-prototype/editor/editor-objects.js：不透明度文案。
- D:/AI Agent/LumaCraft/app/test/number_drag_test.dart：输入、双轴、修饰键、限值、主轴锁定、取消及撤销检查。
- D:/AI Agent/LumaCraft/app/test/editor_core_test.dart：真实属性面板三组同排、色卡滑块、宽度拖动与撤销。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号。
- 本说明、D:/AI Agent/LumaCraft/app/docs/superpowers/plans/2026-11-04-property-controls.md、D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：计划与交付记录。

## 验证
代码检查无问题；一轮五项核心检查全部通过，包含共用数值控件、色卡提色/存储/绘制/导出、既有编辑保存应用模式返回及EXIF。实际编辑器组件检查了三组两列排版、不透明度滑块和宽度拖动撤销。
另对主轴锁定和指针取消做了针对性检查，通过。只读审查未发现确定的重要回归；Windows release编译成功。
日志：D:/AI Agent/LumaCraft/app/build/property-controls-check.log、D:/AI Agent/LumaCraft/app/build/number-drag-check.log。
其余实际鼠标手感由用户试用，不扩大测试范围。图片标识及背景填充仍留下一批。
