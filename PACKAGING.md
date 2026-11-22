# 版本包使用说明

公开 ZIP 包含个人 skill、八款工具的公开快照、迁移说明、采集与打包程序。每份包都有格式版本、文件清单和逐文件 SHA-256。私人版可额外收录本人履历及本人选定的 IDE 原生导出。ZIP 本身不加密，私人版应保存在本人控制的位置。

## 下载和核对

取同一 Git 提交的 `dist/personal-skill-public.zip` 与 `dist/SHA256SUMS`，在 Windows 用 `Get-FileHash -Algorithm SHA256 <包路径>` 比对整包。包内 MANIFEST.json 用于逐文件核对。校验值的可信度取决于取得它的仓库及提交。

## 从源文件构建

从仓库根目录运行，打包工具只需要 Python 3.11+。首次使用可以直接下载 ZIP。

```powershell
python tools/bundle.py build --output dist/personal-skill-public.zip
python tools/bundle.py verify dist/personal-skill-public.zip
```

私人版接收仓库外的 UTF-8 Markdown 档案，可选附上各款 IDE 的原生设置导出。每款 IDE 最多一份。示例中的 `../private` 位于仓库同级。项目依赖、运行入口及机器专有设置的迁移方法见 MIGRATION.md。

```powershell
python tools/bundle.py build --profile ../private/profile.md --output ../private/personal-skill-private.zip
python tools/bundle.py build --profile ../private/profile.md --settings clion=../private/clion.zip --settings vscode=../private/editor.code-profile --output ../private/personal-skill-with-settings.zip
python tools/bundle.py verify ../private/personal-skill-private.zip
```

CLion、PyCharm、IntelliJ IDEA 使用各 IDE 导出的 ZIP，对应参数 clion、pycharm、idea。VS Code 使用 vscode 和 .code-profile。附入的原生设置由本人在目标 IDE 选择性导入。账号和模型服务在目标设备上重新授权。

## 更新与使用

公开快照或源文件变化时重新打包，记录新 ZIP 的 SHA-256，核对同一 Git 提交中的源文件、ZIP 和校验值。公开构建始终只取程序列出的公开文件。私人材料只在指定输入时加入私人版。首版源码、设置覆盖范围和用户决定保留在 Git 历史中。打包与文件校验不启动 IDE、不执行恢复演练。

显式启用个人 skill 后，私人版可按任务需要读取本人档案。简历中的研究兴趣、已完成项目和在学技能分别记录，涉及对外介绍时按本次指示选择材料。
