# Windows 工作台 UI 迁移实施计划

目标为迁移已确认的暖橙工作台，并加入真实目录树、子目录扫描、无原生标题栏窗口。规格来自 ui-prototype/design-notes.md、产品设计方案及本次聊天确认。

技术使用现有 Flutter、Dart 和 Windows runner，不增加应用运行依赖。

## 执行清单
- [x] directory_browser.dart 实现盘符、按需子目录、可取消的逐批 JPG 扫描，切换时丢弃旧结果。
- [x] ui/app_theme.dart、app_icons.dart、workspace_layout.dart 实现主题、矢量图标、360 ms 布局过渡和三处拖拽。
- [x] workspace_settings.dart 保存布局、外观、子目录开关与上次目录，现有 photo-state.json 保留。
- [x] main.dart 接入现有逐张预设、EXIF 补填和导出。右侧仅呈现已经实现的两款预设与照片信息。
- [x] window_controls.dart 和 Windows runner 实现自绘顶栏、最小化/最大化/关闭、拖动及边缘缩放。
- [x] 一轮核心流程验证目录切换、递归范围、选择、元数据和导出，完成静态分析、Windows 构建和窗口检查。

全局约束为全部文件位于 app 内，不删除文件，不引入完整编辑器功能，不覆盖原照片，核心流程通过后其余体验交用户验证。


## 完成记录
Windows Release 构建通过。目录核心脚本通过，桌面一轮核心流程通过。审查发现的扫描批次使在途预览失效、深目录缩进溢出均已修正。补充验证包括在途解码复用、深目录和原生最大化/还原。
右侧使用“预设 / 照片信息”，呈现当前已实现能力；完整调整编辑器和其余风格后续开发。
