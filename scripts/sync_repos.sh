#!/usr/bin/env bash
set -euo pipefail


# 默认值
DEFAULT_SRC_HOST="https://github.com/frappe"

# 目标用户名固定为 cnb，token 从环境变量 CNB_TOKEN 获取
DEFAULT_DST_HOST_BASE_TEMPLATE="https://%s@cnb.cool/frappecn"

if [ -z "${CNB_TOKEN:-}" ]; then
  echo "错误：必须设置环境变量或 GitHub Secret：CNB_TOKEN"
  exit 1
fi

# 构建目标主机基础 URL，用户名固定为 cnb，密码使用 CNB_TOKEN
DST_HOST_BASE="https://cnb:${CNB_TOKEN}@cnb.cool/frappecn"

# 读取映射文件：第一个命令行参数会覆盖默认路径
MAPPING_FILE="${1:-scripts/repos.list}"

declare -a LINES
if [ -f "$MAPPING_FILE" ]; then
  mapfile -t LINES < "$MAPPING_FILE"
else
  # 回退到内置默认列表
  LINES=(
    "frappe"
    "hrms"
    "crm"
  )
fi

for line in "${LINES[@]}"; do
  # 去除前后空白并跳过空行或注释行
  line_trimmed=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  [ -z "$line_trimmed" ] && continue
  case "$line_trimmed" in
    \#*) continue ;; # 注释
  esac

  # 按空白拆分为 src（必须）和可选的 dst
  src=""
  dst=""
  read -r src dst <<< "$line_trimmed"

  if [[ "$src" =~ ^https?:// ]]; then
    SRC_URL="$src"
  else
    SRC_URL="$DEFAULT_SRC_HOST/$src.git"
  fi

  if [ -z "$dst" ]; then
    # 使用仓库名或 src 的最后一部分构建目标默认地址
    if [[ "$src" =~ / ]]; then
      repo_name=$(basename "$src" .git)
    else
      repo_name="$src"
    fi
    DST_URL="${DST_HOST_BASE}/${repo_name}.git"
  else
    if [[ "$dst" =~ ^https?:// ]]; then
      DST_URL="$dst"
    else
      DST_URL="${DST_HOST_BASE}/${dst}.git"
    fi
  fi

  echo "==> 同步: $SRC_URL -> $DST_URL"

  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  # 使用非-mirror 方式：克隆为 bare 仓库，并分别推送所有分支与标签
  git clone --bare "$SRC_URL" "$tmpdir"
  pushd "$tmpdir" >/dev/null

  # 添加目标 remote 并推送分支与标签（非镜像方式，不强制删除目标上额外的 refs）
  git remote add target "$DST_URL"
  git fetch --prune origin
  git push --all target
  git push --tags target

  # 自动删除目标上在源已不存在的分支：
  # 1) 列出本地（源）分支
  # 2) 列出目标远程分支
  # 3) 对比并删除目标上多余的分支
  echo "==> 检查并删除目标上已被删除的分支（如果有）"

  # 本地分支列表
  mapfile -t local_branches < <(git for-each-ref --format='%(refname:short)' refs/heads)

  # 目标远程分支列表（使用 ls-remote）
  mapfile -t remote_branches < <(git ls-remote --heads target | awk '{print $2}' | sed 's|refs/heads/||')

  # 将本地分支放入关联数组以便快速查找
  declare -A local_map
  for b in "${local_branches[@]}"; do
    local_map["$b"]=1
  done

  # 收集需要删除的远端分支
  del_list=()
  for rb in "${remote_branches[@]}"; do
    if [ -z "${local_map[$rb]:-}" ]; then
      del_list+=("$rb")
    fi
  done

  if [ ${#del_list[@]} -gt 0 ]; then
    echo "将删除以下目标分支: ${del_list[*]}"
    for br in "${del_list[@]}"; do
      echo "删除目标分支: $br"
      git push target --delete "$br" || echo "警告: 删除 $br 失败"
    done
  else
    echo "目标没有多余分支，无需删除。"
  fi

  popd >/dev/null
  rm -rf "$tmpdir"
  trap - EXIT
  echo "==> 完成"
done

echo "所有仓库已镜像完成。"
