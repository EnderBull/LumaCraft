# LumaCraft 0.10.1 · 界面问题修复（制作版）

2026-11-05，版本0.10.1+36。此交付为制作版，沿用0.10.0的全部功能。

## 修复 1：底栏缩放比例与“适合窗口”没有紧贴右下角

- 现象：编辑页中间画布区底部，缩放比例和“适合窗口”离右边有一大段空白，窗口越宽空得越多。
- 原因：底栏那一行里，提示文字“Alt 滚轮 · 空格拖动”被放在 `Flexible` 中，后面又有 `Spacer`，两者平分剩余空间，文字只用自己那一点宽度，另一半份额就空着。这段写法从接手时就存在，窗口窄时不明显。全软件只有这一处这样写。
- 修复：提示文字改用 `Expanded` 占满剩余空间，缩放比例和“适合窗口”自然挤到最右。
- 修改：D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_canvas.dart。

## 修复 2：特定缩放比例下预览的照片边缘出现白边

- 现象：边框为 0 的一边（照片贴着画布边缘），预览在某些缩放比例下，照片边缘出现一圈浅色细边；导出时没有。
- 原因：画布在画照片前，先在整个画布（包括照片下面）铺了一层浅色底色。缩放到小数比例时，照片边缘像素只有部分覆盖，会和下面的浅色底色混合，在深色照片边缘形成白边。导出刚好整像素对齐所以看不到，但换一张尺寸不凑巧的照片，导出也可能出现。
- 修复：底色只铺在边框区域，不再铺在照片下面。有边框的一边，底色向照片内多伸 4 个画布单位（被不透明的照片盖住，看不见），保证照片与边框交界处不留缝；边框为 0 的一边不铺底色，边缘像素只和画布外部混合。预览、缩略图、导出共用这段绘制，一并修好。模糊背景模式原本就单独处理过，未改动。
- 修改：D:/AI Agent/LumaCraft/app/lib/editor/background_render.dart。

## 验证

- 新增 `test/photo_edge_test.dart` 共2项。第一项在 0.7311、0.9137、1.2653、0.5 四个小数缩放比例并带小数偏移下渲染，检查照片左、右、上三个边缘像素不能混入浅色底色、底边框内仍是底色。修复前该测试失败（边缘像素红色通道为 80，照片本身为 20），修复后通过。第二项检查有边框的情况下照片与边框交界处没有透明缝隙（首次用重叠 1 个画布单位时出现约 2% 的缝隙，加到 4 后消除）。
- 界面检查：`build/phone-preview/ui_test.dart` 增加断言，“适合窗口”右侧留白小于 36 px，并截图核对。
- 完整 Flutter 测试共43项通过；四个额外预览测试通过；制作版 Windows 编译成功并能启动。
- 未验证：你的真实照片在各缩放档位下的最终观感，请试用时确认。

## 文件清单

修改：
- D:/AI Agent/LumaCraft/app/lib/editor/background_render.dart
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_canvas.dart
- D:/AI Agent/LumaCraft/app/build/phone-preview/ui_test.dart
- D:/AI Agent/LumaCraft/app/pubspec.yaml（版本0.10.1+36）
- D:/AI Agent/LumaCraft/项目台账.md

新增：
- D:/AI Agent/LumaCraft/app/test/photo_edge_test.dart
- D:/AI Agent/LumaCraft/app/docs/windows-fixes-0.10.1.md
- D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.10.1-Authoring/（旧版本目录保留未动）

## 交付

D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.10.1-Authoring/lumacraft.exe。请保留完整目录，不单独移动EXE。
