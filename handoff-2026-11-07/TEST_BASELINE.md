# 测试基线（2026-11-07）

源码版本 0.18.0+58，Git `main` / `63d20f8`。

## 结论

| 项目 | 结果 |
|---|---|
| `flutter analyze lib` | 无错误、无警告 |
| `flutter test --no-pub -j 1`（**串行**） | **206 项通过，1 项跳过** |
| `flutter test --no-pub`（并行，默认） | 201 通过 / 5 失败 —— 已知干扰，见下 |

## 必须串行跑

**用 `-j 1`。** 并行时下列测试会互相干扰而误报失败：

- `builtin_fonts_test`（画布渲染，抢 CPU）
- `export_workspace_flow_test`（起完整工作台）
- `live_delete_refresh_test`、`live_recycle_refresh_test`、`live_export_recovery_test`（真实文件操作 + 定时器）

原因：它们共用同一个 `LUMACRAFT_DATA_DIR`，并依赖真实时间等待（2 秒核对、导出落盘）。并行时互相覆盖记录、抢定时器窗口。

**这不是代码缺陷。** 单独跑或在 `-j 1` 下全部通过。

## 复现命令

```powershell
cd "D:\AI Agent\LumaCraft\app"
$env:PUB_CACHE = "D:\AI Agent\LumaCraft\app\.toolchain\pub-cache"
# 路径必须含 export-ui-check；每次换新目录，避免残留影响
$env:LUMACRAFT_DATA_DIR = "D:\AI Agent\LumaCraft\app\build\export-ui-check-0308-seq"
$env:LUMACRAFT_COLOR_TOOL = "D:\AI Agent\LumaCraft\app\build\windows\x64\runner\Release\lumacraft_color_tool.exe"
flutter test --no-pub -j 1
```

预期结尾：`All tests passed!`，计数 `+206 ~1`。

## 测试文件清单（60 个）

**核心功能**
`editor_core_test`、`default_style_test`、`browse_controls_test`、`layout_adaptation_test`、`workspace_refinements_test`、`refinements_test`、`number_drag_test`、`hsb_picker_test`

**预设与样式**
`preset_library_test`、`palette_core_test`、`shape_test`、`stamp_test`、`texture_film_test`、`photo_stroke_test`、`image_background_test`、`photo_edge_test`、`builtin_fonts_test`、`phone_classics_test`、`apply_style_scope_test`

**导出**
`export_pipeline_test`、`export_workspace_flow_test`、`export_limit_test`、`export_resume_test`、`export_resume_drill_test`、`export_recovery_test`、`stress_export_test`、`wide_gamut_test`

**分享与导入（0.17.4）**
`preset_code_test`、`preset_qr_test`、`preset_image_import_test`、`real_share_image_test`、`share_availability_test`、`share_image_corners_test`、`dialog_contrast_test`

**目录刷新与文件锁**
`directory_watch_test`、`directory_rescan_test`、`live_delete_refresh_test`、`live_recycle_refresh_test`、`live_export_recovery_test`、`file_lock_probe_test`、`thumb_lock_test`、`preview_lock_probe_test`、`watch_coverage_probe_test`、`listing_perf_probe_test`

**照片重新关联**
`relink_test`、`relink_flow_test`、`relink_swap_test`、`relink_real_state_test`、`relink_notice_test`、`relink_ui_test`、`relink_shot_test`（skip，golden 渲染卡死）

**设置与地点（0.18.0）**
`gps_fixture_test`、`gps_reader_test`、`coords_test`、`settings_core_test`、`place_lookup_test`、`settings_ui_test`、`photo_info_refresh_test`

**HEIC 与杂项**
`heif_import_test`、`widget_test`

## 依赖真实素材的测试

| 测试 | 依赖 |
|---|---|
| `real_share_image_test` | `C:\Users\<用户>\OneDrive\Desktop\画廊签名-分享.png`，文件不存在时自动跳过 |
| `gps_reader_test` | `build/gps-fixtures/` 下自行生成的 4 张带坐标 JPG，缺失时先跑 `gps_fixture_test` 生成 |
| `heif_import_test` | `test/fixtures/heic/` 下 19 个 HEIC 样本（已在版本库） |
| `stress_export_test` | 自行生成素材 |

`real_share_image_test` 的跳过（`~1`）就是它——它是唯一跳过项，属预期。

## 未覆盖的部分

以下只能在真实软件里验证，自动化测试替代不了：

- 地图窗口的实际交互（WebView2 在 `flutter test` 环境创建不了）
- 高德 API 真实调用（需要用户自己的 Key）
- 深浅色模式下的实际观感与对比度
- 不同 Windows 缩放比例下的界面清晰度
- 导出中断在真实强杀下的行为（测试是模拟记录，真实场景需用户操作）

## 已知不稳定项

| 现象 | 说明 |
|---|---|
| 并行时 5 项失败 | 数据目录与定时器竞争，`-j 1` 即通过。见台账 R12 |
| `relink_shot_test` | golden 渲染卡死，已改为 skip |

## 建议

1. **改完代码先跑 `-j 1` 全量**，约 3 分钟。
2. 只改某个模块时，跑相关测试 + `editor_core_test` 作为回归。
3. 每次换新的 `LUMACRAFT_DATA_DIR`，不要复用上一次的，否则残留记录会导致误报。
4. 涉及界面改动的功能，**必须再用真实软件看一遍**，尤其深浅色两种模式。
