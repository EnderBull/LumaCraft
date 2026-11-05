# ADR-004 · Windows原生WIC转换后嵌入sRGB ICC

状态：按当前代码及保留记录重建，2026-11-05。历史缺少决策证据的部分明确标注，不臆造。

## 背景

用户要求导出色彩管理和ICC嵌入；仅贴sRGB标签不能把非sRGB像素变为sRGB。

## 决策

独立无窗口C++工具，WIC源配置→Windows标准sRGB像素，RGBA进共用画布，JPG APP2/PNG iCCP嵌入实际目标配置。

## 被否决/未采用的备选与证据边界

本轮以前的普通编码不足以证明真实转换，不作为当前方案。未找到其它跨端色彩库正式基准比较记录，不虚构否决。

## 代价与影响

Windows依赖及辅助EXE必须随包；源无配置的RGB按sRGB解释，不反推来源；HEIC/HDR专项未完成。

## 影响文件/核实入口

app/windows/runner/color_tool.cpp、CMakeLists.txt；app/lib/export/color_management.dart；render.dart；editor/style_render.dart；test/export_pipeline_test.dart。
