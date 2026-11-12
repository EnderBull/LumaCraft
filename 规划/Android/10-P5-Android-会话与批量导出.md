# Android P5 会话恢复与后台批量导出

2026-11-11。基于 P4.1。应用 ID 为 `com.example.lumacraft.alpha`，安装版本为 `0.20.1-p5`，版本号 69，最低 Android 12。试用包沿用前一版调试签名。

| 用途 | 安装包 | SHA-256 |
| --- | --- | --- |
| ARM64 真机 | `app/dist/LumaCraft-Android-P5/LumaCraft-Android-P5-arm64-v8a.apk` | `ECFEBFEA602F73F63097CB44781FA5EC6DF0033D94A6D86A59340C50B882E683` |
| x86_64 模拟器 | `app/dist/LumaCraft-Android-P5/LumaCraft-Android-P5-x86_64.apk` | `6BBF33540564C7FC4CAA2F3B2508EAB2431443A81FB29C5766B3FADDD9909FD2` |

## 试用

- 首页点「继续编辑」恢复单个会话。长按缩略图显示各照片的 `×`，点栏外隐藏。移出本次选图后可用「撤销」按原顺序恢复。点预览组件时保持编辑栏打开，点空白处收起。
- 导出面板可选当前照片或全部照片。通知与应用内均提供取消。失败弹窗列出照片名，可只重试失败项。默认同名自动编号。开启替换并确认后，仅替换应用自己在 `Pictures/LumaCraft` 中的旧成片。新成片先完整发布，随后处理旧成片及原文件名。
- 从相册分享照片到 LumaCraft 会提示是否开启新会话。系统文件管理器打开 `.lmp` 进入预设导入。支持由文件管理器提供的专用 MIME 类型或带 `.lmp` 文件后缀的通用文件 URI。
- 「更多功能 → 导出诊断」可查看和复制本机的错误记录。记录只有时间和错误类别。

## 验证记录

- Android 12 模拟器从系统文件选择器导入两张照片。长按显示两个移除按钮，移除第二张后撤销，强制结束再启动应用并点击「继续编辑」，两张照片及顺序恢复。
- 确认编辑栏打开时点中题签保留编辑栏，点预览空白处收起。
- 导出两张照片后立即切到桌面并关屏，设备报告 `mWakefulness=Asleep`，相册文件数从 6 增至 8。
- 临时移开一张模拟器测试照片，整批首次只发布一张。恢复文件后只重试失败项，实际相册文件数从 8 到 9 再到 10。`.lmp` 的文件关联通过系统活动解析检查。
- 自动化 13 项通过，覆盖编辑快照、数值手势、构图、预设库及共享导出。见 `app/build/android-p5-core-tests.log`。两份 APK 校验架构、版本、签名和 16 KiB 对齐，构建日志见 `app/build/android-p5-x86_64-build.log` 和 `app/build/android-p5-arm64-v8a-build.log`。
- vivo 锁屏、通知取消、系统相册分享和实际文件管理器 `.lmp` 直开待真机试用。Android 15 及以上使用 `mediaProcessing` 类型，Android 12–14 使用 `dataSync` 类型。若进程被系统结束，下次打开提示导出中断并可恢复编辑。

构建使用 `-PlumacraftP5=true`、`-Ptarget=lib/android_main.dart`，分别指定 `android-arm64` 和 `android-x64`。

## P5.1 真机反馈修订

- 用户反馈 vivo 锁屏时导出疑似暂停，其余 P5 测试通过。导出面板增加锁屏说明，提示解锁回到应用、保持亮屏，或检查系统后台运行限制。暂停的实际原因尚未确认。
- 内置邮戳只提供换墨色，保留原有样式、大小、位置和不透明度。Android 12 模拟器实测航空邮戳从灰色改为 #B72B2B，宽度维持 300，撤销后恢复灰色。导出说明可见。邮戳和 Android 编辑共 9 项测试通过。
- P5.1 的版本号为 70，沿用 P5 包名和签名。用 -PlumacraftP5Patch=true 构建。安装包位于 app/dist/LumaCraft-Android-P5.1/。
