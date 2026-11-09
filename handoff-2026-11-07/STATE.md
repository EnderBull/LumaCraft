# STATE · 冻结状态（2026-11-09）

源码版本 `app/pubspec.yaml`：0.20.1+66，标签 `v0.20.1-beta`。

仓库已公开：`https://github.com/EnderBull/LumaCraft`。预发布：`https://github.com/EnderBull/LumaCraft/releases/tag/v0.20.1-beta`。

## 目录与职责

```text
D:/AI Agent/LumaCraft/
  AGENTS.md                         执行约束、思考方式教训、UI 偏好
  项目台账.md                        功能状态、风险清单、变更记录（最完整）
  README.md                         面向公开仓库的说明
  LICENSE                           GPL-3.0 全文
  docs/screenshots/                 README 截图
  packaging/windows/lumacraft.iss   Windows 安装脚本
  框印工坊-LumaCraft-产品设计方案.md   产品规划，不是现状承诺
  启动框印工坊.lnk                    双击启动最新版
  清理用户数据.bat                    清空本地记录
  tools/                            启动脚本、快捷方式创建脚本
  handoff-2026-11-07/               本次交接（2026-11-08 更新到 0.20.0 Beta）
  app/
    lib/main.dart                   工作台入口、导出流程、浏览
    lib/usage_data.dart             本地数据写入闸门
    lib/settings/                   设置存储、高德服务、坐标转换、地图页面、地理编码
    lib/editor/                     文档模型、控制器、渲染、预设库、.lmp
    lib/fonts/                      内置字体目录
    lib/export/                     导出任务、命名、偏好、色彩管理、中断恢复
    lib/ui/                         共用控件、浏览/编辑/设置界面
    windows/runner/                 无边框窗口、窗口状态、WIC 色彩工具
    assets/builtins/library.json    41 款内置预设（编译进程序的唯一来源）
    assets/ui/                      SVG 图标（layer-* 组件图标 / ui-* 界面图标）
    assets/fonts/                   字体、OFL 许可、来源与哈希
    test/                           Flutter 测试
    docs/                           各版本交付说明
    dist/                           各版本可运行目录，最新为 LumaCraft-0.20.1-Beta
    local/                          开发期 JSON 记录（含用户路径与预设，不进版本库）
    .toolchain/                     Flutter/Dart SDK 与 pub-cache（不进版本库）
    .dart_tool/                     生成配置与编译缓存（不进版本库）
```

## 当前命令与最近结果

```powershell
cd "D:\AI Agent\LumaCraft\app"
$env:PUB_CACHE = "D:\AI Agent\LumaCraft\app\.toolchain\pub-cache"
$env:LUMACRAFT_DATA_DIR = "D:\AI Agent\LumaCraft\app\build\export-ui-check-<每次新目录>"
$env:LUMACRAFT_COLOR_TOOL = "D:\AI Agent\LumaCraft\app\build\windows\x64\runner\Release\lumacraft_color_tool.exe"
```

| 操作 | 命令 | 最近结果 |
|---|---|---|
| 分析 | `flutter analyze lib` | 无 error（2026-11-07，0.20.0 封包前） |
| 测试 | `flutter test --no-pub -j 1` | 236 项通过、1 项跳过。见 TEST_BASELINE |
| 发行版构建 | `flutter build windows --release --no-pub` | 成功，产物即 0.20.1 Beta |
| 制作版构建 | 上一条再加 `--dart-define=LUMACRAFT_AUTHORING=true` | 0.20.0 没有再出制作版 |
| 运行 | 双击 `启动框印工坊.lnk` | 按版本号启动最新目录，即 `dist/LumaCraft-0.20.1-Beta` |
| 安装包 | `ISCC.exe packaging\windows\lumacraft.iss` | `dist/LumaCraft-0.20.1-Beta-Setup.exe`（含简体中文向导） |

**构建前提**：需要 Windows「开发者模式」已开启（插件需要创建符号链接）。仅构建机需要，最终用户不需要。

## 依赖与锁文件

Flutter 3.47.9 / Dart 3.13.7。直接依赖：

| 依赖 | 用途 |
|---|---|
| image | 图像编解码、EXIF |
| file_selector | 文件与目录选择 |
| flutter_svg | SVG 图标 |
| qr | 生成二维码 |
| zxing2 | 识别二维码 |
| webview_flutter_windows | 高德地图（WebView2） |
| shelf | 备用；本地页面实际用 `HttpServer` |
| package_info_plus | 关于页读程序自带版本号 |
| url_launcher | 打开外部网页 |

完整传递依赖见 `app/pubspec.lock`。直接依赖和传递依赖里没有 GPL / LGPL / AGPL。字体是 OFL 1.1，随包保留各自许可证。

## 环境变量

| 变量 | 说明 |
|---|---|
| `PUB_CACHE` | 必须指向项目内 `.toolchain/pub-cache`，否则可能用错全局缓存 |
| `LUMACRAFT_DATA_DIR` | JSON 记录目录。**测试路径必须含 `export-ui-check`**。未设置时从可执行文件向上找 `pubspec.yaml`，找到则用该工程 `app/local` |
| `LUMACRAFT_COLOR_TOOL` | 原生色彩工具路径；不设则优先找主程序旁，再找 `build/windows/x64/runner/Release` |
| `LUMACRAFT_AUTHORING` | **编译期**开关，默认 false。true = 制作版（显示维护入口），不传 = 发行版。0.20.0 Beta 没传 |

## 本地数据文件

全部为版本化 JSON，无数据库。位于 `app/local/`（或 `LUMACRAFT_DATA_DIR`）：

| 文件 | 内容 |
|---|---|
| `photo-state.json` | 逐照片的样式、补填信息、编辑标记、内容指纹 |
| `workspace.json` | 窗口布局、上次目录、收藏、明暗模式。全新文件时收藏为空 |
| `editor-presets.json` | 用户预设与草稿 |
| `export-settings.json` | 导出偏好与命名模板 |
| `app-settings.json` | 高德 Key/安全密钥（简单混淆）、自动填地点开关 |
| `export-recovery.json` | 导出中断进度（正常完成即删除） |
| `export-batch-<id>.json` | 一批导出的样式、字段、文件名、替换授权。进度记录只指向它 |
| `export-recovery.dismissed` | 标记「上次是主动关闭」，仅影响提示措辞 |
| `window-state.txt` | 窗口位置大小（原生侧写入） |
| `builtin-working.json` | **仅制作版**读取的内置预设工作库。发行版不读、也不应新建 |

写文件统一用「先写 `.pending` 再 rename」，避免进程被杀时写坏。清理使用记录时由 `UsageData` 先冻结写入，避免删完又被写回。

记录按完整路径关联照片；搬动或改名后靠「文件名 + 拍摄时间」和「内容指纹（大小 + 首尾 32KB 哈希）」重新认回。指纹在扫描后放到后台分批算。

## 文档与代码已知差异

- 产品设计方案中有早期章节（如图片库选型、原生语言未定），实际已采用 image 包、JSON、Windows C++ WIC。
- 旧交接 `handoff-2026-11-05/`（0.8.0 状态）已在提交 `452da6a` 删除，只能从 Git 历史查看，内容均已过时，以本文和台账为准。
- 台账第 7 节 0.20.0 那一行写着「GitHub 提交 / 发布 / 公开尚未执行」。那是封包当时的待办，随后已经做完。以本文为准。

## 任务看板

| 任务 | 状态 | 下一步 |
|---|---|---|
| Windows 功能到 0.20.1 Beta | ✅ 已发布并公开 | Beta 期，保持暂停 |
| 1.0.0 正式版 | ⬜ 未开始 | 去掉 Beta 字样，按 HANDOFF 发行版清单再封一次 |
| Android 版 | ⬜ 未开始 | 需装 SDK、重做界面适配、地图换方案、处理签名 |
| macOS / iOS | ⬜ 无法进行 | 需 Mac 环境 |
| 英文界面 | ⬜ 未开始 | 抽文案 + 语言切换 |
| 大图内存、安装包瘦身 | ⏸ 用户暂缓 | 不要自行开始 |
