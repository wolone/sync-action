# Repo mirror workflow

此仓库包含一个 GitHub Actions 工作流和一个同步脚本，用于将下列源仓库的所有分支和标签镜像到目标仓库：

- https://github.com/frappe/frappe -> https://cnb.cool/frappecn/frappe
- https://github.com/frappe/hrms   -> https://cnb.cool/frappecn/hrms
- https://github.com/frappe/crm    -> https://cnb.cool/frappecn/crm
 - https://github.com/frappe/erpnext -> https://cnb.cool/frappecn/erpnext

使用说明
- 目标用户名固定为 `cnb`，在仓库 Settings -> Secrets 中添加 Secret：`CNB_TOKEN`（用于 HTTP 推送认证）。
- 手动触发：在 Actions 面板选择 `Mirror Frappe Repos`，点击 `Run workflow`。
- 工作流也会按计划每日运行（UTC 03:00）。

脚本说明
-- 脚本路径：`scripts/sync_repos.sh`。
- 脚本使用 `git clone --bare` 拉取源仓库（非 mirror 模式），并使用 `git push --all` 与 `git push --tags` 推送到目标仓库。
	脚本在推送后会对目标仓库执行清理：删除那些在源仓库已不存在的分支（请谨慎）。

注意
-- 目标 Git 服务需要允许使用用户名+token 的 HTTP 推送方式；用户名固定为 `cnb`，token 存储在 `CNB_TOKEN` Secret 中。
	如果需要使用 SSH，请改造脚本和工作流以使用私钥。

示例（本地运行）：
```bash
export CNB_TOKEN=your_token_here
./scripts/sync_repos.sh
```

示例（使用自定义映射文件）：
```bash
export CNB_TOKEN=your_token_here
./scripts/sync_repos.sh path/to/my_mappings.txt
```
