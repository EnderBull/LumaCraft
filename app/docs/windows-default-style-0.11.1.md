# LumaCraft 0.11.1 · 默认预设改为“画廊签名”（制作版）

2026-11-05，版本0.11.1+38。此交付为制作版，沿用0.11.0的全部功能。

## 修改内容

没有设置样式的照片，原来在三个场景各用一套早期遗留的旧逻辑（早期“画一张标题图”的旧边框，写着 Gallery Collection），与现在的内置预设无关。现在统一改为内置预设“画廊签名”（内置库里 id 为 `gallery` 的一款）：

| 场景 | 原来 | 现在 |
|---|---|---|
| 浏览页预览 | 旧的画标题图方式 | 与编辑页相同的统一渲染，使用画廊签名 |
| 进入编辑页的初始样式 | 早期模板 `StyleDocument.template()` | 画廊签名的副本 |
| 直接导出没设样式的照片 | 旧版导出路径 | 用画廊签名导出，预览与导出一致 |

- 制作版里你修改了画廊签名，默认样式会同步变化（没改过就是封包原样）；万一内置库里没有 `gallery`，退回库里第一款。
- “没设样式 = 未编辑”的判断不变，“全部已编辑照片”的导出范围不受影响。
- 旧的画图代码（`render.dart` 里的旧版导出和标题图函数）保留未删，原因是仍有测试在用；确认无人使用后再单独清理。

## 验证

- 新增 `test/default_style_test.dart` 共2项：默认样式取内置画廊签名、每次返回副本、随制作版修改同步、restore 后回到封包原样、不再是早期的 Gallery Collection 模板、内置库里没有 gallery 时退回第一款；浏览页真实界面里没设样式的照片，主画布预览使用的就是画廊签名。
- 完整 Flutter 测试共49项通过；原有测试未做改动即全部通过。

## 文件清单

修改：
- D:/AI Agent/LumaCraft/app/lib/main.dart：浏览预览、进入编辑、导出三处改用默认样式；删除旧的画标题图预览代码和不再使用的导入。
- D:/AI Agent/LumaCraft/app/lib/editor/preset_store.dart：新增 `defaultStyle()`。
- D:/AI Agent/LumaCraft/app/pubspec.yaml（版本0.11.1+38）
- D:/AI Agent/LumaCraft/项目台账.md

新增：
- D:/AI Agent/LumaCraft/app/test/default_style_test.dart
- D:/AI Agent/LumaCraft/app/docs/windows-default-style-0.11.1.md
- D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.11.1-Authoring/（旧版本目录保留未动）

## 交付

D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.11.1-Authoring/lumacraft.exe。请保留完整目录，不单独移动EXE。
