# LumaCraft 0.2.0 · Windows 预设编辑器

日期：2026-11-04。交付目录：D:\AI Agent\LumaCraft\app\dist\LumaCraft-0.2.0。

## 使用
1. 启动 lumacraft.exe，保留同目录的 data 和 DLL 文件。
2. 顶栏“浏览”模式用于选目录、照片和预设；照片信息位于右侧底部、导出按钮上方。
3. 顶栏切换“编辑”，修改当前照片样式或从空白画布新建。草稿预览不自动修改照片。
4. “保存预设”可以新建或选择用户预设覆盖；“应用样式”明确选择当前或选中照片。
5. 返回“浏览”后导出。JPG 固定质量 92，PNG 保留拍摄信息，默认移除 GPS。导出扩展选项仍按后续规划处理。

## 已实现
- 真实照片及拍摄信息、四边比例与联动、背景颜色、七类文字/信息组件。
- 图层排序、多选、嵌套分组、显隐/锁定、复制/删除、六方向对齐、照片边缘吸附。
- 自由文字/作者双击原位编辑，其他拍摄信息组件双击独立选择。
- Alt + 滚轮缩放、空格 + 拖动平移、适合窗口；横/竖/方适配检查不裁改原照片。
- 锚点切换时换算坐标，边框归零时转移到照片区域；编辑历史撤销/重做。
- 预设缩略图、搜索、用户预设新建/覆盖、草稿恢复、明确应用范围。
- 已确认的黑金主题、无边框窗口、两种布局与面板拖动、原型矢量图标及标签页/属性控件样式。

## 快捷键
- Ctrl+J 复制组件；Ctrl+D 取消当前操作区域的选择；Ctrl+A 全选当前区域。
- Ctrl+G 分组；Ctrl+Shift+G 取消分组。
- Ctrl+Z 撤销；Ctrl+Shift+Z 重做。
- Ctrl 点选增减，Shift 点选连选；画布空白处拖动框选。
- 方向键微调组件，Shift 加大步长；照片区域左右方向键切图、Shift 扩选。
- Alt 临时关闭组件拖动吸附。
- 文字编辑 Enter 换行，Ctrl+Enter 完成，Esc 取消。

## 数据与兼容
照片原文件不修改。旧 film/fields 照片记录继续可读；新样式写入附加字段。预设存入本地 editor-presets.json，内置模板不可覆盖，预设数量不限制为六种。草稿以照片和稳定预设来源关联，应用后继续编辑也可恢复。读取异常会停止预设覆盖写入；保存失败显示错误，应用失败恢复原照片状态。

## 修改文件
- app/lib/editor/style_document.dart、editor_controller.dart、preset_store.dart、style_render.dart：样式模型、选择与历史、存储、统一排版。
- app/lib/ui/editor/editor_page.dart、editor_panels.dart、editor_canvas.dart、prototype_controls.dart：编辑器界面和原型共用控件。
- app/lib/main.dart、photo_state.dart、render.dart：入口、工作台、照片记录、预览和导出。
- app/lib/ui/workspace_layout.dart、app_icons.dart：阴影层级及图标支持。
- app/assets/ui/*.svg、app/pubspec.yaml、app/pubspec.lock：原型矢量资源与依赖、版本。
- app/test/editor_core_test.dart、app/test/widget_test.dart：核心流程验证与原模板测试说明。
- app/docs/superpowers/plans/2026-11-04-windows-editor.md、technical-validation.md、本文件：实施和交付记录。

## 验证
核心检查通过：样式/分组/锚点/撤销与实际预设文件存储，真实照片编辑→保存预设→应用，JPG/PNG 导出与 EXIF、GPS 移除。代码检查无问题。保留核心检查输出 app/build/editor-core-check.log 与 app/test/editor-output 下的样例。本轮不做长时间压力测试，其余使用体验交用户验证。


最终状态：交付包已正常启动，使用原有本地记录；先前隔离示例窗口已关闭。实际窗口外观已核对，未对用户照片执行测试导出或应用操作。
