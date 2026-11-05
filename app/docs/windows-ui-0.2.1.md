# LumaCraft 0.2.1 · 第一步界面试用包

日期：2026-11-04。版本：0.2.1+6。
本次仅包含第一步界面调整。第二步过渡动画优化已按用户要求暂缓；程序继续使用原有切换动画。

## 调整内容
- 编辑器属性面板以浏览器原型为基准：强化分区标题，统一标签与提示文字颜色/字重/行高，调整字段间距，数值不再显示无意义的 .0。
- 复制/删除按钮移到位置与锚点之后、组件对齐之前，使用原型的中性背景、圆角和删除提示色；组件对齐六按钮加入深色背景分组。
- 两种模式共用顶栏，明暗切换、布局按钮、窗口按钮尺寸与间距相同；最大化状态共用通知。
- 浏览模式右侧恢复“预设 / 信息”页签。信息页按设备、曝光、时间与地点分区，使用中性色信息卡、不同字号和字重；缺失及补填状态明确标识。此项替换 0.2.0 的信息底置方案。
- 两种模式共用底栏，统一照片计数、无图标的全选/取消选择按钮、缩略图尺寸、选中状态、修改标记及滚动条。
- 侧栏铺满时，侧栏在底栏之后绘制，阴影覆盖底栏；底栏铺满时反之。沿用原有面板动画与拖动调节，不新增模式过渡效果。

## 使用
运行同目录 lumacraft.exe。请保留 data 和 DLL 文件，或将整个文件夹一起移动。
旧版 0.2.0 保留，新包单独存放在 D:\AI Agent\LumaCraft\app\dist\LumaCraft-0.2.1。
预设编辑、保存、应用、导出方式与 0.2.0 相同。正常启动继续读取原有本地记录，不改动照片原文件。

## 本轮修改清单
- D:/AI Agent/LumaCraft/app/lib/ui/editor/workspace_chrome.dart：新增共用顶栏与底栏。
- D:/AI Agent/LumaCraft/app/lib/main.dart：接入共用组件、预设/信息页签与分区信息页；保留 MaterialPageRoute 原切换方式。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart：共用顶栏/底栏、编辑标记；不包含第二步过渡代码。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_panels.dart：属性排版、操作按钮、对齐背景与数值显示。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/prototype_controls.dart：共用标题、标签、提示、数值文字样式。
- D:/AI Agent/LumaCraft/app/lib/ui/workspace_layout.dart：按铺满方向切换面板绘制层级。
- D:/AI Agent/LumaCraft/app/lib/window_controls.dart：共用最大化状态。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号。
- D:/AI Agent/LumaCraft/app/test/editor_core_test.dart：适配整数形式的边框输入值。
- D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：验证和需求记录。

## 验证
代码检查无问题。单轮核心检查三项通过：样式/分组/锚点与保存、真实照片编辑→保存→应用、JPG/PNG 导出及 EXIF。只读审查未发现确定的重要回归。
不扩大测试范围，其余界面体验交用户试用。检查输出保留于 D:/AI Agent/LumaCraft/app/build/editor-core-check.log。
