# LumaCraft 工程交接总入口

**开发已按用户要求暂停；交接不代表获准继续开发。**

| 项目 | 当前事实 |
|---|---|
| 工程根目录 | `D:/AI Agent/LumaCraft` |
| 分支 / HEAD | `main` / `8976499`，与 `origin/main` 已同步 |
| 交接文档更新时间 | 2026-11-08 |
| 当前源码版本 | `app/pubspec.yaml`：0.20.0+65 |
| 最新交付 | `D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.20.0-Beta/lumacraft.exe` |
| 公开仓库 | GitHub 公开，`https://github.com/EnderBull/LumaCraft` |
| 预发布 | `https://github.com/EnderBull/LumaCraft/releases/tag/v0.20.0-beta` |
| 许可证 | 代码 GPL-3.0（根目录 `LICENSE`）；Logo 与 `app/assets/branding/` 保留所有权利，不在 GPL 授权范围内 |

## 目标、理念、范围

软件名：框印工坊 / LumaCraft。面向摄影照片的本地边框、水印和自由排版工具。优先 Windows 专业桌面操作；目录直浏览，不依赖导入照片库；预设可编辑、可复用、离线分享；批量导出不改原图。

首版产品规划含 Windows 及后续 Android。**当前实际验证平台只有 Windows x64**，Android 仅为模板工程，不是可交付移动版。macOS/iOS、英文界面属后续规划。

**当前明确不做**：Android 版、macOS/iOS 版、英文界面、RAW 输入、整张高亮度编码的 HDR（缺解码库且涉 HEVC 专利）、大图内存优化、软件瘦身。后两项是用户 2026-11-07 明确暂缓的。

## 接手阅读顺序

1. 根目录 `AGENTS.md` —— 执行约束与思考方式教训，**必须逐条读**。
2. 根目录 `项目台账.md` —— 功能状态、风险清单、变更记录，是最完整的现状来源。
3. 本文 → `STATE.md` → `TEST_BASELINE.md`。
4. `DEVLOG.md`、`ADR/`；面向用户的说明在根目录 `README.md`。

产品设计方案是规划，与实现冲突时以代码和测试为准。

## 当前能运行的功能

| 功能 | 状态 |
|---|---|
| Windows 无边框窗口、目录树、多目录/子目录、Ctrl/Shift 选择、照片预览 | ✅ |
| 组件、图层/分组、拖排/框选、吸附/对齐、撤销重做、锚点换算 | ✅ |
| 形状（8 种）、边框纹理（18 种）、邮票/车票造型、内置邮戳、照片描边 | ✅ |
| 色卡、图片标识、纯色/渐变/照片模糊/纹理背景、胶片打孔、投影、HSB 取色 | ✅ |
| 预设库（搜索/分组/收藏/多选）、`.lmp` 离线分享 | ✅ |
| 分享预设面板：二维码 + 文本代码 + 导出 `.lmp` + 保存图片 | ✅ 0.17.4 |
| 从图片导入预设：读取分享图中的二维码，不需要摄像头 | ✅ 0.17.4 |
| 内置预设 41 款，9 个分组 | ✅ 已定稿；0.20.0 只改了「模糊色卡」描边不透明度为 50 |
| EXIF 读取补填、批量导出、重名处理、导出中断续传 | ✅ |
| sRGB 转换与 ICC 嵌入、EXIF/GPS 策略（导出默认移除 GPS） | ✅ |
| HEIC/HEIF 导入（Windows 解码）、广色域 JPG 预览与导出一致 | ✅ 0.15.0 |
| 照片移动或改名后自动认回（内容指纹 + 文件名/拍摄时间） | ✅ 0.15.x |
| 删除照片后列表自动刷新（含回收站删除、Shift+Delete） | ✅ 0.17.3 |
| 设置面板：通用 / 高德 API / 关于 | ✅ 0.18.0 |
| 地点填写：地图搜索或点选、GPS 自动填、坐标转换 | ✅ 0.18.0 |
| 清理使用记录后自动关闭并重新打开 | ✅ 0.18.2 |
| 续导沿用原批次数据，提示张数不含中断那一张 | ✅ 0.18.1 / 0.18.4 |
| 浏览模式刷新不再打断扫描；指纹改到后台算 | ✅ 0.18.5 |
| 全新安装默认不收藏任何预设 | ✅ 0.20.0 |
| 8 款内置字体、发行版隐藏制作入口 | ✅ |

## 0.20.0 Beta 已发布

这是第一个公开测试版，**不是 1.0.0 正式版**。构建时没有传 `LUMACRAFT_AUTHORING`，所以制作版入口默认隐藏。

| 交付物 | 位置 |
|---|---|
| 绿色版文件夹 | `app/dist/LumaCraft-0.20.0-Beta/` |
| 安装包 | `app/dist/LumaCraft-0.20.0-Beta-Setup.exe`（33.1 MB） |
| 绿色版压缩包 | `app/dist/LumaCraft-0.20.0-Beta-Portable.zip`（40.6 MB） |
| 安装脚本 | `packaging/windows/lumacraft.iss`，用本机 Inno Setup 6 编译 |
| 面向用户的说明 | 根目录 `README.md`；交付文件夹里有 `使用说明.md` |
| 截图 | `docs/screenshots/`。风景照片是 AI 生成的演示图，相机信息是演示数据 |

发行版核对过的事实：

- 关于页显示「版本 0.20.0 Beta」。版本号从程序自带版本资源读取，不再依赖旁边的 `pubspec.yaml`。
- 运行发行版后没有新建 `builtin-working.json`。
- 打包进程序的内置库里，「模糊色卡」色卡描边不透明度是 50。
- exe 属性：产品名 LumaCraft，公司名 LumaCraft，版权为 GPL-3.0。
- 安装向导是英文。Inno Setup 自带语言没有简体中文，软件界面仍是中文。

0.18.5 和 0.18.6 两个文件夹缺少 `licenses`，构建时也没传制作版开关。以 0.20.0 Beta 为准，不要把那两版当成制作版。

## 未完成 / 受阻

- **1.0.0 正式版**：未做。0.20.0 只是 Beta。关于页的 Beta 字样是写死的，做正式版时要拿掉。
- **Android 版**：SDK 未安装，包名仍为 `com.example.lumacraft`、debug 签名，不能发布。地图功能在 Android 上需换方案（不能复用 Windows 的 WebView2）。
- **macOS / iOS**：需要 Mac 环境。
- **英文界面**：未开始。安装向导也还是英文模板。
- **整张高亮度编码的 HDR**：已决定暂不支持，打不开时明确说明原因。
- **RAW 输入**：不做。
- **大图内存、安装包瘦身**：用户要求暂缓。
- **`editor_core_test` 偶发失败（已查明根因，代码未修）**：2026-11-09 已查明（证据见台账 R35）：不是编辑器逻辑问题，而是 Windows 下连续极快保存 JSON 时「`.pending` 改名覆盖原文件」偶发被系统拒绝。**修法已定，尚未改代码**，等恢复开发时做。 修法：把各处「写 `.pending` 再改名」收拢成 `usage_data.dart` 里的共用写入函数，改名失败时间隔 15 毫秒重试 3 次，仍失败则直接写入原文件并清理 `.pending`。涉及 `preset_store.dart`（2 处）、`photo_state.dart`、`workspace_settings.dart`、`export_preferences.dart`、`settings/app_settings.dart`、`export_recovery.dart` 的批次写入，并在 `editor_core_test.dart` 补一条高频保存验证。真实软件保存预设、照片记录、设置时也用同一写法，所以这是潜在的真实风险，不只是测试问题。

## 进行中及下一步

**交接后保持暂停，恢复开发需用户明确指示。** 2026-11-08 用户确认：暂不恢复开发，先留一段 Beta 期再考虑 1.0.0。

用户已确认的方向里，封 Beta 发行版并公开仓库已经做完。还没开始的是：

1. **1.0.0 正式版** —— 去掉关于页的 Beta 字样，版本号改 1.0.0，重新封发行版。制作版入口清单仍在下文，正式版封包时再核一遍。
2. **Android 版** —— 大工程，需重做界面适配与触屏交互、处理签名，地图要换方案。
3. **英文界面** —— 中等工作量，抽文案 + 语言切换。

新 Agent 接手后建议：
1. 读 `AGENTS.md`、`项目台账.md`、本文。
2. `git log --oneline -5` 确认 HEAD 是 `8976499`，本地与 `origin/main` 一致，标签 `v0.20.0-beta` 已在远程。
3. 需要构建/测试时先按 `ENVIRONMENT.template.ps1` 隔离数据目录，不要碰 `app/local` 真实记录。
4. 向用户说明已核实状态与未完成清单，再确认下一步范围。
5. 推送只用本机安装的 `gh` 和现有 `origin`（`https://github.com/EnderBull/LumaCraft.git`）。不要改用 Cursor 绑定的 GitHub。

## 环境与构建

```powershell
$env:PUB_CACHE = "D:\AI Agent\LumaCraft\app\.toolchain\pub-cache"
$env:LUMACRAFT_DATA_DIR = "D:\AI Agent\LumaCraft\app\build\export-ui-check-<新目录>"
$env:LUMACRAFT_COLOR_TOOL = "D:\AI Agent\LumaCraft\app\build\windows\x64\runner\Release\lumacraft_color_tool.exe"
```

| 项目 | 值 |
|---|---|
| Flutter / Dart | 3.47.9 / 3.13.7，在 `app/.toolchain`，不在系统 PATH |
| 发行版构建 | `flutter build windows --release --no-pub`（不传 `LUMACRAFT_AUTHORING`） |
| 制作版构建 | 上面命令再加 `--dart-define=LUMACRAFT_AUTHORING=true` |
| 测试 | `flutter test --no-pub -j 1`，见 TEST_BASELINE |
| 直接依赖 | image、file_selector、flutter_svg、qr、zxing2、webview_flutter_windows、shelf、package_info_plus、url_launcher |
| 构建前提 | **需要 Windows 开发者模式**（插件符号链接），仅构建机需要，最终用户不需要 |
| 安装包 | 本机已装 Inno Setup 6：`%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe` |

**启动软件**：双击项目根目录 `启动框印工坊.lnk`，脚本在 `tools/`，按版本号自动启动 `app/dist` 里最新的版本。0.20.0 Beta 会成为启动目标。

**Git 推送**：系统开着代理时，`git push` 需临时加 `-c http.proxy=... -c https.proxy=...`，详见 `AGENTS.md` 纠正记录。推送前先读注册表 `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings` 的 `ProxyEnable` 与 `ProxyServer`。2026-11-07 实测代理是 `127.0.0.1:7897`，这个地址会变，不要写死。

## 目录结构

```text
D:/AI Agent/LumaCraft/
  AGENTS.md                         执行约束、思考方式教训、UI 偏好
  项目台账.md                        功能状态、风险、变更记录（最重要）
  README.md                         面向公开仓库的说明，含截图
  LICENSE                           GPL-3.0 全文
  docs/screenshots/                 README 用的 4 张界面截图
  packaging/windows/lumacraft.iss   Windows 安装脚本
  启动框印工坊.lnk                    双击启动最新版本
  tools/                            启动脚本与快捷方式创建脚本
  handoff-2026-11-07/               本次交接（2026-11-08 已更新到 0.20.0 Beta）
  app/
    lib/main.dart                   工作台入口、导出流程、图片浏览
    lib/usage_data.dart             本地数据写入闸门，清理记录时防止写回
    lib/settings/                   设置存储、高德服务、坐标转换、地图页面
    lib/editor/                     文档模型、控制器、渲染、预设库/.lmp
    lib/export/                     导出任务、命名、偏好、色彩管理、中断恢复
    lib/ui/                         共用控件、浏览/编辑/设置界面
    windows/runner/                 无边框窗口、窗口状态、WIC 色彩工具
    assets/builtins/library.json    41 款内置预设
    assets/ui/                      SVG 图标（layer-* / ui-*）
    test/                           Flutter 测试
    docs/                           各版本交付说明
    dist/                           各版本可运行目录，最新为 LumaCraft-0.20.0-Beta
    local/                          开发期 JSON 记录（含用户路径与预设，不进版本库）
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
- 浏览模式扫描被取消时必须带「已取消」标记，调用方丢掉结果。残缺列表不能当成删除。
- 扫描后的照片指纹用后台分批计算，不要回到界面线程里逐张算。

## 发行版与制作版

0.20.0 Beta 已经按发行版封过一次。下面的清单留给下一次封包核对，不要凭印象。

**开关定义**：`app/lib/editor/builtin_library.dart`

```dart
bool.fromEnvironment('LUMACRAFT_AUTHORING', defaultValue: false)
```

默认 `false`，即**不传这个参数就是发行版**。`PresetStore.authoring` 读取它，界面各处按它判断。

### 一、受开关控制的制作版专用入口

| # | 位置 | 表现 | 发行版行为 |
|---|---|---|---|
| 1 | `app/lib/ui/preset_actions.dart` 菜单项 | 预设面板右上角菜单出现「内置预设维护」 | 整项不出现在菜单里 |
| 2 | `manageBuiltins()` | 打开维护面板 | 函数直接 return，打不开 |
| 3 | 同一文件右键菜单 | 出现「恢复默认」「恢复默认（N 款）」 | 整项不出现 |
| 4 | `app/lib/main.dart` `openBuiltinEditor()` | 进入内置预设编辑 | 直接 return，进不去 |
| 5 | `app/lib/main.dart` 预设面板 | `onEditBuiltin` 回调 | 传 `null`，入口失效 |
| 6 | `app/lib/ui/editor/editor_panels.dart` | 编辑页预设面板的维护回调 | 传 `null` |
| 7 | `app/lib/ui/editor/editor_canvas.dart` | 画布上出现「恢复默认」按钮 | 不显示 |
| 8 | `app/lib/ui/editor/editor_panels.dart` 状态文字 | 「正在维护内置预设 · 保存后更新制作版工作库」 | 显示普通文案「草稿仅在确认应用后影响照片。」 |

另外 `app/lib/ui/editor/editor_page.dart` 里，制作版走「保存内置预设」分支；发行版走普通「保存预设」。行号会随改动变化，按函数名找，不要按旧行号找。

### 二、内置预设的封包方式

制作版读取的是**本机工作库** `app/local/builtin-working.json`；发行版不读它，只用打包进资源的 `app/assets/builtins/library.json`。

2026-11-07 封 0.20.0 时，工作库和 `library.json` 哈希一致，都是 41 款。唯一改动是「模糊色卡」色卡描边不透明度从 49.6 改为 50，两边都改了。

`app/lib/editor/preset_store.dart` 在非 authoring 模式下写内置库会抛 `发行版内置预设只读`，这是保护，不要改掉。

### 三、封包步骤

```powershell
# 1. 确认内置预设已在 assets/builtins/library.json

# 2. 构建发行版（注意：不传 LUMACRAFT_AUTHORING）
cd "D:\AI Agent\LumaCraft\app"
.\.toolchain\flutter\bin\flutter.bat build windows --release --no-pub

# 3. 新建交付目录，不要覆盖旧版本
#    app/dist/LumaCraft-<版本>-Beta/   或正式版不带 Beta

# 4. 复制 build/windows/x64/runner/Release/ 全部内容（不能只拷 exe）
# 5. 从 0.20.0 Beta 复制 licenses/
# 6. 写「使用说明.md」
# 7. 核对 data/app.so 与构建输出一致，exe 版本号与 pubspec 一致
# 8. 用 packaging/windows/lumacraft.iss 出安装包，再打绿色版 zip
```

### 四、封包后必须核对的清单

| 检查项 | 期望 |
|---|---|
| 预设面板右上角菜单 | 无「内置预设维护」 |
| 预设右键菜单 | 无「恢复默认」 |
| 编辑页画布 | 无「恢复默认」按钮 |
| 编辑页状态文字 | 显示「草稿仅在确认应用后影响照片。」 |
| 进入内置预设编辑 | 无法进入 |
| 内置预设数量与外观 | 与定稿一致，41 款 |
| 运行后是否新建 `builtin-working.json` | 不应新建 |
| 版本号 | `pubspec.yaml`、exe 属性、关于页一致 |
| 窗口标题、关于页、GitHub 链接 | 正常 |
| 地图功能 | 发行版仍可用（用户自填 Key） |
| 导出、分享、导入 | 全部可用 |
| 全新数据目录 | 收藏为空 |

### 五、容易漏的地方

- **只在发行版构建一次就交付**：制作版跑得好不代表发行版没问题，两条分支的界面不完全相同，必须用发行版实测一遍上面这张表。
- **忘了更新版本号**：`pubspec.yaml` 改完后要重新构建，只改文件不影响已构建的程序。
- **只拷 exe**：色彩工具、`data/`、`licenses/` 必须一起走。
- **`启动框印工坊.lnk`**：按版本号自动选最新，新目录会自然成为启动目标，无需手动改。
- **公开仓库后的发布**：只用本机 `gh`，先建预发布再上传安装包和绿色版。仓库已经是公开的，不要再改可见性，除非用户明确要求。

## 禁止与人工审批

根目录 `AGENTS.md` 持续适用，重点：

- **任何文件删除**都必须单独列出文件和原因取得确认，不能用 clean、递归删除、覆盖式同步绕过。
- **不得覆盖旧交付目录**，每次更新开新版本号 + 新 dist 文件夹。
- **不改原图**；导出默认移除 GPS。
- 新增范围、文件改动先列计划确认。
- 工程的 `app/local/` 含用户路径、EXIF 补填与预设，不能未经授权公开上传。
- 仓库已经公开。历史提交也会被看到。不要把密钥、真实照片路径写进以后的提交。

## 已删除的内容（备查）

- `backup-2026-11-05/`（7.36 GB，0.8.0 时期完整工程副本）：2026-11-07 用户确认删除。删除理由：代码已在 Git 版本库，工具链可重新下载，旧 dist 仍在。**代价：0.8.0 到 0.13.0 之间的源码不再有任何副本**（Git 最早提交是 0.13.0）。
- 临时诊断测试：`gps_diag_test.dart`、`webview_headless_diag_test.dart` 等一次性排查脚本。
- 2026-11-07 截图用的演示照片：`app/build/demo-photos/` 及生成脚本、截图脚本已按用户确认删除。`C:\LumaCraft-Demo\` 按用户要求保留。
