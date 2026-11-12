# Android P6 第一轮交互试用

2026-11-11。试用版本 `0.20.1-p6.1`，版本号 71，最低 Android 12。安装 ID 和签名沿用 P5.1。

| 用途 | APK | SHA-256 |
| --- | --- | --- |
| ARM64 真机 | `app/dist/LumaCraft-Android-P6.1/LumaCraft-Android-P6.1-arm64-v8a.apk` | `F6A11448BCE6D060355CB97A7F3303ECFF2CDFF1C9784BD083A2553ADC8836F1` |
| x86_64 模拟器 | `app/dist/LumaCraft-Android-P6.1/LumaCraft-Android-P6.1-x86_64.apk` | `C7DDF060BDA1C5F34ACCDB82EDC3223D0FE4205F797AA95550919A57B6227563` |

- 首页顶栏和主区域共用同一表面色。无会话时选图圆形居中，有会话时和继续编辑圆形轻微重叠。首页管理预设可浏览、搜索、收藏、导入和按条目分享。
- 编辑栏、底栏和预览用同一动画进度，持续 220 毫秒并响应系统减少动态效果设置。照片层与选中框分开，预览区域改变尺寸时可复用照片的绘制记录。组件条只在选中项超出可视区时滚动。

## 验证

- Android 12 模拟器通过浅色无会话首页、深色有会话首页、选图入口、预设分享及恢复会话。连续五次开合编辑栏、动画中途返回和照片双击进出全屏通过。
- 12 项测试通过，包含数值手势、预设库、构图及预览图层回归。测试让预览连续改变五次尺寸，照片绘制层的同步重画计数保持原值。两份安装包通过架构、版本、签名和 16 KiB 对齐校验。日志见 `app/build/android-p6.1-core-tests.log`。
- vivo 的实际帧率、双指缩放与长列表滑动手感待真机对比。测试证明动画复用了照片绘制层，实际帧率尚未采集。

构建使用 `-PlumacraftP6Ui=true` 和 `-Ptarget=lib/android_main.dart`。

## P6.2 真机反馈修订

2026-11-11。试用版本 `0.20.1-p6.2`，版本号 72，最低 Android 12。安装 ID 和签名沿用 P6.1。

| 用途 | APK | SHA-256 |
| --- | --- | --- |
| ARM64 真机 | `app/dist/LumaCraft-Android-P6.2/LumaCraft-Android-P6.2-arm64-v8a.apk` | `949D60EE3629A6FD4C441CBEDB8C6A6A6B67A7CDF7849025DDBA531CFA31E1E5` |
| x86_64 模拟器 | `app/dist/LumaCraft-Android-P6.2/LumaCraft-Android-P6.2-x86_64.apk` | `3FB927A8D97857A17342B238C053FA226F7BB356F7F279DFC21603789D20FE13` |

- 首页按可用屏幕宽度居中，继续编辑圆形直径为主按钮的 64%。选图图标的加号和框线分开。
- 预设导入入口和管理标题同一行，文本代码输入框随屏幕加宽。导入进度使用覆盖层，保留各选项点击前的坐标。分组菜单有上下滚动的回弹反馈。
- 缩略图移除按钮显示在右上角，图标底色直径为 20 dp，触控区为 44 dp。全屏进出采用 140/120 毫秒淡入淡出，响应系统减少动态效果设置。
- 预设缩略图按照片和样式在面板内复用低分辨率渲染结果，窗口请求设备支持的最高刷新率，上限约 120 Hz。vivo 实际动画帧率和滚动手感待真机验证。
- 模拟器使用 420 像素宽视口时，单圆按钮与管理预设按钮均在 x=210 居中。管理标题和导入按钮中心同在 y=206。文本导入正文宽度为 340 像素。分组可滑动后选择，二维码图片入口选择样本后成功导入。
- 9 项核心测试通过，见 `app/build/android-p6.2-core-tests.log`。两个 APK 均通过架构、版本、签名和 16 KiB 对齐校验。构建使用 `-PlumacraftP6Patch=true` 和 `-Ptarget=lib/android_main.dart`。
- 有会话时，选图与继续编辑的组合范围为 x=82 到 x=338，仍以 x=210 为中心。模拟器已走通选图、进出全屏、长按移除与撤销、继续编辑和预设列表滚动。

## P6.3 首页、编辑与扫码

2026-11-11。性能试用版 `0.20.1-p6.3`，版本号 73，最低 Android 12。沿用 P6.2 的安装 ID 和调试签名，可覆盖安装。

| 用途 | APK | 字节 | SHA-256 |
| --- | --- | ---: | --- |
| ARM64 真机 | `app/dist/LumaCraft-Android-P6.3/LumaCraft-Android-P6.3-arm64-v8a-profile.apk` | 66951039 | `AD9D8E503E75868D9977840D8E26EEF1EFB29D7D170D6AAC80C0F81527C51D28` |
| x86_64 模拟器 | `app/dist/LumaCraft-Android-P6.3/LumaCraft-Android-P6.3-x86_64-profile.apk` | 67016566 | `4A7247A8EC3A771292911940463B7283567FEB37FF4A49EB3EB8C80754C9D077` |

- 首页双圆按钮下移、分开并加淡阴影，管理预设上移。恢复会话从继续编辑按钮位置圆形展开；选图后横滑进入。编辑顶栏显示撤销、重做，组件条端点回弹，属性面板用 280 毫秒缓动开合。
- 首页和编辑页共用预设选择面板及 2×2 导入菜单。导入支持 .lmp、文本、二维码图片、相机扫码。扫码采用 Android Camera2 与已有 ZXing 灰度识别和预设校验，无新第三方依赖。只从扫码页请求相机权限。完整预设编辑的电脑端提示在导入菜单内。
- 预设缩略图在滚动期间延后生成。安卓端构图标记阴影改用直接绘制羽化圆角。420×860 Android 12 软件渲染模拟器性能包样本中，阴影改动前后，回滚栅格绘制中位数为 6.96 → 5.01 ms，首次滑动中位数约 15.5 ms。最终属性栏开合样本的栅格绘制中位数 3.41 ms、最大值 6.30 ms。以上是绘制阶段的耗时，vivo 上的完整帧时间和扫码实拍待验证。
- 13 项核心测试通过，见 `app/build/android-p6.3-core-tests.log`。模拟器验证两个导入入口、相机权限与预览、二维码图片导入与结果提示、恢复会话、编辑顶栏和属性栏开合。两份性能 APK 校验了架构、版本、签名和 16 KiB 对齐。
- 使用 `-PlumacraftP63=true`、`-Ptarget=lib/android_main.dart` 与 Gradle `:app:assembleProfile`。性能采样记录在 `app/build/android-p6.3-*-timeline.json`。

## P6.4 首页弧形留缝与预设面板首开

2026-11-11。性能试用版 `0.20.1-p6.4`，版本号 74，最低 Android 12，延用 P6.3 安装 ID 与签名。

| 用途 | APK | SHA-256 |
| --- | --- | --- |
| ARM64 真机 | `app/dist/LumaCraft-Android-P6.4/LumaCraft-Android-P6.4-arm64-v8a-profile.apk` | `0F8973168A52B715B65345EE280D1594A86D3C44623788FD5272CA923438AE1F` |
| x86_64 模拟器 | `app/dist/LumaCraft-Android-P6.4/LumaCraft-Android-P6.4-x86_64-profile.apk` | `29A86D8995EF4ABBD568D0C6F7CEFB6154DBBEEAFB03D1CD3BDD6ACE473E578A` |

- 选择照片圆形在继续编辑左上方，两者投影范围交叠。继续编辑沿大圆边缘切出 4 dp 弧形缝，留缝区不响应继续编辑。三个首页按钮阴影加深。
- 共用预设面板上滑时先绘制轻量占位，过渡结束后再构建完整卡片和生成缩略图。已在 420×860 的 Android 12 模拟器检查首页截图、打开管理预设和继续编辑。
- 首开采样从首个栅格绘制起算，前 250 ms 内 P6.3 的一个样本有 2 次完成绘制，P6.4 两个样本各有 15 次。最慢单帧仍约 32 ms。该结果来自软件渲染模拟器，vivo 首开手感待实测。原始采样为 `app/build/android-p64-before.json`、`android-p64-after.json`、`android-p64-after-repeat.json`。
- 8 项核心测试通过，见 `app/build/android-p6.4-core-tests.log`。两份 APK 的架构、版本、签名及 16 KiB 对齐均通过校验。使用 `:app:assembleProfile -PlumacraftP64=true -Ptarget=lib/android_main.dart` 构建。

## P6.5 撤销提示、返回动画与扫码取景

2026-11-11。性能试用版 `0.20.1-p6.5`，版本号 75，最低 Android 12，沿用 P6.4 安装 ID 和签名。

| 用途 | APK | SHA-256 |
| --- | --- | --- |
| ARM64 真机 | `app/dist/LumaCraft-Android-P6.5/LumaCraft-Android-P6.5-arm64-v8a-profile.apk` | `985D251D7AE662A07FF8B25CA4CA52B413C71C7ABAB97A6842D949DA6A47C77D` |
| x86_64 模拟器 | `app/dist/LumaCraft-Android-P6.5/LumaCraft-Android-P6.5-x86_64-profile.apk` | `51D4EBB31BE1581845FDD605802000FC6224112D6615244C5DEEDDAD775701EE` |

- 移除照片提示显示 5 秒，期间保留撤销。模拟器验证了撤销恢复照片、未操作时提示自动消失。
- 左上返回和系统返回共用收回首页的流程。组件属性打开时先收起。继续编辑按钮位置按首页实际布局测量，模拟器抓帧确认工作台收成以该按钮为中心的圆形。
- 组件属性面板顶部增加拖动条，验证轻拖回弹、向下长拖关闭。拖动手势位于顶部区域，属性列表保留自己的滚动。
- 扫码预览改为 Flutter SurfaceProducer，根据预览后端是否已处理旋转决定是否补旋转，视口按缓冲区尺寸等比适配。模拟器虚拟场景的竖屏画面直立，横屏视口等比切换。模拟器强制横屏不会同步模拟手持旋转，vivo 实拍画面方向与真实扫码待复验。
- 9 项核心测试通过，含从灰度帧识别预设二维码，见 `app/build/android-p6.5-core-tests.log`。两份 APK 的架构、版本、签名与 16 KiB 对齐通过验证。构建使用 `:app:assembleProfile -PlumacraftP65=true -Ptarget=lib/android_main.dart`。

## P6.6 安卓地图修复

2026-11-11。性能试用版 `0.20.1-p6.6`，版本号 76，最低 Android 12，沿用 P6.5 安装 ID 和签名。

| 用途 | APK | SHA-256 |
| --- | --- | --- |
| ARM64 真机 | `app/dist/LumaCraft-Android-P6.6/LumaCraft-Android-P6.6-arm64-v8a-profile.apk` | `8F264D64263D55C5C4168449BA812C65417A16EABED5648217709A117CE822E4` |
| x86_64 模拟器 | `app/dist/LumaCraft-Android-P6.6/LumaCraft-Android-P6.6-x86_64-profile.apk` | `E8FA7688CB1BBA28EEA39311232DC0FEA2EDB024C73B723011BB63203692C5DF` |

- 本机 HTTP 放行规则由 Debug 专属目录迁入 Android 共用配置，仅允许 `127.0.0.1`。两份性能 APK 已检查清单、规则资源、架构、签名及 16 KiB 对齐。
- 手机设置增加测试连接。测试使用尚未保存的输入，复用选点页 WebView、高德脚本和地址解析插件。使用固定测试坐标，不读取用户当前位置。加载失败或超时显示阶段提示。
- Android 12 模拟器覆盖安装通过。空输入显示校验提示，无效测试 Key 运行到高德地址解析阶段并显示失败提示。生成页面的脚本模拟覆盖成功、脚本失败、地址失败和超时。4 项现有核心测试通过。有效 Key 的连接成功和实际选点仍待 vivo 验证。
- 构建使用 `:app:assembleProfile -PlumacraftP66=true -Ptarget=lib/android_main.dart`，日志见 `app/build/android-p6.6-core-tests.log` 和 `app/build/android-p6.6-map-script.log`。

## P6.7 首页、设置和预设管理

2026-11-11。性能试用版 `0.20.1-p6.7`，版本号 77，最低 Android 12，沿用 P6.6 安装 ID 和签名。

| 用途 | APK | SHA-256 |
| --- | --- | --- |
| ARM64 真机 | `app/dist/LumaCraft-Android-P6.7/LumaCraft-Android-P6.7-arm64-v8a-profile.apk` | `C86BC6E720FE0072C6153ACA278F5D441B2EE579CA921DB50818C311A64899A8` |
| x86_64 模拟器 | `app/dist/LumaCraft-Android-P6.7/LumaCraft-Android-P6.7-x86_64-profile.apk` | `53DC472436F54905D7DEB9FC35DA53B75B41D3EB5569EE35B4A7F1F97B43D67A` |

- 首页圆形按钮组再下移，管理预设上移。设置按通用、高德 API、关于分区，通用包括外观、预设管理及缩略图缓存，高德区复用保存与连接测试。
- 管理预设的操作改为 4×2 底部菜单，内置预设禁用移动、删除和重命名。用户预设支持移动到已有分组或新建分组，删除要求确认。分组筛选新增未分组。
- 二维码图上半部保留白色扫码留白，底栏左侧为应用图标和名称，右侧为预设名称，采用无竖线版。样图 `app/build/p67-qr-gallery-preview.png`。
- 13 项测试通过，覆盖真实样图和近容量上限二维码的回读。Android 12 模拟器覆盖安装并验证外观切换、高德测试入口、关于页版本、内置预设禁用状态、导出二维码，以及测试副本的复制、重命名、移动到新建分组和删除。两份 APK 通过清单、架构、签名及 16 KiB 对齐校验。
- 构建使用 `:app:assembleProfile -PlumacraftP67=true -Ptarget=lib/android_main.dart`，测试日志见 `app/build/android-p6.7-core-tests.log`。

## P6.8 预设操作与导入确认

2026-11-11。性能试用版 `0.20.1-p6.8`，版本号 78，最低 Android 12，沿用 P6.7 安装 ID 和签名。

| 用途 | APK | SHA-256 |
| --- | --- | --- |
| ARM64 真机 | `app/dist/LumaCraft-Android-P6.8/LumaCraft-Android-P6.8-arm64-v8a-profile.apk` | `8E78B0A9FD2AC9A418A3CA23DA13EEFBFEDBFF3681AA5756BA296B3633017C2A` |
| x86_64 模拟器 | `app/dist/LumaCraft-Android-P6.8/LumaCraft-Android-P6.8-x86_64-profile.apk` | `D0A7827AF53CC8C09C93C80C4EABA4A8FEA8593A520AAA71AF4A0A9A11D838E4` |

- 预设操作按钮使用菜单底色，图标 29 dp，缩短图文间距并保留内置预设禁用状态。
- .lmp、文本、二维码图片、相机扫码及系统打开 .lmp 共用确认框。识别并校验后显示名称和样式渲染，多项可滚动，确认后写入。示意图从软件图标的矢量场景导出为随包素材，预览使用示意拍摄数据。
- 9 项测试通过，包括批量确认框的取消与确认。Android 12 模拟器覆盖安装后，实测二维码识别、渲染预览、取消和确认导入通过。截图见 `app/build/android-p68-preset-actions.png` 和 `app/build/android-p68-import-confirmation.png`。
- 两份 APK 通过清单、架构、签名和 16 KiB 对齐检查。构建使用 `:app:assembleProfile -PlumacraftP68=true -Ptarget=lib/android_main.dart`，测试日志见 `app/build/android-p6.8-core-tests.log`。

## P6.9 组件属性补填与成片 EXIF

2026-11-11。Android 性能试用版 `0.20.1-p6.9`，版本号 79，最低 Android 12，沿用 P6.8 的应用 ID 与签名。Windows 本地试用版 `0.20.2+67`。

| 用途 | 产物 | SHA-256 |
| --- | --- | --- |
| ARM64 真机 | `app/dist/LumaCraft-Android-P6.9/LumaCraft-Android-P6.9-arm64-v8a-profile.apk` | `D6EF4376E60A2868FD085290A16EA95904F040B83CB915FA5339F7BF9F987F5D` |
| x86_64 模拟器 | `app/dist/LumaCraft-Android-P6.9/LumaCraft-Android-P6.9-x86_64-profile.apk` | `289BB99CFC25ACCD231628E3CE6D0C1BAB464E273314190777AB0C6207EE1BA7` |
| Windows x64 | `app/dist/LumaCraft-0.20.2-Beta-Preview/lumacraft.exe` | `871AABD6853E0324A63A6A271D9BC1459CC1ED0B9480A2A6A2774231E2E599E1` |

- 安卓预设操作菜单的图文间距为 10 dp，操作行间距为 12 dp。
- 两端可在对应组件属性中编辑当前照片的焦距、光圈、快门、ISO、相机型号、镜头型号、拍摄时间和地点。地点沿用手填和地图选点。补填数据随照片记录保存，清空覆盖值可恢复原始值。
- 导出开启「保留拍摄参数」时，补填字段直接编码进 JPG 和 PNG。地点文字使用 EXIF UserComment，精确 GPS 仍由独立开关决定。未补填的拍摄参数按原有保留策略处理。
- `flutter test --no-pub -j 1 test/export_pipeline_test.dart test/android_mobile_edits_test.dart test/editor_core_test.dart` 共 15 项通过。成片 EXIF 回读核对了补填值、未修改快门的原始精度及默认 GPS 移除，并逐字节比对原片。
- Windows 构建使用 `flutter build windows --release --no-pub --build-name=0.20.2 --build-number=67`。安卓构建使用 `:app:assembleProfile --offline -PlumacraftP69=true -Ptarget=lib/android_main.dart`，日志为 `app/build/android-p6.9-build.log`。两份 APK 通过清单、架构、签名和 16 KiB 对齐校验。完整交互待真机与桌面试用确认。
