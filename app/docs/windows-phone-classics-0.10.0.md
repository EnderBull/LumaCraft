# LumaCraft 0.10.0 · 手机经典（制作版）

2026-11-05，版本0.10.0+35。此交付为制作版，开启内置预设维护入口，沿用0.9.2的全部功能。

## 新增：手机经典 6 款

入口：预设面板 → 内置 → 分组选“手机经典”。6 款均为“横竖通用”，横图、竖图各有单独的底栏高度与排版，方图使用通用布局。

| 名称 | 版式 |
|---|---|
| 底栏参数条·白 | 白底。左边机型、地点，右边拍摄参数、拍摄时间，中间一条竖线分隔，最右是品牌标识占位 |
| 底栏参数条·黑 | 同上，黑底浅字，占位图用深色版 |
| 透明叠加·左下角 | 无边框。照片左下角一块半透明深色底衬，里面是占位图、机型和参数 |
| 居中双行 | 浅白底。机型居中，下面一条短横线，再下面是参数 |
| 签名边框 | 白底。左边手写签名（可改文字），右边机型和参数 |
| 极简单行 | 窄白边，一行小字。左边小占位图加机型，右边参数 |

- 分隔线均为“形状”组件里的线条，不是文字字符。
- 所有文字组件跟随每张照片的 EXIF（机型、参数、时间、地点）；缺失时在编辑画布显示提示，不进入成片。
- 名称用版式特点命名，不含任何手机或相机品牌名。

## 品牌 Logo 与占位图

- 本软件不提供品牌 Logo。依据各品牌官方条款调研，未发现允许第三方软件分发其 Logo 的授权，因此一律不随软件分发品牌标识。
- 预设里的“品牌标识（占位）”是一个灰色圆角方块加线条镜头图标的占位图（256×256 PNG，约 9 KB，随预设保存）。点选该图层 → “替换图片”，即可换成自己的标识。
- 未替换就导出，占位图会印在成片上。可点图层旁的“眼睛”隐藏，或删除该图层。居中双行、签名边框两款没有 Logo 位。
- 软件内说明：
  - 预设面板选中“手机经典”分组时，列表上方显示：“版式参考，与任何手机或相机品牌无关，不提供品牌 Logo。如需使用品牌标识，请用‘图片标识’自行导入，并确认你拥有使用权。”
  - 选中占位图层时，右侧“图片素材”下方提示不提供品牌 Logo、请只使用有使用权的标识，并说明占位图导出前需替换或隐藏。

## 分享

6 款都能导出为 `.lmp`（含 shapeV1 能力声明，旧版软件会拒绝导入，不含形状的预设不受影响），并能重新导入。

## 验证

- 新增 `test/phone_classics_test.dart` 共2项：6 款名称与顺序、横竖布局与适配标记、全部文字与名称不含品牌词、占位图合法（256×256 PNG、体积小、比例1）、分隔线必须是形状、横竖底边框不同；6 款 `.lmp` 来回导入与素材校验。
- 原有 `builtin_fonts_test.dart` 对内置库每款在 3:2、2:3、1:1 上检查所有组件都在画布内，9 款全部通过。
- 完整 Flutter 测试共41项通过（原39加新2）；三个额外预览测试通过。
- 真实界面：`build/phone-preview/ui_test.dart` 截图核对分组提示与图片面板提示的显示。
- 效果图（示例照片）：`build/phone-preview/out/`，生成程序 `build/phone-preview/drafts_test.dart`。
- 未验证：真实照片上的实际观感（请在制作版里用你的照片微调定稿）；各 Windows 缩放档位下新增说明文字的清晰度。

## 定稿与封包

按约定：你在制作版“内置预设维护”里直接修改这 6 款并保存，通知我后，我先导出写回工程资源，再封包为发行版。注意：保存的修改在本机 `builtin-working.json`，不等于已写入工程。

## 文件清单

修改：
- D:/AI Agent/LumaCraft/app/assets/builtins/library.json：“手机经典”分组加入 6 款（占位图随预设内嵌）。
- D:/AI Agent/LumaCraft/app/lib/ui/preset_panel.dart：手机经典分组说明。
- D:/AI Agent/LumaCraft/app/lib/ui/editor/image_panel.dart：图片标识面板说明与占位图提示。
- D:/AI Agent/LumaCraft/app/pubspec.yaml：版本0.10.0+35。
- D:/AI Agent/LumaCraft/项目台账.md。

新增：
- D:/AI Agent/LumaCraft/app/test/phone_classics_test.dart。
- D:/AI Agent/LumaCraft/app/build/phone-preview/ui_test.dart、merge_into_library.py（把草案合并进内置库的一次性脚本）；之前已提交的 drafts_test.dart、drafts.json、placeholder-light.png、placeholder-dark.png。
- D:/AI Agent/LumaCraft/app/docs/windows-phone-classics-0.10.0.md：本说明。
- D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.10.0-Authoring/：新制作版，旧目录保留未动。

## 交付

D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.10.0-Authoring/lumacraft.exe。请保留完整目录，不单独移动EXE。只提供可运行文件夹，无压缩包。
