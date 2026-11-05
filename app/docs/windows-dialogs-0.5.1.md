# LumaCraft 0.5.1 · 弹窗、渐变与交互修正

版本0.5.1+19，2026-11-04。

- 保存预设改用框外独立标签，输入与错误提示分区；缩略图每行4项，最多2行，超出部分独立滚动。
- 管理与编辑弹窗复用WorkspaceDialog/WorkspaceTextField，共用明确字体、字号、行高、内边距，避免回落到不一致的默认样式。系统实际缩放下的文字清晰度仍需用户确认。
- 双色渐变支持线性/中心两种，中心渐变可调中心X/Y、扩散范围；保存、导出和.lmp同步支持。旧记录默认线性；旧软件会拒绝不支持的中心渐变能力。
- 移动分组下拉菜单中可新建分组，创建后自动选中；取消移动保留已创建的空分组。
- 预设缩略图空白处右键可新建分组。
- 文字字号取消输入、拖动缩放、.lmp校验的上限，保留最小8和有限数值校验。
- 共用底栏已编辑圆点移到照片预览内部左上角，使用金色和轻微外发光，文件名后不再显示。
- 图层开关延迟修复：样式复制不再JSON编解码，比较直接检查结构并共享不可变素材字符串；已应用状态检查也不重复编码。保留深复制、撤销、自动保存和状态判断。

## 文件清单
新增：D:/AI Agent/LumaCraft/app/lib/ui/workspace_dialog.dart。
修改：
- D:/AI Agent/LumaCraft/app/lib/ui/app_theme.dart：共用弹窗文字主题。
- D:/AI Agent/LumaCraft/app/lib/ui/preset_actions.dart：共用表单、移动中新建分组。
- D:/AI Agent/LumaCraft/app/lib/ui/preset_panel.dart：空白右键菜单。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart：共用弹窗、保存网格、应用快照。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_panels.dart：字号上限。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_canvas.dart：字号缩放、应用状态比较。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/workspace_chrome.dart：缩略图状态圆点。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/background_panel.dart：中心渐变参数。
- D:/AI Agent/LumaCraft/app/lib/editor/background_style.dart：渐变模型。
- D:/AI Agent/LumaCraft/app/lib/editor/background_render.dart：中心渐变绘制。
- D:/AI Agent/LumaCraft/app/lib/editor/preset_package.dart：中心渐变能力及字号兼容。
- D:/AI Agent/LumaCraft/app/lib/editor/style_document.dart：无JSON深复制与结构比较。
- D:/AI Agent/LumaCraft/app/lib/editor/editor_controller.dart：编辑历史的轻量比较。
- D:/AI Agent/LumaCraft/app/test/editor_core_test.dart、D:/AI Agent/LumaCraft/app/test/image_background_test.dart、D:/AI Agent/LumaCraft/app/test/preset_library_test.dart：相应核心验证。
- D:/AI Agent/LumaCraft/app/pubspec.yaml、D:/AI Agent/LumaCraft/AGENTS.md：版本及已要求记录的纠正。
- 本说明及 technical-validation.md、ui-prototype/design-notes.md：记录。

## 验证
十项核心流程通过，代码检查无问题。包含中心渐变像素/存储、空白右键新组、已有预设管理、实际保存应用、带长素材字符串的开关/撤销/深复制，以及JPG/PNG和EXIF。日志：D:/AI Agent/LumaCraft/app/build/dialog-gradient-check.log，构建日志同目录dialog-gradient-build.log。
不继续扩大测试；Windows文字观感及鼠标手感交用户试用确认。浏览器原型未同步本批新增内容。只输出可运行文件夹，保留旧版本。
程序：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.5.1/lumacraft.exe。

实机检查：使用独立测试数据打开Windows新版，查看保存弹窗；检查中窗口被继续操作，未继续自动点击。标签分离已接入，最终字体观感仍需用户确认，不声称已排除所有DPI/字体显示差异。
