# LumaCraft 环境变量模板
#
# 用法：在 PowerShell 里执行本文件（或在会话开始时逐条粘贴）。
# 这些变量只影响当前终端会话，不写入系统环境。
#
# 注意：
#   * LUMACRAFT_DATA_DIR 的路径必须包含 "export-ui-check"，这是测试里的保险，
#     防止误用真实数据目录、覆盖用户的预设和照片记录。
#   * 每次跑测试请换一个新的目录，不要复用上一次的，否则残留记录会导致误报。

# 依赖缓存必须在项目内，否则可能用到全局缓存导致版本错乱
$env:PUB_CACHE = "D:\AI Agent\LumaCraft\app\.toolchain\pub-cache"

# 测试用的独立数据目录（每次运行换一个新的）
$env:LUMACRAFT_DATA_DIR = "D:\AI Agent\LumaCraft\app\build\export-ui-check-0000-template"

# 原生色彩工具（导出与广色域预览需要）
$env:LUMACRAFT_COLOR_TOOL = "D:\AI Agent\LumaCraft\app\build\windows\x64\runner\Release\lumacraft_color_tool.exe"

# 如需构建制作版（显示内置预设维护等开发入口），构建命令里加：
#   --dart-define=LUMACRAFT_AUTHORING=true
# 发行版不加这个参数。这是编译期开关，不是环境变量。

Write-Host "LumaCraft 环境变量已设置" -ForegroundColor Green
Write-Host "  PUB_CACHE          = $env:PUB_CACHE"
Write-Host "  LUMACRAFT_DATA_DIR = $env:LUMACRAFT_DATA_DIR"
Write-Host "  LUMACRAFT_COLOR_TOOL = $env:LUMACRAFT_COLOR_TOOL"
