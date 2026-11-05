# LumaCraft 0.6.4 · 编辑信息与预设筛选

2026-11-05，版本0.6.4+27。

- 编辑页预设名从顶栏移至主面板左上角，与文件名以“ · ”分隔，统一60%中性色文字，长文本省略。
- 共用表单内容列改为按内容收缩，修复新建分组窗口纵向撑满的问题；错误提示独立排布。
- 缺少EXIF时，镜头/相机/时间/地点/拍摄参数组件在编辑画布显示缺失提示并保留可选中边界。部分拍摄参数存在时显示已有内容；自由文字留空不强制提示。占位仅用于编辑，不进入预设缩略图、浏览预览或导出。
- 侧栏提示移至共用底栏顶部居中，取消背景，保留强调色文字。宽度不足时单独占一行，避开选择和快捷键区域。
- 预设筛选压缩为同一行：构图切换、分组下拉、管理分组。构图按钮为图标加简短文字，依次循环全部/通用/横图/竖图，悬停显示含义。横竖复用已确认图标，全部/通用采用相同圆角、1.65线宽及柔和金色细节的新SVG。下拉菜单仍直接开关。

## 文件

- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart：不再向顶栏传入预设名。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_canvas.dart：文件名与预设名并列、编辑缺失信息开关。
- D:/AI Agent/LumaCraft/app/lib/editor/style_render.dart：仅编辑启用的缺失信息显示和边界计算。
- D:/AI Agent/LumaCraft/app/lib/ui/workspace_dialog.dart：独立标签表单内容按需收缩。
- D:/AI Agent/LumaCraft/app/lib/ui/preset_panel.dart：紧凑筛选、移除顶部提示块。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/workspace_chrome.dart：共用底栏居中提示及窄空间适配。
- D:/AI Agent/LumaCraft/app/lib/main.dart、D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_panels.dart：浏览/编辑底栏提示来源。
- D:/AI Agent/LumaCraft/app/assets/ui/layer-compositionAll.svg、D:/AI Agent/LumaCraft/app/assets/ui/layer-compositionUniversal.svg：同风格构图筛选图标。
- D:/AI Agent/LumaCraft/app/test/workspace_refinements_test.dart：缺失信息显示范围、60个分组时弹窗内容高度与错误提示。
- D:/AI Agent/LumaCraft/app/test/preset_library_test.dart：既有选择/分组流程和四态筛选循环。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号；本说明及技术/设计记录同步更新。

## 验证

两项新增与九项既有核心验证通过。弹窗尺寸最初误量了全屏路由容器，改为核对标题至按钮的实际内容跨度后通过；修正项和构图切换相关流程重跑通过。代码分析无问题。截图附件中的视觉问题按现有共用字体、颜色和控件处理，系统缩放观感与剩余操作体验交用户试用。

日志：D:/AI Agent/LumaCraft/app/build/workspace-refinements-check.log、workspace-refinements-recheck.log、workspace-refinements-build.log（均在同一build目录）。

程序：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.6.4/lumacraft.exe。仅交付完整可运行文件夹，无压缩包，旧版保留。
