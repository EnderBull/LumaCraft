# LumaCraft 0.2.2 · 界面修正试用包

日期：2026-11-04。版本：0.2.2+7。

## 本次调整
- 侧栏铺满布局：在面板上方独立绘制侧栏内缘阴影，完整延伸到底栏，避免被底栏的不透明内容遮住；不拦截鼠标操作。
- 字体、相对区域、画布比例三个下拉入口共用新的选框：深色圆角、柔和阴影、中性选中背景和金色标记，支持键盘导航、Esc 和点击外部关闭。按用户补充要求，展开与收起均无过渡动画。
- 图层面板添加组件加号恢复正常尺寸，去掉压缩图标的内部留白。
- 图层拖动手柄调整为清楚的两列三行六点。
- 图层列表后的说明改为原型中的四行，顶部间距 30，降低不透明度。
- 下拉弹层打开时暂停编辑页全局快捷键，避免方向键同时移动后台组件、Esc 清空组件选择。

模式切换过渡动画的第二步优化仍暂缓。照片原文件、导出方式、预设保存方式保持现有逻辑。

## 使用
运行同目录的 lumacraft.exe。data 文件夹和 DLL 必须与程序放在一起；移动或分享时请使用完整文件夹或 ZIP 包。

新包目录：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.2.2。
压缩包：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.2.2-windows-x64.zip。
旧版本保留。

## 文件清单
- D:/AI Agent/LumaCraft/app/lib/ui/workspace_layout.dart：侧栏阴影覆盖层。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/prototype_controls.dart：共用下拉选框与无动画弹层。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_panels.dart：字体和相对区域选框、加号尺寸、说明文字、拖动手柄。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_canvas.dart：画布比例选框。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart：弹层打开时暂停后台编辑快捷键。
- D:/AI Agent/LumaCraft/app/assets/ui/layer-grip.svg：六点图标视区。
- D:/AI Agent/LumaCraft/app/test/editor_core_test.dart：核心流程加入下拉键盘隔离检查。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号。
- 本说明及 technical-validation.md、2026-11-04-windows-editor.md、ui-prototype/design-notes.md：交付与验证记录。

## 验证
- 代码检查：No issues found。
- 核心三项通过：样式/分组/锚点/撤销/存储；照片编辑→保存→应用；JPG/PNG 导出保留 EXIF、移除 GPS。
- 审查发现并复现下拉键盘穿透问题，修复后通过核心检查；日志：D:/AI Agent/LumaCraft/app/build/editor-core-check-0.2.2.log。
- 原生 Windows 窗口查看了侧栏铺满下底栏两侧的阴影、正常尺寸加号、六点手柄、说明文字以及新下拉弹层。
- 剩余界面体验由用户试用，不扩大测试范围。
