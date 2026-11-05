# 模板，不含密钥。先阅读STATE.md；不要盲目执行测试。
# 当前工程目录；若复制/迁移，请修改此值。
$projectRoot='D:\AI Agent\LumaCraft'
$appRoot=Join-Path $projectRoot 'app'
$env:PUB_CACHE=Join-Path $appRoot '.toolchain/pub-cache'
# 测试必须隔离，export_workspace_flow_test要求路径包含export-ui-check。
$env:LUMACRAFT_DATA_DIR=Join-Path $appRoot 'build/export-ui-check-handoff-next'
$env:LUMACRAFT_COLOR_TOOL=Join-Path $appRoot 'build/windows/x64/runner/Release/lumacraft_color_tool.exe'
# 下列为编译参数，不是PowerShell环境变量：
# --dart-define=LUMACRAFT_AUTHORING=true          制作版；默认false为发行版
# --dart-define=LUMACRAFT_BUILTIN_ASSET=assets/builtins/library.json
# JAVA_HOME / ANDROID_SDK_ROOT 未配置；Android当前不可作为已验证目标。
