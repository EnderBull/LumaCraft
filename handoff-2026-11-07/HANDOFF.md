# LumaCraft 工程交接总入口

**开发已按用户要求暂停；交接不代表获准继续开发。**

| 项目 | 当前事实 |
|---|---|
| 工程根目录 | `D:/AI Agent/LumaCraft` |
| 分支 / HEAD | `main` / `63d20f8` |
| 交接文档生成时间 | 2026-11-07T14:00+08:00 |
| 当前源码版本 | `app/pubspec.yaml`：0.18.0+58 |
| 最新交付 | `D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.18.0-Authoring/lumacraft.exe` |
| 远程仓库 | GitHub 私有，`https://github.com/EnderBull/LumaCraft` |
| 本地与远程 | 已同步；`v0.17.3`、`v0.18.0` 已打标签（v0.18.0 需推送） |

## 目标、理念、范围

软件名：框印工坊 / LumaCraft。面向摄影照片的本地边框、水印和自由排版工具。优先 Windows 专业桌面操作；目录直浏览，不依赖导入照片库；预设可编辑、可复用、离线分享；批量导出不改原图。

首版产品规划含 Windows 及后续 Android。**当前实际验证平台只有 Windows x64**，Android 仅为模板工程，不是可交付移动版。macOS/iOS、英文界面属后续规划。

**当前明确不做**：Android 版、macOS/iOS 版、英文界面、RAW 输入、整张高亮度编码的 HDR（缺解码库且涉 HEVC 专利）。

## 接手阅读顺序

1. 根目录 `AGENTS.md` —— 执行约束与思考方式教训，**必须逐条读**。
2. 根目录 `项目台账.md` —— 功能状态、风险清单、变更记录，是最完整的现状来源。
3. 本文 → `STATE.md` → `TEST_BASELINE.md`。
4. `DEVLOG.md`、`ADR/`；各版本说明在 `app/docs/`。

产品设计方案是规划，与实现冲突时以代码和测试为准。

## 当前能运行的功能

| 功能 | 状态 |
|---|---|
| Windows 无边框窗口、目录树、多目录/子目录、Ctrl/Shift 选择、照片预览 | ✅ |
| 组件、图层/分组、拖排/框选、吸附/对齐、撤销重做、锚点换算 | ✅ |
| 形状（8 种）、边框纹理（18 种）、邮票/车票造型、内置邮戳、照片描边 | ✅ |
| 色卡、图片标识、纯色/渐变/照片模糊/纹理背景、胶片打孔、投影、HSB 取色 | ✅ |
| 预设库（搜索/分组/收藏/多选）、`.lmp` 离线分享 | ✅ |
| **分享预设面板**：二维码 + 文本代码 + 导出 `.lmp` + 保存图片 | ✅ 0.17.4 |
| **从图片导入预设**：读取分享图中的二维码，不需要摄像头 | ✅ 0.17.4 |
| 内置预设 41 款，9 个分组 | ✅ 已定稿，不再改 |
| EXIF 读取补填、批量导出、重名处理、导出中断续传 | ✅ |
| sRGB 转换与 ICC 嵌入、EXIF/GPS 策略（导出默认移除 GPS） | ✅ |
| HEIC/HEIF 导入（Windows 解码）、广色域 JPG 预览与导出一致 | ✅ 0.15.0 |
| 照片移动或改名后自动认回（内容指纹 + 文件名/拍摄时间） | ✅ 0.15.x |
| 删除照片后列表自动刷新（含回收站删除、Shift+Delete） | ✅ 0.17.3 |
| **设置面板**：通用 / 高德 API / 关于 | ✅ 0.18.0 |
| **地点填写**：地图搜索或点选、GPS 自动填、坐标转换 | ✅ 0.18.0 |
| 8 款内置字体、制作版内置库维护 | ✅ |

## 未完成 / 受阻

- **Android 版**：SDK 未安装，包名仍为 `com.example.lumacraft`、debug 签名，不能发布。地图功能在 Android 上需换方案（不能复用 Windows 的 WebView2）。
- **macOS / iOS**：需要 Mac 环境。
- **英文界面**：未开始。
- **整张高亮度编码的 HDR**：已决定暂不支持，打不开时明确说明原因。
- **RAW 输入**：不做。
- **正式版封包（1.0.0）**：未做。当前所有交付都是「制作版」，带内置预设维护、恢复默认等开发专用入口。

## 进行中及下一步

**交接后保持暂停，恢复开发需用户明确指示。**

用户曾讨论的三个方向（未选定）：

1. **封 1.0.0 正式版** —— 隐藏制作版专属入口（「内置预设维护」「恢复默认」等，共 8 处）、内置预设正式打包、写面向普通用户的说明、版本号改 1.0.0。**具体做法与必须核对的清单见下文「正式版封包（1.0.0）」一节，照做即可，不要凭印象。**
2. **Android 版** —— 大工程，需重做界面适配与触屏交互、处理签名，地图要换方案。
3. **英文界面** —— 中等工作量，抽文案 + 语言切换。

新 Agent 接手后建议：
1. 读 `AGENTS.md`、`项目台账.md`、本文。
2. `git log --oneline -5` 确认 HEAD 与标签；确认本地与 `origin/main` 是否一致。
3. 需要构建/测试时先按 `ENVIRONMENT.template.ps1` 隔离数据目录，不要碰 `app/local` 真实记录。
4. 向用户说明已核实状态与未完成清单，再确认下一步范围。

## 环境与构建

```powershell
$env:PUB_CACHE = "D:\AI Agent\LumaCraft\app\.toolchain\pub-cache"
$env:LUMACRAFT_DATA_DIR = "D:\AI Agent\LumaCraft\app\build\export-ui-check-<新目录>"
$env:LUMACRAFT_COLOR_TOOL = "D:\AI Agent\LumaCraft\app\build\windows\x64\runner\Release\lumacraft_color_tool.exe"
```

| 项目 | 值 |
|---|---|
| Flutter / Dart | 3.47.9 / 3.13.7，在 `app/.toolchain`，不在系统 PATH |
| 构建命令 | `flutter build windows --release --no-pub --dart-define=LUMACRAFT_AUTHORING=true` |
| 测试 | `flutter test --no-pub`，部分测试需 `-j 1` 串行（见 TEST_BASELINE） |
| 直接依赖 | image、file_selector、flutter_svg、qr、zxing2、webview_flutter_windows、shelf、package_info_plus、url_launcher |
| 构建前提 | **需要 Windows 开发者模式**（插件符号链接），仅构建机需要，最终用户不需要 |

**启动软件**：双击项目根目录 `启动框印工坊.lnk`，脚本在 `tools/`，按版本号自动启动 `app/dist` 里最新的版本。

**Git 推送**：系统开着代理时，`git push` 需临时加 `-c http.proxy=... -c https.proxy=...`，详见 `AGENTS.md` 纠正记录。

## 目录结构

```text
D:/AI Agent/LumaCraft/
  AGENTS.md                         执行约束、思考方式教训、UI 偏好
  项目台账.md                        功能状态、风险、变更记录（最重要）
  启动框印工坊.lnk                    双击启动最新版本
  tools/                            启动脚本与快捷方式创建脚本
  handoff-2026-11-05/               旧交接（0.8.0 时期，多数内容已过时）
  handoff-2026-11-07/               本次交接
  app/
    lib/main.dart                   工作台入口、导出流程、图片浏览
    lib/settings/                   设置存储、高德服务、坐标转换、地图页面
    lib/editor/                     文档模型、控制器、渲染、预设库/.lmp
    lib/export/                     导出任务、命名、偏好、色彩管理、中断恢复
    lib/ui/                         共用控件、浏览/编辑/设置界面
    windows/runner/                 无边框窗口、窗口状态、WIC 色彩工具
    assets/builtins/library.json    41 款内置预设
    assets/ui/                      SVG 图标（layer-* / ui-*）
    test/                           Flutter 测试
    docs/                           各版本交付说明
    dist/                           各版本可运行目录（0.1.1 ～ 0.18.0）
    local/                          开发期 JSON 记录（含用户路径与预设，不进版本库）
  backup-2026-11-05/                已于 2026-11-07 按用户确认删除
```

## 关键实现细节（踩过的坑，避免重犯）

**地图（0.18.0 新增，最易踩坑）**

- **必须用 AMap 1.4，不能用 2.0**。2.0 依赖 WebGL，Flutter 的 WebView 是纹理合成，GPU 上下文起不来，`new AMap.Map()` 会同步阻塞不返回，连定时器都不执行。
- **插件必须用 `AMap.plugin([...], cb)` 显式加载**，写在 script URL 的 `&plugin=` 里不可靠；缺 `AMap.PlaceSearch` 会让后续绑定全部中断。
- **占位符替换必须带引号**。页面用 `'...&key=' + __KEY__` 拼接，替换成裸值会变成非法变量名，整段脚本失效。
- **隐藏 WebView 必须先 `setSize`**。无尺寸则页面不布局、脚本不执行。
- **坐标必须转换**。EXIF 是 WGS-84，高德是 GCJ-02，不转换偏 300–500 米。已在 `app/lib/settings/coords.dart` 实现双向转换。

**其他重要约定**

- 照片记录 `state.fields` 是原地修改的 Map，判断变化不能只比引用。
- 异步回调、定时检查里的异常必须落到界面或日志，不能静默吞掉。
- 打开的文件句柄必须配平，否则照片会被占用、用户在资源管理器里删不掉。
- 弹窗默认「点外部即关闭」，点外部视同取消。
- 修改弹窗/面板后，深浅色两种模式都要看。

## 正式版封包（1.0.0）：必须隐藏的制作版入口

**背景**：所有交付至今都是「制作版」，编译时传了 `--dart-define=LUMACRAFT_AUTHORING=true`。这个开关一关，相关入口会自动隐藏，但**封包前必须逐项核对下面这张表**，确认发行版里一处都不剩。

**开关定义**：`app/lib/editor/builtin_library.dart` 第 9 行

```dart
bool.fromEnvironment('LUMACRAFT_AUTHORING', defaultValue: false)
```

默认 `false`，即**不传这个参数就是发行版**。`PresetStore.authoring` 读取它，界面各处按它判断。

### 一、受开关控制的制作版专用入口（共 8 处）

| # | 位置 | 表现 | 发行版行为 |
|---|---|---|---|
| 1 | `app/lib/ui/preset_actions.dart:417` | 预设面板右上角菜单出现「内置预设维护」 | 整项不出现在菜单里 |
| 2 | `app/lib/ui/preset_actions.dart:434` | `manageBuiltins()` 打开维护面板 | 函数直接 return，打不开 |
| 3 | `app/lib/ui/preset_actions.dart:481` | 右键菜单出现「恢复默认」「恢复默认（N 款）」 | 整项不出现 |
| 4 | `app/lib/main.dart:724` | `openBuiltinEditor()` 进入内置预设编辑 | 直接 return，进不去 |
| 5 | `app/lib/main.dart:1533` | 预设面板的 `onEditBuiltin` 回调 | 传 `null`，入口失效 |
| 6 | `app/lib/ui/editor/editor_panels.dart:1282` | 编辑页预设面板的维护回调 | 传 `null` |
| 7 | `app/lib/ui/editor/editor_canvas.dart:402` | 画布上出现「恢复内置预设」按钮 | 不显示 |
| 8 | `app/lib/ui/editor/editor_panels.dart:520` | 状态文字「正在维护内置预设 · 保存后更新制作版工作库」 | 显示普通文案「草稿仅在确认应用后影响照片。」 |

另外 `app/lib/ui/editor/editor_page.dart:863` 处，制作版走「保存内置预设」分支；发行版走普通「保存预设」。

### 二、内置预设的封包方式

制作版读取的是**本机工作库** `app/local/builtin-working.json`（用户在制作版里调整过的版本）；发行版不读它，只用打包进资源的 `app/assets/builtins/library.json`。

**封包前必须做的事**：

1. 确认 `builtin-working.json` 是用户认可后的最终稿
2. 把它导出到 `app/assets/builtins/library.json`（这是编译进程序的唯一来源）
3. 用发行版构建一次，抽查几个预设的视觉效果与制作版一致
4. 确认发行版**不生成也不需要** `builtin-working.json`

`app/lib/editor/preset_store.dart:53` 在非 authoring 模式下写内置库会抛 `发行版内置预设只读`，这是保护，不要改掉。

### 三、封包步骤

```powershell
# 1. 确认内置预设已导出到 assets/builtins/library.json

# 2. 构建发行版（注意：不传 LUMACRAFT_AUTHORING）
flutter build windows --release --no-pub

# 3. 新建交付目录，不要覆盖旧版本
#    app/dist/LumaCraft-1.0.0/   ← 注意不带 -Authoring 后缀

# 4. 复制 build/windows/x64/runner/Release/ 全部内容（不能只拷 exe）
# 5. 从上一版复制 licenses/
# 6. 把说明文档复制为「使用说明.md」
# 7. 抽查 data/app.so 与构建输出哈希一致
```

### 四、封包后必须核对的清单

| 检查项 | 期望 |
|---|---|
| 预设面板右上角菜单 | 无「内置预设维护」 |
| 预设右键菜单 | 无「恢复默认」 |
| 编辑页画布 | 无「恢复内置预设」按钮 |
| 编辑页状态文字 | 显示「草稿仅在确认应用后影响照片。」 |
| 进入内置预设编辑 | 无法进入 |
| 内置预设数量与外观 | 与定稿一致，41 款 |
| `app/local/` 下是否新建 `builtin-working.json` | 不应新建 |
| 版本号 | 1.0.0，且 `pubspec.yaml` 与程序「关于」页一致 |
| 窗口标题、关于页、GitHub 链接 | 正常 |
| 地图功能 | 发行版仍可用（用户自填 Key） |
| 导出、分享、导入 | 全部可用 |

### 五、容易漏的地方

- **只在发行版构建一次就交付**：制作版跑得好不代表发行版没问题，两条分支的界面不完全相同，必须用发行版实测一遍上面这张表。
- **忘了更新版本号**：`pubspec.yaml` 改 1.0.0 后要重新构建，只改文件不影响已构建的程序。
- **dist 目录命名**：正式版不带 `-Authoring` 后缀，便于和其他版本区分。
- **`启动框印工坊.lnk`**：按版本号自动选最新，1.0.0 会自然成为启动目标，无需手动改。

## 禁止与人工审批

根目录 `AGENTS.md` 持续适用，重点：

- **任何文件删除**都必须单独列出文件和原因取得确认，不能用 clean、递归删除、覆盖式同步绕过。
- **不得覆盖旧交付目录**，每次更新开新版本号 + 新 dist 文件夹。
- **不改原图**；导出默认移除 GPS。
- 新增范围、文件改动先列计划确认。
- 工程的 `app/local/` 含用户路径、EXIF 补填与预设，不能未经授权公开上传。

## 已删除的内容（备查）

- `backup-2026-11-05/`（7.36 GB，0.8.0 时期完整工程副本）：2026-11-07 用户确认删除。删除理由：代码已在 Git 版本库，工具链可重新下载，旧 dist 仍在。**代价：0.8.0 到 0.13.0 之间的源码不再有任何副本**（Git 最早提交是 0.13.0）。
- 临时诊断测试：`gps_diag_test.dart`、`webview_headless_diag_test.dart` 等一次性排查脚本。
