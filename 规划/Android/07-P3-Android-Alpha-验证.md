# Android P3 Alpha 验证

2026-11-10。分支 `codex/android`。以 P2 通过真机验收的共享导出和安卓平台接口为基线。

## 试用

| 设备 | 安装包 | SHA-256 |
| --- | --- | --- |
| vivo X100 Ultra 等 ARM64 手机 | `app/dist/LumaCraft-Android-Alpha/LumaCraft-Android-Alpha-arm64-v8a.apk` | `CF98C0FFA0FD0BC636E4789D7C81931EE4CB000198DC685AB4F1B881E500B7F0` |
| x86_64 模拟器 | `app/dist/LumaCraft-Android-Alpha/LumaCraft-Android-Alpha-x86_64.apk` | `5B272F49A57A49380D90686A305CA9AF8015C276E761FE911ED1304AB07A7F1D` |

两份 APK 的安装名为「LumaCraft Alpha」，应用 ID 为 `com.example.lumacraft.alpha`，最低 Android 12（API 31），目标 API 36。通过调试签名、目标 ABI 和 APK 16 KiB 对齐校验。可与 P2 并存。

1. 点「选择照片」，从相册或文件导入。文件选择器中可长按一张再多选。一次最多导入 30 张，底部缩略图切换当前照片。
2. 点「选择预设」，浏览实时缩略图，可按名字、分组、收藏筛选。切换照片沿用同一套预设。点主预览进入全屏，支持双指放大、拖动和上一张、下一张。
3. 点「导出照片」，选择 JPG 或 PNG，尺寸留空时导出原尺寸，也可填长边或短边。JPG 可调整画质，默认保留拍摄参数、移除 GPS。每次保存当前照片到 `Pictures/LumaCraft`。

模拟器已安装 Alpha，测试照片在其内部存储 `Download/LumaCraft-P3`。启动模拟器后可在项目 `app` 目录执行：

```powershell
. .\tools\android-p0-env.ps1
adb -e shell am start -W -n com.example.lumacraft.alpha/com.example.lumacraft.MainActivity
```

## 验证结果

- Android 12 模拟器实际在系统文件选择器多选一张 JPEG 和一张 HEIC。两张都进入缩略图带。应用「色带边框」，从全屏切到第二张后，工作台仍显示同一预设。实测分组和收藏筛选。
- JPEG 原尺寸 JPG 保存成功。HEIC 以短边 600 导出 PNG，MediaStore 两次发布均为 `is_pending=0`。同名 PNG 自动保留两份。
- Windows 与 Android 使用同一份 HEIC、同一预设及短边 600，对照成片均为 713 × 600。回读两端 PNG 均有 EXIF 拍摄时间与 ICC。Android PNG 的 sRGB ICC 逐字节核验，GPS IFD 按默认设置移除。用实际 Manrope 字体生成 Windows 对照，边框与文字布局吻合。该合成图的部分颜色和色卡取样有可见差异，分别经过 Windows WIC 和 Android ImageDecoder。
- Android 12 模拟器的「从相册选择」回退到了系统文件选择器。取消后保留两张照片、当前照片和预设。用户随后确认 P3 Alpha 真机功能测试全部通过。
- Windows 导出、工作台、构图和 P2 预设往返 7 项回归通过。Alpha 静态检查为 0 错误、0 警告，5 条格式提示。
- 截图 `app/build/android-p3-home.png`、`android-p3-presets.png`、`android-p3-export.png`、`android-p3-fullscreen.png` 来自 320 × 640 Android 模拟器。

## 代码与复现

- `app/lib/android_main.dart` 和 `app/lib/ui/android/` 是手机 Alpha 入口和工作台。预设直接读取 `PresetStore`，收藏用现有本地设置模型，实时和全屏预览用 `StylePreview`。
- `app/lib/export/android_photo_io.dart` 和 Kotlin `AndroidP1Bridge.kt` 接系统照片选择、文件多选、解码和 MediaStore 保存。Alpha 的色卡使用安卓转为 sRGB 的预览文件，预览与导出使用同一取样路径。
- Android 构建沿用 P2 的 Gradle `:app:assembleDebug`，目标入口改成 `-Ptarget=lib/android_main.dart`，以 `-PlumacraftP3=true` 分别构建 `android-x64` 和 `android-arm64`。日志见 `app/build/android-p3-x86_64-build.log`、`android-p3-arm64-v8a-build.log`。
- Windows 回归使用 `flutter --no-version-check test --no-pub -j 1 --reporter expanded`，目标为 `test/export_pipeline_test.dart`、`test/export_workspace_flow_test.dart`、`test/layout_adaptation_test.dart` 和 `test/p2_preset_roundtrip_test.dart`，使用名称含 `export-ui-check` 的隔离数据目录。日志见 `app/build/android-p3-windows-regression.log`。
- 模拟器操作与发布记录在 `app/build/android-p3-runtime.log`。成片对照为 `android-p3-android-output.png` 和 `android-p3-windows-reference.png`，Windows 参考渲染日志为 `android-p3-parity-windows.log`。

P4 接组件属性编辑、逐张文字、预设互通和地图的正式手机入口。P5 接会话恢复、分享入口和后台批量。当前 Alpha 在源图超过设备单张纹理上限时会报告失败，原尺寸保护沿用 P2。

用户反馈 Alpha 的界面布局和操作逻辑仍需调整，决定在 Android 功能完善后统一处理。
