# ADR-002 · 版本化JSON、本地路径关联与串行写入

状态：按当前代码及保留记录重建，2026-11-05。历史缺少决策证据的部分明确标注，不臆造。

## 背景

需要照片补填、用户预设、草稿、UI与导出偏好本地恢复，当前无SQL依赖。

## 决策

按职责分JSON，schema version=1；串行写.pending后rename；照片键为完整路径。

## 被否决/未采用的备选与证据边界

当前记录未发现SQL/ORM迁移方案的正式否决过程；不能补写成“性能比较后否决SQLite”。

## 代价与影响

本地记录随路径变化失联；无通用迁移框架；中断可能留.pending，不能擅自清理。

## 影响文件/核实入口

app/lib/photo_state.dart；workspace_settings.dart；editor/preset_store.dart；export/export_preferences.dart。
