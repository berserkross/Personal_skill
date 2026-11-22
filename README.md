# 个人工作方式与开发环境迁移包(自用)

v0.1 · Windows · 2026-11-22

本仓库同时维护两种会独立变化的内容：本人确认过的工作方式，以及本机 AI 和开发工具可公开的配置。Git 提交记录两者的变化。

| 内容 | 入口 |
|---|---|
| 显式启用的个人偏好 | [SKILL.md](skills/personal-workstyle/SKILL.md) |
| 首次公开配置快照 | [windows.json](snapshots/windows.json) |
| 重新采集允许公开的字段 | [Export-PublicConfig.ps1](tools/Export-PublicConfig.ps1) |
| 八款工具的迁移步骤、覆盖范围与更新方法 | [迁移与维护](MIGRATION.md) |

在本机以 PowerShell 7.3+ 从仓库根目录运行：

```powershell
pwsh -NoProfile -File ./tools/Export-PublicConfig.ps1
git diff -- snapshots/windows.json
```

导出器只写仓库中的快照，运行前先读取必要的源配置；源文件缺失或无法解析时以失败退出并保留上一版。可选 Profile、SDK 或扩展清单的可见程度在快照中标注。快照只包含脚本显式选择的字段。完整的私人恢复材料由本人保管。首版未进行恢复实测、个人偏好盲评或宿主安装。
