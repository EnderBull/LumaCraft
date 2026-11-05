# ADR-001 · Flutter与桌面优先

状态：按当前代码及保留记录重建，2026-11-05。历史缺少决策证据的部分明确标注，不臆造。

## 背景

产品需要Windows与后续Android共用排版，桌面又需要自由画布和专业操作。

## 决策

采用Flutter；当前交付Windows x64，Android另行适配。

## 被否决/未采用的备选与证据边界

产品方案明确比较过Qt/QML和Tauri，取舍是手机体验与跨端界面复用；没有把Android模板当成已完成跨端。

## 代价与影响

需要自行处理Windows窗口、原生解码/色彩，不能假设Flutter层自动解决全部平台一致性。

## 影响文件/核实入口

app/pubspec.yaml；app/lib/main.dart；app/windows/runner/；根产品方案§15。
