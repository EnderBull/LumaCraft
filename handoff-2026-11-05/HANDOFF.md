# LumaCraft 工程交接总入口

**开发已由用户要求暂停；交接不代表获准继续开发。无 Git 锚点。**

| 项目 | 冻结事实 |
|---|---|
| 工程根目录 | `D:/AI Agent/LumaCraft` |
| 当前分支 / HEAD commit | 不存在 / 不存在（非 Git 仓库） |
| 交接文档生成时间 | 2026-11-05T14:54:35+08:00 |
| 代码检查后冻结时间 | 2026-11-05T14:48:47.059736+08:00 |
| 当前源码版本 | `app/pubspec.yaml`：0.8.0+31 |
| 本次可重复实现状态锚点 | SHA-256 `7b053958c9de563e30bee918217501f59762490892efd0ce6da9218617b6922f`，149个关键源码/资源文件 |
| 权威逐文件绑定 | `evidence/source-files.json`；全工程见`evidence/PROJECT_SNAPSHOT.jsonl` |
| 最新已交付软件 | `D:/AI Agent/LumaCraft/app/dist/LumaCraft-0.8.0-Authoring/lumacraft.exe` |

当前目录及app都执行过`git rev-parse`，非仓库。Flutter SDK自身的版本commit不是本项目HEAD。软件版本号不是源码提交锚点，不能凭版本号还原历史源码。

## 目标、理念、范围

软件名：框印工坊 / LumaCraft。面向摄影照片的本地边框、水印和自由排版工具。优先Windows专业桌面操作；目录直浏览，不依赖导入照片库；预设可编辑、可复用、离线分享，批量导出保留原照片。UI以根目录AGENTS.md的稳定偏好和已确认浏览器原型为依据，新增功能同样重视文字清晰度、留白、控件一致性及Adobe式直接操作。

首版产品规划包括Windows及后续Android轻量编辑。当前实际验证平台为Windows x64；Android只有模板工程，不能视为已有可交付移动版。未来macOS/iOS、英文、HDR/广色域属于后续规划。

明确不做：本轮不开发、不修历史脚本、不安装Android SDK、不升级依赖、不初始化或上传Git、不清理删除文件、不改写用户原图；当前不是完整RAW显影/调色软件，不把浏览器原型当正式程序，不声称HEIC/HDR及所有相机/显示器已兼容。高德、二维码、移动后照片重新关联尚未发现实现入口。

## 接手阅读顺序

1. 根目录`AGENTS.md` → 本文 → `STATE.md` → `TEST_BASELINE.md`。
2. `DEVLOG.md`、`ADR/`；详细版本记录仍在`app/docs/`。
3. 根目录产品设计方案是规划，遇到与实现冲突，以代码/当前测试为准，冲突见STATE。

所有本文相对路径以`D:/AI Agent/LumaCraft/handoff-2026-11-05`为基准；`app/...`明确表示工程根目录下的app。备份副本中保留同样层级，可整体迁移后调整根路径。

## 当前能运行的功能及证据

| 功能 | 代码 | 本次可复现证据 |
|---|---|---|
| Windows无边框窗口、目录树、多目录/子目录、Ctrl/Shift选择、照片预览及平滑滚动 | app/lib/main.dart、directory_browser.dart、ui/、windows/runner/flutter_window.cpp | flutter-tests.log中的browse_controls与editor_core；windows-authoring-build.log |
| 组件、图层/分组、拖排/框选、吸附/对齐、撤销重做、锚点换算、Alt滚轮和空格拖动 | app/lib/editor/editor_controller.dart、style_document.dart、ui/editor/ | flutter-tests.log中editor_core、layout_adaptation等 |
| 色卡、图片标识、纯色/渐变/照片模糊背景、胶片打孔、投影、HSB取色 | app/lib/editor/*_render.dart、*_style.dart、ui/editor/ | flutter-tests.log中palette_core、image_background、hsb_picker、number_drag |
| 预设收藏/分组/多选管理及.lmp离线分享 | app/lib/editor/preset_store.dart、preset_package.dart、ui/preset_* | flutter-tests.log中preset_library |
| EXIF读取补填、批量导出命名/尺寸、冲突决策、取消及失败重试 | app/lib/photo_state.dart、export/、main.dart、render.dart | flutter-tests.log中export_workspace_flow、export_pipeline |
| 实际sRGB转换及JPG/PNG ICC嵌入、EXIF/GPS策略 | app/windows/runner/color_tool.cpp、lib/export/color_management.dart | export_pipeline：源配置像素变化和ICC读回；编译含色彩工具 |
| 8款内置字体、三款横竖样式、制作版内置库维护 | app/lib/fonts/、editor/builtin_library.dart、assets/、ui/builtin_* | flutter-tests.log中builtin_fonts及preview-builtins.log |

本轮`flutter test --no-pub --reporter expanded`30项通过；两项额外预览各1项通过；Windows制作版构建通过。完整命令、退出码、环境和原始输出见TEST_BASELINE及evidence，不能将这些结果等同于所有真实照片和全部系统缩放测试。

本次重建的主EXE、色彩工具、Flutter DLL、data/app.so和内置库资源，与0.8.0交付目录对应文件SHA-256一致，见`evidence/rebuild-vs-delivery.json`。

## 不能运行 / 未完成 / 受阻

- Android SDK未安装，实际色彩导出明确仅支持Windows；Android模板仍为`com.example.lumacraft`及debug签名配置。不能发布。
- 历史`app/test/core/check.dart`以普通Dart VM运行失败：Flutter依赖/dart:ui不可用；已由现有Flutter测试覆盖当前主流程，历史脚本未迁移。
- 分析配置引用未声明的flutter_lints，专门检查有1条warning；`dart analyze lib test`通过不等于配置完整。
- “手机经典”只是空分组，未制作各品牌样式、未核实联名/Logo素材分发条件。Futura已取消，不得重新悄悄加入。
- HEIC/HDR专项、Android跨端一致性、照片移动重新关联、地理服务、二维码、崩溃后导出任务恢复：未完成/待后续方案。
- 无Git，历史变更归属及误改判断受阻：无可信旧源码基线；不要编造“干净工作树”。

## 进行中及下一步

交接完成后保持暂停。下一项开发原计划为手机品牌经典边框参考整理和视觉确认，再制作样式；此前需用户明确恢复开发。新的Agent先核对快照，不要因计划中的勾选将尚未制作的品牌预设当成完成。

新Agent接手后的前3件事：
1. 阅读约束、交接和测试基线，运行`python handoff-2026-11-05/tools/verify_snapshot.py --scope source`；不先运行会改写状态的命令。
2. 确认使用0.8.0制作版还是发行构建；确认用户维护库的位置。需要运行测试时先按ENVIRONMENT模板隔离数据，不接触app/local真实记录。
3. 向用户说明已核实状态及未完成清单，确认何时恢复、下一阶段范围；再另行讨论是否初始化Git及远程目标。

## 禁止与人工审批

根目录AGENTS.md持续适用。任何文件删除都必须单独列出文件和原因取得确认；不能用clean、递归删除、覆盖式同步或“旧缓存”理由绕过。不得覆盖旧交付目录、批量升级SDK/锁文件，或修改原图。新增开发范围/文件改动先列计划确认；初始化Git、建立远程及上传工程需另行授权。工程及备份包含本地绝对路径、EXIF补填及用户预设，不能未经授权公开上传。

## 备份与完整性

完整副本目标：`D:/AI Agent/LumaCraft/backup-2026-11-05/project/`，包含工程原有源码、工具链、缓存、历史dist、编译软件及本套交接材料。仅排除备份目录自身，防止递归。普通文件逐一SHA-256核对；唯一插件目录链接重建到备份内pub-cache，不继续指向原工程。空目录保留。

最终复制/校验的权威结果为`D:/AI Agent/LumaCraft/backup-2026-11-05/BACKUP_REPORT.json`，报告不存在或verified不为true时，不得宣称备份可用。并非磁盘镜像：不包含项目目录外的原照片、系统字体、Windows标准ICC、Visual Studio/Android安装及系统环境，也不承诺复制NTFS ACL/ADS等非文件内容元数据。外部原照片仍需用户自行另备。

## 等待用户确认（不阻塞当前交接）

- 后续何时恢复开发、是否先做手机品牌样式。
- 是否初始化Git，以及远程服务/私有性/需要纳管的目录；本轮没有执行。
- 将来发行封包前，用户修改的内置工作库是否为最终稿；迁移时是否携带项目外照片。
