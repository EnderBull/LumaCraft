# LumaCraft 应用图标

当前版本按已确认的青蓝色光影画框样式矢量重绘。白色闭合圆角画框、渐变山形、暖色太阳、背景晕影及右下长阴影均由 SVG 定义。外侧为干净的透明区域。

- lumacraft-icon.svg 为可编辑源文件，1280×1280 viewBox。
- lumacraft-icon-1024.png 为 1024×1024 透明 PNG。
- lumacraft.ico 含 16、24、32、48、64、128、256 px 七档图像。
- Windows 工程使用 windows/runner/resources/app_icon.ico。
- Android 工程使用 android/app/src/main/res/mipmap-*/ic_launcher.png，分别为 48、72、96、144、192 px。

重新生成时运行 build-icons.cjs。脚本依赖 sharp，本次使用 Codex 自带的 Node 库，通过 NODE_PATH 指向依赖目录。此工具仅用于素材构建，应用运行不依赖它。修改 SVG 后重新运行会更新平台图标。

本次替换 Android 的现有 PNG 启动图标。Android APK 和设备实际显示待对应开发阶段验证。
Windows Release 构建通过，新的 ICO 已包含在构建产物中。已检查 PNG 尺寸、ICO 七档索引和透明区域。
长阴影边界已修正为圆角的 45° 切线，投影位移为 (320,320)，与相框外轮廓相切。
