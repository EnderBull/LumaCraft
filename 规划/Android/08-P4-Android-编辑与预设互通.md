# Android P4 编辑与预设互通

2026-11-10。分支 `codex/android`，基线提交 `ac439e1`。APK 包含当前工作区 P0～P4 的 Android 开发改动。

## 安装

| 设备 | 安装包 | SHA-256 |
| --- | --- | --- |
| vivo X100 Ultra 等 ARM64 手机 | `app/dist/LumaCraft-Android-P4/LumaCraft-Android-P4-arm64-v8a.apk` | `C97DA4AE24EA46DCCAF9EC779645F87CD06A62DB9476221F9BFA189826D0C553` |
| x86_64 模拟器 | `app/dist/LumaCraft-Android-P4/LumaCraft-Android-P4-x86_64.apk` | `B003A3C7FA6E616B2A084124AA6D49774E5812414E4F452E06ADE53A8440722E` |

安装名 LumaCraft Beta，版本 `0.20.1-p4`，版本号 67，最低 Android 12（API 31），目标 API 36。沿用 P3 的 `com.example.lumacraft.alpha` 和本机调试签名，可覆盖安装并保留预设库和收藏。会话仍以本次打开为单位。

## 试用入口

1. 选照片后点顶栏「编辑样式」。选已有组件，编辑共用样式或「仅修改本张文字」。文本和数值可在键盘上点完成，也可点其他控件提交。形状和图片尺寸可调，原有组件位置、锚点和层级沿用预设。
2. 在「更多功能 → 照片信息」补填当前照片的拍摄信息。已有原始值会显示，留空可恢复原值。地图使用自备高德 JS API Key 和安全密钥，确认地图点位后只填入当前照片的地点字段，原图 GPS 保持原有导出规则。
3. 在「更多功能 → 预设保存与分享」新建用户预设、覆盖用户预设，或导入导出 `.lmp`、文本代码和二维码图片。分享内容只包含共用样式，照片级覆盖留在当前会话。超过 2,331 字节的二维码改用文本或 `.lmp`。系统语言缺少对应界面资源时回退简体中文，主题跟随系统。

## 验证

- Android 12 x86_64 模拟器从系统文件选择器导入两张照片和 Windows 复杂 `.lmp`。字号从 32 改到 44，撤销恢复 32，重做回到 44。导出的 `app/build/android-p4-roundtrip.lmp` 由 Windows 预设读取器回读，图片字节、分组、横竖布局和样式、组件、分组扩展字段均保留。
- Android 生成二维码图片并保存到相册，随后从文件选择器重新导入。最初单独方形二维码被旧裁剪逻辑裁去边缘，修复后原图先识别，原有 Windows 分享卡片裁剪路径继续作为后备。生成的 740 字节文本代码已通过系统文件保存和重新导入。
- `app/build/android-p4-core-tests.log` 记录 28 项通过，涵盖批次样式与逐张文字、地点解析、构图适配、预设库、分享代码、二维码和 Windows 导出核心流程。41 款内置预设中二维码数据最长 1,358 字节。接近容量上限的方形二维码也通过生成与回读。P4 APK 的目标架构、调试签名和 16 KiB 对齐均通过校验。
- P4 的高德确认选点到照片地点仍待真机在线验收。P2 的高德在线地图已由用户验收。P4 的界面为功能验证版本，整体布局和操作逻辑按约定留待功能完善后调整。

## 代码与复现

- `app/lib/ui/android/` 接入 Android 属性编辑、逐张内容和预设分享。`app/lib/settings/android_map_preview.dart` 与 Kotlin `AndroidP1Bridge.kt` 接入地图确认及系统文件保存。`app/lib/editor/preset_package.dart` 和 `qr_scan.dart` 共享预设素材隐私处理与二维码识别。
- 在 `app` 中加载 `. .\tools\android-p0-env.ps1`。构建使用 Gradle `:app:assembleDebug --offline`，指定 `-PlumacraftP4=true -Ptarget=lib/android_main.dart` 以及 `-Ptarget-platform=android-x64` 或 `android-arm64`。构建日志见 `app/build/android-p4-x86_64-build.log` 和 `app/build/android-p4-arm64-v8a-build.log`。
- 核心验证使用 `flutter --no-version-check test --no-pub -j 1 --reporter expanded`。测试文件为 `android_mobile_edits_test.dart`、`layout_adaptation_test.dart`、`preset_library_test.dart`、`preset_code_test.dart`、`preset_qr_test.dart`、`export_pipeline_test.dart`、`p2_preset_roundtrip_test.dart`。用 `LUMACRAFT_P2_ANDROID_PRESET` 指向实际导出的 `.lmp` 可复现 Windows 回读断言。

P5 规划见《分阶段开发实施计划》，包含会话恢复、外部分享入口和后台批量导出。
