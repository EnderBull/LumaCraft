# 内置字体与预设制作 Implementation Plan

> 执行方式：使用 superpowers:executing-plans 在现有工作区逐项实现。项目没有 Git 仓库，不创建 worktree、不提交、不删除文件。

**Goal:** 打包可离线使用的中英文字体，完善04/05/06预设及制作版内置库维护。
**Architecture:** 字体注册表统一菜单/画布/导出和.lmp校验；内置库改为可封包的数据资源。制作版将覆盖稿保存到独立文件，发行版忽略覆盖且不提供维护入口。
**Tech Stack:** Flutter / Dart，OFL字体，JSON资源与现有.lmp校验。
**Spec:** 用户2026-11-05已确认方案及根目录产品设计方案；Futura取消，英文无衬线选择Jost、Manrope。

## Global Constraints
- 复用现有下拉菜单，仅字体项目使用对应字体；UI正文样式不变。
- 文件都在app；不删除文件；只输出新可运行文件夹。
- 核心验证一轮，余下交用户；新旧预设ID与字体键兼容。
- 首批制作04画廊签名、05旅行记录、06胶片档案；手机经典组先建立，品牌视觉另按参考方案逐步制作。

## Review Focus
- 旧字体serif/sans/signature和旧.lmp仍可读取。
- 字体缺字有明确提示和同类中文回退；导出不依赖本机安装字体。
- 内置覆盖草稿不影响用户预设；发行构建不读取制作稿。
- 维护导出的库可重新封包，非法结构拒绝，不静默覆盖文件。
- 横竖布局与缺失Exif的核心显示正确；弹窗外标签、固定动作、滚动区域。

## Task 1 字体
- [x] 下载官方区域精简/单字重字体及OFL，生成来源/大小记录；英文可变小文件直接保留。
- [x] 新增app/lib/fonts/font_catalog.dart；修改prototype_controls.dart、editor_panels.dart、style_render.dart、editor_canvas.dart、preset_package.dart、pubspec.yaml。
- [x] 检查真实字体加载、菜单样式、旧.lmp及导出渲染。

## Task 2 内置库与三款样式
- [x] 新增app/lib/editor/builtin_library.dart和app/assets/builtins/library.json；修改preset_store.dart、main.dart。
- [x] 共用现有StyleDocument支持横竖适配，稳定ID gallery/film，新增travel。
- [x] 新增app/lib/ui/builtin_manager.dart，在preset_actions.dart接入维护入口，在editor_page.dart接入保存内置目标。
- [x] 制作版dart-define=LUMACRAFT_AUTHORING=true；发行版默认false。维护含新增、分组、重命名、更新、恢复原稿、导出JSON库，按钮样式复用。
- [x] app/tools封包检查支持将导出的库置入新的资源路径，不覆盖旧库；记录封包步骤。
- [x] 核心覆盖保存/重启恢复、发行只读、导出导入库校验及横竖渲染。

## Task 3 交付
- [x] 核对字体菜单及预设维护真实字体截图，修正必要的排版问题。
- [x] 静态分析、相关核心流程；制作版Windows编译和独立文件夹交付。
- [x] 写完整文件清单、字体大小/许可、未完成手机品牌素材边界及使用说明。

## 执行账本
- 2026-11-05：按确认方案实现字体、三款样式及维护入口；手机组创建，不提前虚构品牌复刻。
- 官方字体和OFL下载完成，来源、大小、哈希见assets/fonts/sources.json。
- 核心4项+既有9项通过；维护UI1项最终通过，失败原因与修复见交付说明。
- Windows实际新增面板核对完成，收到物理Esc后停止所有电脑操作。
- 编译0.8.0+31制作版，输出独立目录，未删除文件、未生成ZIP。
