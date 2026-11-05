# 交接材料索引

先读[HANDOFF.md](HANDOFF.md)，当前为**无Git锚点、开发暂停**。

- [STATE.md](STATE.md)：当前结构、配置、数据与任务状态。
- [DEVLOG.md](DEVLOG.md)：保留证据支持的版本索引、否决方案及风险。
- [TEST_BASELINE.md](TEST_BASELINE.md)：本轮完整命令、环境、退出码与输出链接。
- [ADR/README.md](ADR/README.md)：11份决策记录。
- [ENVIRONMENT.template.ps1](ENVIRONMENT.template.ps1)：不含密钥的变量模板。
- evidence/：全目录清单、哈希、前后差异、完整日志、锁定依赖与环境汇总。
- tools/：只读核验、目录盘点、基线执行及新目录备份工具。

只读核验（工程根目录）：

```powershell
python handoff-2026-11-05/tools/verify_snapshot.py --scope source
python handoff-2026-11-05/tools/verify_snapshot.py --scope project
python handoff-2026-11-05/tools/verify_snapshot.py --scope handoff
```

全工程快照不含交接目录，避免清单自引用；交接文件由单独HANDOFF_HASHES.json绑定，该清单自身SHA-256保存在独立备份报告。文件链路见HANDOFF的备份说明。

独立备份：D:/AI Agent/LumaCraft/backup-2026-11-05/project。
最终完整性结论仅认D:/AI Agent/LumaCraft/backup-2026-11-05/BACKUP_REPORT.json中的verified=true。未取得该报告不能声称备份完成。
