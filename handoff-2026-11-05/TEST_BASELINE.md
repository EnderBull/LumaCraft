# TEST_BASELINE · 交接冻结基线

记录时间：2026-11-05T14:54:35+08:00。实际环境：Windows 11 10.0.26300.9711；Flutter stable 3.47.9；Dart 3.13.7；Visual Studio Build Tools 2022 17.14.44，Windows SDK 10.0.26100.0。完整doctor与SDK版本JSON在evidence。

执行脚本：`tools/run_baseline.ps1`及`tools/legacy_recheck.ps1`。路径存在空格，使用PowerShell调用操作符`&`及引号。执行从项目内工具链，不依赖全局PATH。测试/构建需要SDK缓存可写；本次已获准运行。

`LUMACRAFT_DATA_DIR`使用evidence下包含export-ui-check的独立目录；`PUB_CACHE`指向app/.toolchain/pub-cache；`LUMACRAFT_COLOR_TOOL`指向项目Windows Release工具。每条命令的实际环境见`evidence/command-results.json`，不含私密环境变量转储。

| 检查 | 退出码 | 结论 | 完整输出 |
|---|---:|---|---|
| git-project | 128 | 预期128：无项目Git仓库 | [日志](evidence/git-project.log) |
| flutter-version | 0 | 成功，SDK commit仅属于Flutter | [日志](evidence/flutter-version.log) |
| flutter-doctor | 0 | 进程0，但有3类环境告警；不是全绿 | [日志](evidence/flutter-doctor.log) |
| dart-analysis | 0 | lib/test无问题 | [日志](evidence/dart-analysis.log) |
| flutter-tests | 0 | 30项通过 | [日志](evidence/flutter-tests.log) |
| preview-export | 0 | 1项通过 | [日志](evidence/preview-export.log) |
| preview-builtins | 0 | 1项通过 | [日志](evidence/preview-builtins.log) |
| legacy-core | 64 | 无效调用尝试；本Dart命令拒绝顶层--packages | [日志](evidence/legacy-core.log) |
| legacy-directory | 64 | 同上，不作为脚本本体结论 | [日志](evidence/legacy-directory.log) |
| windows-authoring-build | 0 | Windows x64制作版构建成功 | [日志](evidence/windows-authoring-build.log) |
| legacy-check-direct | 254 | 失败254：普通Dart VM缺Flutter包及dart:ui | [日志](evidence/legacy-check-direct.log) |
| legacy-workspace_io_check-direct | 0 | 通过0：纯Dart目录扫描检查 | [日志](evidence/legacy-workspace_io_check-direct.log) |
| analyzer-config | 2 | warning退出2：flutter_lints include找不到 | [日志](evidence/analyzer-config.log) |

## 完整执行命令

不省略命令参数。日志包含工具原始输出，以下命令与command-results.json对应。

### git-project

工作目录：`D:\AI Agent\LumaCraft`；退出码：128。

```powershell
& 'git' '-C' 'D:\AI Agent\LumaCraft' 'rev-parse' '--show-toplevel'
```

### flutter-version

工作目录：`D:\AI Agent\LumaCraft\app`；退出码：0。

```powershell
& 'D:\AI Agent\LumaCraft\app\.toolchain\flutter\bin\flutter.bat' '--version' '--machine'
```

### flutter-doctor

工作目录：`D:\AI Agent\LumaCraft\app`；退出码：0。

```powershell
& 'D:\AI Agent\LumaCraft\app\.toolchain\flutter\bin\flutter.bat' 'doctor' '-v'
```

### dart-analysis

工作目录：`D:\AI Agent\LumaCraft\app`；退出码：0。

```powershell
& 'D:\AI Agent\LumaCraft\app\.toolchain\flutter\bin\cache\dart-sdk\bin\dart.exe' 'analyze' 'lib' 'test'
```

### flutter-tests

工作目录：`D:\AI Agent\LumaCraft\app`；退出码：0。

```powershell
& 'D:\AI Agent\LumaCraft\app\.toolchain\flutter\bin\flutter.bat' 'test' '--no-pub' '--reporter' 'expanded'
```

### preview-export

工作目录：`D:\AI Agent\LumaCraft\app`；退出码：0。

```powershell
& 'D:\AI Agent\LumaCraft\app\.toolchain\flutter\bin\flutter.bat' 'test' '--no-pub' 'build/export-preview/preview_test.dart' '--reporter' 'expanded'
```

### preview-builtins

工作目录：`D:\AI Agent\LumaCraft\app`；退出码：0。

```powershell
& 'D:\AI Agent\LumaCraft\app\.toolchain\flutter\bin\flutter.bat' 'test' '--no-pub' 'build/builtin-preview/preview_test.dart' '--reporter' 'expanded'
```

### legacy-core

工作目录：`D:\AI Agent\LumaCraft\handoff-2026-11-05\evidence\legacy-core-working`；退出码：64。

```powershell
& 'D:\AI Agent\LumaCraft\app\.toolchain\flutter\bin\cache\dart-sdk\bin\dart.exe' '--packages=D:\AI Agent\LumaCraft\app\test\core\.dart_tool\package_config.json D:\AI Agent\LumaCraft\app\test\core\check.dart'
```

### legacy-directory

工作目录：`D:\AI Agent\LumaCraft\handoff-2026-11-05\evidence\legacy-core-working`；退出码：64。

```powershell
& 'D:\AI Agent\LumaCraft\app\.toolchain\flutter\bin\cache\dart-sdk\bin\dart.exe' '--packages=D:\AI Agent\LumaCraft\app\test\core\.dart_tool\package_config.json D:\AI Agent\LumaCraft\app\test\core\workspace_io_check.dart'
```

### windows-authoring-build

工作目录：`D:\AI Agent\LumaCraft\app`；退出码：0。

```powershell
& 'D:\AI Agent\LumaCraft\app\.toolchain\flutter\bin\flutter.bat' 'build' 'windows' '--release' '--no-pub' '--dart-define=LUMACRAFT_AUTHORING=true'
```

### legacy-check-direct

工作目录：`D:\AI Agent\LumaCraft\app\test\core`；退出码：254。

```powershell
& 'D:\AI Agent\LumaCraft\app\.toolchain\flutter\bin\cache\dart-sdk\bin\dart.exe' run check.dart
```

### legacy-workspace_io_check-direct

工作目录：`D:\AI Agent\LumaCraft\app\test\core`；退出码：0。

```powershell
& 'D:\AI Agent\LumaCraft\app\.toolchain\flutter\bin\cache\dart-sdk\bin\dart.exe' run workspace_io_check.dart
```

### analyzer-config

工作目录：`D:\AI Agent\LumaCraft\app`；退出码：2。

```powershell
& 'D:\AI Agent\LumaCraft\app\.toolchain\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze analysis_options.yaml
```

## 失败、跳过及边界

- 无效--packages调用是交接检查脚本的首次参数尝试，日志保留；随后运行原有`dart run check.dart`和`dart run workspace_io_check.dart`得到脚本真实结论，不将无效调用伪装成产品失败。
- `check.dart`导入链已随产品发展进入Flutter渲染，不能用纯Dart VM执行。本轮只记录，不修复。目录脚本仍可执行。
- `analysis_options.yaml`引用flutter_lints，但pubspec及锁文件无该依赖；局部分析通过不能掩盖配置警告。本轮未加依赖。
- `widget_test.dart`仅有空main和注释，不提供独立断言，30项统计以日志实际运行结果为准。
- Android构建未尝试：doctor明确缺SDK，且当前受管理导出在非Windows直接抛UnsupportedError；macOS/iOS无构建环境；浏览器HTML只是原型，不作为Flutter Web功能验证。
- 未做全量实际相机/HEIC/HDR/广色域配置、系统缩放、长时间性能、最终品牌素材检查。保留历史日志，不把过往单次截图等同本轮重新人工验收。
- 执行命令会写app/build、.dart_tool及测试样片；文件变化见evidence/check-file-delta.json。未修改app/lib或关键资源内容，未删除文件。源代码哈希复核为准。
- 本轮Windows构建使用AUTHORING=true；默认false的发行隔离由builtin_fonts_test验证，未额外重建发行二进制。
