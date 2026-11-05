# LumaCraft 0.2.3 · 模式切换试用包

版本：0.2.3+8。日期：2026-11-04。

## 本次调整
- 浏览/编辑切换采用侧栏轻滑、画布保留方案，取消整页缩放和淡入淡出。
- 按用户最终要求，侧栏滑动、画布位置与尺寸适配、进入与返回均为 260 毫秒。
- 采用 easeInOutCubic 曲线，进入和返回都柔和起步、平缓停稳，侧栏位移保持 16 px。
- 顶栏和底栏不参与位置或透明度动画。下拉菜单继续即时展开与收起。
- 复用已加载的照片；模式往返传递当前照片、选区、选择锚点和缩略图滚动位置。
- 明确传递原浏览目录，避免递归目录从第一张照片父目录推断错误；扫描未完成时继续扫描并去重，不清空已有选区。
- 尊重系统减少动画设置。

## 使用
运行同目录 lumacraft.exe。保留所有 DLL 和 data 文件夹；搬动或分享时使用完整文件夹或 ZIP。

程序：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.2.3/lumacraft.exe。
压缩包：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.2.3-windows-x64.zip。
旧版本保留，原照片不改动。

## 修改清单
- D:/AI Agent/LumaCraft/app/lib/ui/editor/mode_transition.dart：新增局部转场、共享画布和返回状态；最终统一 260 ms 与柔和起停曲线。
- D:/AI Agent/LumaCraft/app/lib/main.dart：接入模式路由、复用照片、接收返回状态与继续目录扫描。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart：预载照片、明确浏览目录、状态回传与侧栏动画。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_canvas.dart：独立共享画布，保留选择框和辅助线。
- D:/AI Agent/LumaCraft/app/lib/editor/style_render.dart：可选共享预览及画布区域渲染。
- D:/AI Agent/LumaCraft/app/lib/ui/smooth_scroll.dart：支持初始滚动位置。
- D:/AI Agent/LumaCraft/app/test/editor_core_test.dart：核心编辑流程覆盖共享画布转场中间帧、模式返回与递归目录状态。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本号。
- D:/AI Agent/LumaCraft/app/docs/superpowers/plans/2026-11-04-mode-transition.md：实施与完成记录。
- 本说明、D:/AI Agent/LumaCraft/app/docs/technical-validation.md、D:/AI Agent/LumaCraft/app/ui-prototype/design-notes.md：交付记录。

## 验证与边界
代码检查无问题，最终 260 ms 版本单轮三项核心检查全部通过：样式/分组/锚点/存储、编辑→应用→保存→模式返回、JPG/PNG 导出保留 EXIF。
日志：D:/AI Agent/LumaCraft/app/build/editor-core-check-0.2.3.log。
此前原生界面检查被用户 Esc 中止；本次不扩大测试，动画观感由用户试用确认。
已有未应用草稿与照片当前样式不同的情况下，切换时展示各自真实样式，不通过淡入淡出混合内容。
