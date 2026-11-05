# LumaCraft 0.9.0 / 0.9.1 · 形状组件（制作版）

2026-11-05，版本0.9.0+32，随后0.9.1+33。此交付为制作版，开启内置预设维护入口，沿用0.8.0的全部功能。

## 0.9.1 更新：形状选择器

“形状”下拉改为图标选择器：点击后弹出 4 列 × 2 行的网格，8 个形状各有示意图标，图标下方是小字名称；当前形状用强调色描边和淡底色标出，收起时显示当前形状的小图标和名称。图标统一 24 px 网格、同线宽与圆角，细节用柔和金色。与其他下拉一致：直接打开和关闭、无动画，点击外部或按 Esc 关闭，点选后立即切换。

验证：新增选择器测试1项（8个图标、两行四列对齐、带名称、点选切换、Esc 不改变形状），`shape_test.dart` 共8项；完整 Flutter 测试共38项通过；真实界面截图核对排版与图标；制作版 Windows 编译成功并能启动。

新增 D:/AI Agent/LumaCraft/app/lib/ui/editor/shape_picker.dart；修改 D:/AI Agent/LumaCraft/app/lib/ui/editor/shape_panel.dart、D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart、D:/AI Agent/LumaCraft/app/test/shape_test.dart、D:/AI Agent/LumaCraft/app/build/shape-preview/preview_test.dart、D:/AI Agent/LumaCraft/app/pubspec.yaml。交付目录：D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.9.1-Authoring/（0.9.0 目录保留未动）。以下为 0.9.0 的形状组件说明，仍然有效。

## 新增：形状组件

入口：编辑模式 → 添加组件 → 形状。默认添加矩形，在右侧“形状外观”里切换种类。

种类：线条、矩形、三角形、圆形、平行四边形、梯形、菱形、六边形。

| 属性 | 说明 |
|---|---|
| 宽、高 | 线条显示为“长度、粗细”。单位按照片短边1000 px为基准 |
| 旋转角度 | 0～360°，可输入数值或按住鼠标拖动数值框 |
| 填充 | 开关、颜色、独立的“填充不透明度” |
| 描边 | 开关、颜色、粗细、独立的“描边不透明度”（线条没有描边，只有“线条颜色”） |
| 圆角 | 除圆形和线条外所有形状都有；数值上限为最短边的一半 |
| 线条 | 圆头端点、虚线 |
| 三角形 | 只支持等腰三角形，可“设为等边”；可开启“左右分别设色”，按对称轴分为左右两半各设填充色 |
| 平行四边形 | 倾斜程度 0～85% |
| 梯形 | 上边收窄 0～49% |
| 六边形 | 平顶或尖顶，角部收窄 0～50% |
| 圆形 | 宽高可分别设置，不相等时为椭圆 |

## 画布操作

- 选中形状后，在形状自己的框上出现抓点，操作方式参考PPT/Photoshop：
  - 白色方块：拖动改变宽高，对侧顶点保持不动；Shift 等比。线条只有两端的方块（改长度）。
  - 金色圆点：圆角抓点（沿顶点的边拖动）；平行四边形、梯形、六边形另有形状抓点（在上边的顶点处）。
  - 上方白色圆形抓点：旋转；Shift 以15°为步进。
- 拖动抓点时，右侧属性面板的数值同步变化；一次拖动合并为一次撤销。
- 旋转过程中隐藏选择框；松开后显示旋转后形状的外接矩形选择框。
- 点选、框选、拖动、吸附、对齐、编组、图层顺序、隐藏锁定、复制删除沿用现有行为。点选按形状自身旋转后的范围判断，倾斜的长线条不会误选到旁边的组件。
- 暂不支持：渐变填充、阴影、平行四边形反向倾斜、自由绘制。

## 预设与分享

- 形状随预设保存；横图、竖图布局可单独覆盖宽、高、旋转、圆角、倾斜、收窄。
- 包含形状的 `.lmp` 增加 `shapeV1` 能力声明。旧版软件会明确拒绝导入，不会静默显示错误效果；不含形状的 `.lmp` 与旧版完全兼容。
- 导出成片、缩略图、画布预览共用同一绘制代码。

## 验证

- 新增 `test/shape_test.dart` 共7项：参数保存与范围限制、八种形状绘制与圆角边界、填充/描边独立不透明度与三角形左右设色、线条圆头/虚线、抓点拖动数学（旋转后对侧顶点不动、最小尺寸、圆角上限）、横竖布局覆盖与撤销与 `.lmp` 往返与拒绝非法/未知内容、导出渲染像素检查。
- 完整 Flutter 测试共37项（原30加新7）通过；两个额外预览测试通过；制作版 Windows 编译成功。
- 真实界面：`build/shape-preview/preview_test.dart` 用真实编辑页面和真实鼠标事件拖动抓点（改宽高、圆角、梯形收窄、旋转），截图核对：抓点位置、旋转时选择框隐藏、松手后外接矩形、面板数值同步。
- 整套测试中出现过一次 `export_workspace_flow_test` 偶发失败，单独与整套各重跑两次均通过，原因未查明，已记入项目台账。
- 未验证：各 Windows 缩放档位下新面板的文字清晰度（请使用时核对）。

## 文件清单

新增：
- D:/AI Agent/LumaCraft/app/lib/editor/shape_style.dart：形状数据、几何、抓点与拖动计算。
- D:/AI Agent/LumaCraft/app/lib/editor/shape_render.dart：形状绘制。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/shape_panel.dart：属性面板。
- D:/AI Agent/LumaCraft/app/assets/ui/layer-shape.svg：图层图标。
- D:/AI Agent/LumaCraft/app/test/shape_test.dart：核心测试。
- D:/AI Agent/LumaCraft/app/build/shape-preview/preview_test.dart：界面抓点交互与截图。
- D:/AI Agent/LumaCraft/app/docs/windows-shapes-0.9.0.md：本说明。

修改：
- D:/AI Agent/LumaCraft/app/lib/editor/style_document.dart：节点支持形状、横竖布局覆盖。
- D:/AI Agent/LumaCraft/app/lib/editor/style_render.dart：边界计算与绘制。
- D:/AI Agent/LumaCraft/app/lib/editor/preset_package.dart：shapeV1 能力与校验。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_panels.dart：面板接入。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_canvas.dart：抓点绘制与拖动、形状点选。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/editor_page.dart：状态与引入。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本0.9.0+32。

## 交付

D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.9.0-Authoring/lumacraft.exe。请保留完整目录，不单独移动EXE。只提供可运行文件夹，无压缩包，旧版本保留未改动。
