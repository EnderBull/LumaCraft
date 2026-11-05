# LumaCraft 0.6.3 · 统一预设缩略图

2026-11-05，版本0.6.3+26。

新增共用 PresetThumbnail 装饰控件，统一为预设图片添加左下角构图标记。横图/竖图各一个图标，横竖通用两个；底板不透明度55%，边缘2.5px柔化，图标保持清晰。小缩略图按可用空间缩小图标、内边距及圆角；底板不透明度与柔化参数不变。

覆盖浏览/编辑的预设面板、保存预设、管理分组概览及详情、导入确认。新建预设的加号卡片不显示构图图标。主工作区照片预览不属于预设缩略图，不叠加角标。

控件只负责图片上的角标装饰，原有图片渲染、缓存、选择边框、菜单和收藏操作由原来的界面保留，避免重复套用角标及改动选择逻辑。

## 文件清单

- D:/AI Agent/LumaCraft/app/lib/ui/preset_thumbnail.dart：共用缩略图与构图角标、尺寸适配。
- D:/AI Agent/LumaCraft/app/lib/ui/preset_panel.dart：卡片使用共用控件，移出原有私有角标实现。
- D:/AI Agent/LumaCraft/app/lib/ui/preset_actions.dart：导入确认预览使用共用控件。
- D:/AI Agent/LumaCraft/app/lib/ui/folder_manager.dart：概览和详情统一使用共用控件。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart：引入共用控件。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_panels.dart：保存预设缩略图加入角标，包括无照片时的占位预览。
- D:/AI Agent/LumaCraft/app/test/preset_library_test.dart：在既有流程检查分组概览、详情的共用缩略图与选择操作。
- D:/AI Agent/LumaCraft/app/test/editor_core_test.dart：在既有保存流程检查保存面板中现有预设的角标。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号。
- 本说明、D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：交付记录。

## 验证

九项受影响的预设与编辑核心验证通过。新增检查最初使用精确类名查找弹窗，未匹配共用弹窗子类；修正查找方式后该核心流程重跑通过。代码分析无问题。导入确认已接入同一控件并参与编译，未增加原生文件选择器的自动化操作。

日志：D:/AI Agent/LumaCraft/app/build/shared-preset-thumbnail-check.log（首轮）、D:/AI Agent/LumaCraft/app/build/shared-preset-thumbnail-recheck.log（修正验证查找后通过）、D:/AI Agent/LumaCraft/app/build/shared-preset-thumbnail-build.log（编译）。

交付：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.6.3/lumacraft.exe。只输出完整可运行文件夹，不生成压缩包；旧版本保留。剩余视觉观感与操作体验交用户试用。
