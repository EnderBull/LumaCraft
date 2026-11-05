# LumaCraft 0.6.5 · 预览边缘与滚轮缩放

2026-11-05，版本0.6.5+28。

浏览页文件名改为与编辑页一致的60%中性色。共用底栏提示前增加圆点。

模糊填充不再先绘制浅色底色，避免分数缩放时合成边缘透出底色；模糊离屏层边界扩至原有超采样范围，采用不抗锯齿矩形裁切，保持照片覆盖和背景调色逻辑。纯色、渐变和投影逻辑不变。

浏览/编辑的滚轮缩放改为通过共用接口核对Windows实时Alt状态和前台窗口归属，避免仅依赖Flutter的逻辑按键状态。Windows运行时必须确实按住左Alt或右Alt且窗口处于前台才缩放；普通滚轮不缩放。测试环境无原生通道时保留逻辑按键回退。空间键平移及适合窗口复位保持原有方式。

## 文件清单

- D:/AI Agent/LumaCraft/app/lib/main.dart：浏览文件名文字样式。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/workspace_chrome.dart：提示圆点。
- D:/AI Agent/LumaCraft/app/lib/editor/background_render.dart：模糊填充底色、层边界与裁切。
- D:/AI Agent/LumaCraft/app/lib/window_controls.dart：共用实时Alt校验接口。
- D:/AI Agent/LumaCraft/app/windows/runner/flutter_window.cpp：查询Windows左右Alt实时状态及前台窗口。
- D:/AI Agent/LumaCraft/app/lib/ui/browse_viewport.dart、D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart、D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_canvas.dart：浏览/编辑共用校验，异步返回时检查页面是否仍存在。
- D:/AI Agent/LumaCraft/app/test/browse_controls_test.dart：松开Alt后普通滚轮不缩放、模拟逻辑残留与系统状态冲突、原有平移复位。
- D:/AI Agent/LumaCraft/app/test/image_background_test.dart：深色照片配白色底色，四种非整数比例及非整数平移的像素检查，原有素材、背景与导出核心流程。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号。
- 本说明及D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：记录。

## 验证与边界

六项相关核心验证通过。新增异步Windows通道后，原控件验证未模拟通道并等待结果；补齐模拟后缩放核心流程重跑通过。代码分析无问题。日志位于 D:/AI Agent/LumaCraft/app/build/preview-edges-alt-check.log、preview-alt-recheck.log、preview-edges-alt-build.log（同一build目录）。

自动化按键检查使用模拟的系统状态，像素检查使用Flutter测试渲染器；不等同于所有显卡、显示缩放和实际按键场景的现场检查。实际Windows滚轮手感和白边现象交用户本轮试用确认。

交付：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.6.5/lumacraft.exe。完整文件夹交付，无压缩包，旧版本保留。
