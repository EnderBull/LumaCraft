# STATE · 冻结状态

无 Git 锚点。冻结时间：2026-11-05T14:48:47.059736+08:00；文档生成时间：2026-11-05T14:54:35+08:00。
实现/资源锚点：`7b053958c9de563e30bee918217501f59762490892efd0ce6da9218617b6922f`。关键源码清单见evidence/source-files.json；整工程内容冻结和链接定义见PROJECT_SNAPSHOT.jsonl、after-links.json。完整备份的副本校验结果见根目录backup-2026-11-05/BACKUP_REPORT.json。

## 目录与职责

```text
D:/AI Agent/LumaCraft/
  AGENTS.md                         通用执行约束及稳定UI偏好
  框印工坊-LumaCraft-产品设计方案.md   产品规划，不是现状承诺
  初步预设样式.png                   01—06风格参考，非可分发素材证明
  app/
    lib/main.dart                   工作台入口及导出/模式连接
    lib/editor/                     文档模型、控制器、渲染、预设库/.lmp
    lib/fonts/                      内置字体目录及兼容键
    lib/export/                     任务/命名/偏好/原生色彩通信
    lib/ui/                         共用控件、浏览/编辑界面
    windows/runner/                 无边框窗口及WIC色彩工具
    android/                        未完成发布的模板工程
    assets/fonts/                   字体、OFL、来源及哈希
    assets/builtins/library.json     3款预设；手机经典分组为空
    ui-prototype/                   HTML/JS/CSS交互原型、截图及设计记录
    test/                           当前Flutter测试及历史core脚本/产物
    docs/                           版本交付说明、计划与验证历史
    tools/                          字体获取、发行库资源准备脚本
    local/                          开发期JSON记录，有用户路径/预设内容
    dist/                           30个历史可运行目录，最新0.8.0-Authoring
    build/                          生成二进制、日志、临时预览测试与截图
    .dart_tool/                     生成配置、绝对路径和编译缓存
    .toolchain/                     Flutter/Dart SDK、pub-cache及构建依赖
  handoff-2026-11-05/                本套交接与证据
  backup-2026-11-05/project/          独立备份，排除其自身防止递归
```

目录索引完整见evidence/after-dirs.json，完整文件列表见after-files.json（含字节数及mtime）；人工简图见DIRECTORY_TREE.txt。普通项目文件38385个，约7.335GiB；此统计不含随后生成的交接文件和备份目录，也不重复展开插件链接。链接1个，目标在本工程pub-cache内。

## 当前命令与最近结果

- 分析：app目录`& .toolchain/flutter/bin/cache/dart-sdk/bin/dart.exe analyze lib test`，退出0。
- 测试：app目录`& .toolchain/flutter/bin/flutter.bat test --no-pub --reporter expanded`，30项通过，必须先隔离LUMACRAFT_DATA_DIR。
- 构建：app目录`& .toolchain/flutter/bin/flutter.bat build windows --release --no-pub --dart-define=LUMACRAFT_AUTHORING=true`，成功。
- 运行：完整`app/dist/LumaCraft-0.8.0-Authoring`目录中的lumacraft.exe。必须保留色彩工具、DLL和data，不能只拷主EXE。
- 如需受管理导出，原生WIC工具在测试前必须已构建或显式指定环境变量。完整绝对命令、工作目录、退出码、失败及跳过见TEST_BASELINE，那里优先于这里的简写。

## 依赖与锁文件

Flutter 3.47.9 / Dart 3.13.7，SDK要求以实际锁文件为准：Dart >=3.13.0 <4.0.0、Flutter >=3.47.0；pubspec写较低下限不代表当前依赖能在旧SDK工作。直接依赖当前锁定：

| 依赖 | 锁定版本 |
|---|---|
| file_selector | 1.1.0 |
| flutter | 0.0.0 |
| flutter_svg | 2.3.2 |
| flutter_test | 0.0.0 |
| image | 4.12.0 |

完整传递依赖见evidence/dependencies.json及app/pubspec.lock。还有历史app/test/core/pubspec.lock；它不是主Flutter工程依赖。检查前后两个锁文件SHA-256未变。本次未执行pub upgrade。

分析配置有已知不一致：include flutter_lints，而dev_dependencies只有flutter_test，配置专项检查warning。不能把历史“代码分析无问题”扩展为所有配置无warning。

## 环境与生成文件

本工程原先没有发现.env模板，现新增交接模板ENVIRONMENT.template.ps1；只列已在代码使用的变量，不包含密钥。

- PUB_CACHE：项目内依赖缓存；不设置时可能错误使用全局缓存。
- LUMACRAFT_DATA_DIR：JSON记录目录。测试路径必须包含export-ui-check；未设置时从可执行文件向上找pubspec.yaml，找到则用该工程app/local，否则可执行文件旁local。注意dist目录位于app内部，不能想当然认为每个dist都有独立local。
- LUMACRAFT_COLOR_TOOL：原生exe可选路径；否则优先找主可执行文件旁，再找相对build/windows/x64/runner/Release。不能在任意cwd假定找到它。
- 编译期LUMACRAFT_AUTHORING默认false；本次软件true。LUMACRAFT_BUILTIN_ASSET默认assets/builtins/library.json。二者与运行时环境变量不是一回事。
- SDK不在系统PATH，本轮用绝对路径；doctor未找到Android SDK，且maven.google.com检查超时。

迁移后需重新生成的内容：.dart_tool/package_config.json、.flutter-plugins-dependencies、windows/flutter/ephemeral及插件链接、CMake构建树、构建缓存。它们含原目录的绝对路径。先核对现有锁文件，再在新位置使用项目工具链`flutter pub get --offline --enforce-lockfile`（本轮未执行该重生成命令），随后Windows构建；若缓存不足应明确报错，勿擅自升级锁文件。Flutter生成过程可能替换生成文件，仍受根目录禁止删除规则约束，需要清理时先申请具体范围。

备份将插件链接重定向到备份内pub-cache；移动整个备份后仍应由Flutter重新生成链接，不直接依赖绝对路径链接。

## 数据库/迁移与本地状态

未发现SQL/SQLite依赖、数据库文件或迁移目录；当前不是“数据库已迁移”，而是本地版本化JSON方案。photo-state.json保存逐照片状态/手工补充，workspace.json保存界面与目录状态，editor-presets.json保存用户预设与草稿，export-settings.json保存导出偏好，builtin-working.json仅制作版读取。存在与否取决于使用过程，真实文件汇总在evidence/local-data-summary.json。

主记录schema version为1；遇未知版本多处直接拒绝，未发现通用数据迁移框架。记录按完整路径关联照片，搬动照片后的重新关联未做。原图不内嵌于这些记录；图片标识等素材可内嵌样式。写入使用.pending再rename，备份中保留已有暂存文件，不自动清理。

## 未提交、未跟踪、临时与误改

| 项目 | 可证实状态 |
|---|---|
| 未提交改动 | 无Git，无法与HEAD比较；不是“零改动” |
| 未跟踪文件 | 无Git索引，不能声称某些文件已跟踪或未跟踪 |
| 被误改文件 | 没有可信初始源码基线，无法判定历史误改；未确认具体误改文件 |
| 本次检查产生变化 | check-file-delta.json逐项列出新增、缺失及mtime/大小变化；mtime变化不等于内容变化 |
| 本次关键内容变化 | before/after关键哈希共同文件内容无变化；不修改产品源码 |
| 临时调试文件 | temporary-debug-files.json分类列全日志、测试样片、预览脚本/截图、IDE配置及.pending |

本次新增{len(delta['added'])}个项目内生成文件、删除{len(delta['removed'])}个、{len(delta['metadata_changed'])}个元数据发生变化；交接目录另列。不把临时文件当垃圾删除。尤其build/export-preview/preview_test.dart、build/builtin-preview/preview_test.dart实际承载额外验证，贸然删build会丢测试入口。历史app/ui-prototype/*.py为修改原型的脚本，不应盲跑到新代码。

## 文档与代码冲突/阶段差异

- 产品方案仍有“具体图片库/本地存储/原生语言未锁定”的历史段落；实际已采用image、JSON及Windows C++ WIC。
- 早期technical-validation章节写目录树、更多预设/编辑器尚待完成；后续版本已有实现，不能只读文件开头。
- 早期方案和图示不足以证明已完成6款或手机品牌复刻；实际内置JSON为gallery、travel、film三款，phone空分组，预设总数不限制6。
- README与Android工程保留生成模板；Android release仍debug签名，不能当正式发布配置。
- 旧版本二进制都保留，但没有各版本源码commit；DEVLOG只能按历史文档和当前产物引用，不承诺能重建每个历史版本。
- 当前重建5个关键产物与0.8.0交付对应文件哈希一致；这是本轮验证结论，不推断其它旧版本。

## 任务看板

| 任务 | 状态 | 证据 | 阻塞点 | 下一步 |
|---|---|---|---|---|
| Windows核心工作台/编辑/导出 | 当前核心基线通过 | flutter-tests.log、Windows构建日志 | 真实照片专项仍有限 | 保持暂停，用户决定恢复 |
| 字体及三款预设、制作入口 | 当前实现/验证通过 | builtin_fonts_test.dart、preview-builtins.log、library.json | 用户最终视觉稿尚可继续调整 | 用户在制作版修改并导出 |
| 手机经典各品牌样式 | 待做，仅空分组 | library.json | 具体年代/机型样式及素材来源未确认 | 先收集参考与视觉方案 |
| 分析配置/历史core脚本 | 已知技术欠项，未修 | analyzer-config.log、legacy-check-direct.log | 当前SDK及Flutter依赖 | 获准后局部修复/迁移 |
| Android/跨端导出 | 未实现交付 | doctor、Android模板、color_management.dart | SDK缺失、WIC仅Windows | 单独设计与授权开发 |
| HEIC/HDR/真实广色域专项 | 未完成验证 | windows-export-0.7.0.md限制 | 样片/设备与解码方案 | 另行确定验证范围 |
| Git纳管 | 未执行 | git-project.log | 未获初始化/远程授权 | 用户决定 |
| 工程完整备份 | 以独立报告为准 | backup-2026-11-05/BACKUP_REPORT.json | 若报告未通过则不可认定完成 | 按报告验证，勿覆盖源 |


## 本轮备份补记

普通工程文件38385个已逐文件复制并读回SHA-256核对。首次在重建插件junction时因权限不足失败，子进程错误输出又遇到GBK解码问题，未标记成功。已保留backup-2026-11-05/BACKUP_ERROR.json；仅将脚本错误解码改为UTF-8容错，并使用获准的权限补建唯一链接，未删除/重做已有副本。最终完成状态以BACKUP_REPORT.json为准。此处修改仅交接工具，不涉及产品源码。
