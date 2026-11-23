# AI 与其他工具的使用方法及开发环境迁移包(自用)

v0.5.0 · Windows · 2026-11-22

本仓库记录我怎样选择、组合和验证 AI 与其他工具，并备份可公开的配置，方便换模型或换机器后继续工作。v0.5.0 收录长期项目的分工、重要文件的紧急抢修、课前到临考的学习安排、文档写作与代码评审的具体做法，以及一次跨模型写作实例，并新增适用范围条款：四类任务之外按通用最佳实践回答，不套用本文件的流程。学籍资料仅提供背景。

| 内容 | 入口 |
|---|---|
| 可直接下载的公开版 ZIP | [下载版本包](https://github.com/berserkross/Personal_skill/raw/refs/heads/main/dist/personal-skill-public.zip) · [SHA-256](dist/SHA256SUMS) |
| 构建、校验与私人版 | [打包说明](PACKAGING.md) |
| 已确认的工具用法与适用场景 | [SKILL.md](skills/personal-workstyle/SKILL.md) |
| 首次公开配置快照 | [windows.json](snapshots/windows.json) |
| 重新采集允许公开的字段 | [Export-PublicConfig.ps1](tools/Export-PublicConfig.ps1) |
| 八款工具的迁移步骤、覆盖范围与更新方法 | [迁移与维护](MIGRATION.md) |

本机导出快照需要 Python 3.11+ 和 PowerShell 7.3+。从仓库根目录运行：

```powershell
pwsh -NoProfile -File ./tools/Export-PublicConfig.ps1
git diff -- snapshots/windows.json
```

导出器只写仓库中的快照，运行前先读取必要的源配置；源文件缺失或无法解析时以失败退出并保留上一版。可选 Profile、SDK 或扩展清单的可见程度在快照中标注。快照只包含脚本显式选择的字段。完整的私人恢复材料由本人保管。恢复实测仍未进行；个人偏好盲评已完成两轮（8/8 规则复现、3/10 泛化失败），v0.5.0 据此新增适用范围条款。宿主安装未执行。
