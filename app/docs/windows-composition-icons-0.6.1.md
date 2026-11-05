# LumaCraft 0.6.1 · 构图图标角标

2026-11-05，版本 0.6.1+24。

预设卡片不再在名称下方显示构图文字。预览图左下角使用圆角细线画框图标：横图优先显示横框，竖图优先显示竖框，横竖通用显示两个图标。图标带柔和金色细节，置于半透明深色圆角底上，悬停显示文字含义。右上角的操作菜单与名称旁的收藏按钮保持原位。

移除文字行后缩紧卡片高度，预览图尺寸基本保持原来大小。浏览和编辑复用同一面板；构图筛选、保存标记以及实际适配逻辑保持原有功能。

## 文件清单

- D:/AI Agent/LumaCraft/app/assets/ui/layer-landscapeMark.svg：横图图标。
- D:/AI Agent/LumaCraft/app/assets/ui/layer-portraitMark.svg：竖图图标。
- D:/AI Agent/LumaCraft/app/lib/ui/preset_panel.dart：预览角标、悬停说明、移除文字行与卡片高度调整。
- D:/AI Agent/LumaCraft/app/test/preset_library_test.dart：在既有核心流程中检查三种图标状态，并验证卡片调整后的选择和框选。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号。
- 本说明、D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：交付记录。

## 验证

代码分析无问题；三项预设核心验证通过，包含横图/竖图单图标、通用双图标、不再显示构图文字，以及单选、多选、框选与分组操作。Windows release 编译通过。

初次编译因之前两个后台测试实例占用构建 EXE 失败；关闭已确认的测试进程后重编译成功。未关闭用户正在试用的 0.6.0 窗口。

日志：D:/AI Agent/LumaCraft/app/build/composition-icons-check.log、D:/AI Agent/LumaCraft/app/build/composition-icons-build-final.log。

交付：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.6.1/lumacraft.exe。只输出完整可运行文件夹，不生成压缩包，旧版保留。图标实际观感交用户试用确认。
