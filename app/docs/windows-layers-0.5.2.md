# LumaCraft 0.5.2 · 图层开关与原位改名

版本0.5.2+20，2026-11-04。

## 修改
- 图层显示/隐藏、锁定/解锁按钮排除在双击识别及行选择监听之外，不再等待整行双击超时，也不切换选中对象或右侧属性页。
- 仅组件及组件组的名称响应双击，在列表原位编辑名称。Enter或失焦提交、Esc取消、空名不提交；只改变图层名称，不改变自由文字内容或分组关系。
- 组件图标只保留单击选择。名称编辑期间禁用该行拖动，避免文字编辑触发排序；其他时刻仍沿用原有拖动排序。

## 原因与验证
原来整行GestureDetector包含按钮，DoubleTapGestureRecognizer会hold手势竞争，等待约300ms判断第二次点击。此前优化序列化没有解决这个手势冲突，而pumpAndSettle形式的验证会掩盖等待。
本次对照恢复整行双击识别，下一帧断言失败；恢复修复后同一断言通过。四种开关均在测试下一帧16ms生效，选择及属性页不变。原位组件/组改名、Enter/Esc、内容及组成员不变通过；既有编辑保存应用、撤销、JPG/PNG导出和EXIF通过。共六项核心全绿，代码分析无问题；实际设备耗时不是固定16ms承诺，剩余手感交用户试用。
日志：D:/AI Agent/LumaCraft/app/build/layer-toggle-before.log、D:/AI Agent/LumaCraft/app/build/layer-toggle-after.log、D:/AI Agent/LumaCraft/app/build/layer-toggle-build.log。

## 文件清单
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_panels.dart：缩小手势范围，列表原位改名控件。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart：名称编辑行状态。
- D:/AI Agent/LumaCraft/app/test/editor_core_test.dart：即时响应及原位改名验证。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本。
- 本说明，以及 D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：交付记录。

运行：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.5.2/lumacraft.exe。保留DLL及data文件夹，不生成压缩包，旧版本保留。
