# LumaCraft 0.7.0 · 导出与sRGB色彩管理

版本0.7.0+29，2026-11-05。将已确认的导出界面接入真实批处理。

## 使用与行为

- 导出范围为当前、选中、全部已编辑照片。输出目录、格式、质量、尺寸、命名模板和隐私设置保存在本地，下次打开恢复。
- JPG质量1～100；PNG保留置灰质量滑块。尺寸留空按原图像素向外增加边框；输入后按成片长边/短边等比例缩放（含边框），支持放大/缩小。尺寸框支持左右/上下鼠标拖动、键盘输入和清空恢复原尺寸。
- 本版本渲染上限为单边16384像素及总计6400万像素。长短边指定导致另一边超限时，明确失败提示，不生成错误尺寸文件。
- 默认模板{name}_LumaCraft，不默认加序号。变量模块可插入/删除，普通文字可编辑；日期时间只取拍摄元数据，不用文件时间冒充。序号按本轮照片顺序确定，重试沿用原命名。
- Windows非法文件名字符替换为下划线，处理保留设备名和尾部点/空格；过长名称收短。缺失变量集中提示，继续时用“未填写”占位；空命名停止导出。
- 遇到已有同名文件，先询问“取消导出 / 替换保存 / 全部保留”。全部保留通过_1、_2编号；替换仅对确认的输出目标。源照片及符号链接指向的源照片受到保护，不能以替换方式覆盖。若同一批次照片生成相同名称，替换按钮禁用，选择全部保留或返回修改模板，避免相互覆盖。
- 成片先写暂存文件，编码成功后发布。替换前检查目标是否被外部修改，发生变化则停止该项；失败暂存文件可能保留在输出目录，错误信息给出路径。软件不自动清理其他文件。
- 拍摄参数与GPS独立开关，GPS默认移除。尺寸及方向按成片更新。水印中的地点文字与文件内GPS仍为独立概念。
- 进度、取消、失败列表、失败重试、打开输出目录均接通。取消时等待当前解码/编码步骤结束，不发布尚未完成的成片。重试保持失败任务的样式、信息、模板结果和参数，不重做已成功项。

## 色彩管理

Windows后台工具使用WIC颜色上下文与颜色转换，将源照片转换到系统注册的标准sRGB配置。优先读取源ICC，其次读取可识别的EXIF色彩空间（sRGB/Adobe RGB）；无有效配置的普通RGB图按sRGB解释。无配置不能反推真实来源色彩空间；无法解码或转换的文件明确失败，不输出仅贴sRGB标签的假转换文件。此版本没有完成HEIC/HDR的专项兼容验证。

转换后的RGBA像素用于画布合成。JPG使用APP2 ICC_PROFILE分块嵌入，PNG使用iCCP嵌入实际ICC字节，并移除冲突的旧色彩声明；EXIF色彩空间标记为sRGB。配置来自Windows自带的标准sRGB，而非另外分发第三方ICC资源。后台色彩工具必须与EXE放在一起；它不打开交互窗口。

实现依据：[Microsoft WIC色彩管理](https://learn.microsoft.com/en-us/windows/win32/wic/-wic-colormanagement)、[EXIF颜色空间](https://learn.microsoft.com/en-us/windows/win32/api/wincodec/nf-wincodec-iwiccolorcontext-initializefromexifcolorspace)、[PNG规范](https://www.w3.org/TR/png-3/)。

## 文件清单

- D:/AI Agent/LumaCraft/app/lib/main.dart：正式导出入口、任务快照、缺失信息预检、重名决策、进度/取消/失败重试、打开目录。
- D:/AI Agent/LumaCraft/app/lib/export/export_options.dart：参数校验、默认模板、重名选择。
- D:/AI Agent/LumaCraft/app/lib/export/export_naming.dart：变量解析、文件名规范化、编号及保留路径。
- D:/AI Agent/LumaCraft/app/lib/export/export_preferences.dart：本地偏好保存与恢复。
- D:/AI Agent/LumaCraft/app/lib/export/export_task.dart：任务对象、暂存发布、替换前目标检查。
- D:/AI Agent/LumaCraft/app/lib/export/color_management.dart：后台色彩工具通信、sRGB像素解码、JPG/PNG ICC嵌入。
- D:/AI Agent/LumaCraft/app/windows/runner/color_tool.cpp：WIC解码/ICC转换、方向修正、标准sRGB配置获取、无窗口输出。
- D:/AI Agent/LumaCraft/app/windows/runner/CMakeLists.txt：色彩工具构建及随程序复制。
- D:/AI Agent/LumaCraft/app/lib/render.dart：参数化编码、原有默认样式的受管理导出、元数据与GPS策略。
- D:/AI Agent/LumaCraft/app/lib/editor/style_render.dart：受管理像素进入同一画布布局，按目标边长渲染，参数化编码。
- D:/AI Agent/LumaCraft/app/lib/ui/export/export_dialog.dart、naming_template_editor.dart、export_conflict_dialog.dart、vertical_toggle.dart（后面三个同目录）：已确认的导出控件、命名模块、重名面板与开关。正式接入后增加无效尺寸禁用、批内重名替换禁用。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/prototype_controls.dart：预览阶段已增加的可选文字样式，用于尺寸框保持字体一致。
- D:/AI Agent/LumaCraft/app/test/export_pipeline_test.dart：变量/偏好/编号/替换及真实ICC转换、尺寸/EXIF/GPS/JPG/PNG读回。
- D:/AI Agent/LumaCraft/app/test/export_workspace_flow_test.dart：隔离目录中的真实工作台取消、保留、替换及失败重试。
- D:/AI Agent/LumaCraft/app/build/export-preview/preview_test.dart：导出控件预览验证。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号；本说明及technical-validation.md、ui-prototype/design-notes.md、docs/export-panel-preview.md更新交付状态。
- D:/AI Agent/LumaCraft/AGENTS.md：预览阶段已确认的四角裁切纠正规则，本轮未再次修改。

## 验证与限制

十项独立核心检查已通过：两项导出管线、六项既有编辑、一个预览控件流程及一个真实工作台导出流程。管线检查包含线性RGB测试配置的中灰128实际转换到sRGB约188，证明进行了像素转换；读回JPG APP2与PNG iCCP均与目标配置字节一致；检查横竖方向、长/短边尺寸、EXIF尺寸/相机/方向以及GPS开关。

检查中修复后台工具COM释放先后顺序；GPS验证照片最初未正确写入标签，修正测试样本后读回通过；工作台验证的同名取消按钮定位收窄到重名弹窗后通过。工作台使用新建export-ui-check目录，不接触用户原图。实际显示器观感、其他厂商广色域配置和更大批次性能交用户试用，未声称完成所有相机/显示器/HDR兼容测试。

日志：D:/AI Agent/LumaCraft/app/build/export-pipeline-recheck.log、export-workspace-flow-final.log、export-release-0.7.0.log（同一build目录），预览验证见build/export-preview/preview-type-match.log；最初记录保留。

## 交付

D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.7.0/lumacraft.exe。需要完整文件夹，包括lumacraft_color_tool.exe、DLL和data。默认只输出文件夹，无压缩包，旧版本保留。
