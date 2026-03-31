#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# update.sh
# ────────────────────────────────────────────────────────────────
# 使用“时间戳文件”方式，仅处理自上次脚本运行以来真正被修改过的
#  .md 和 public 下生成文件，将其中的 "../../static" 替换为
#  "https://tzj2006.github.io"，再提交（或推送）public。
#
# 每跑一次脚本，最后会更新 .last_build 时间戳。下次再运行时，
# 只会针对那些比 .last_build 更新过的文件做处理和替换，节省时间。
# ────────────────────────────────────────────────────────────────

set -e

# ─── 配置区 ───────────────────────────────────────────────────────
SRC_DIR="content"                   # 存放 .md 的根目录
IMAGE_DIR="static/images"           # 图片的根目录
PUBLIC_DIR="public"                 # Hugo 输出目录（也是 git 仓库）
TIMESTAMP_FILE=".last_build"        # 记录“上次构建时间”的文件
CONFIG_FILE="config.yml"
PATTERN='\.\./\.\./static'          # sed 中用的正则
COMPRESS_SCRIPT="compress_image.py" # 压缩脚本路径
COMMIT_MESSAGE="update website: $(date '+%Y-%m-%d %H:%M:%S')"
# ───────────────────────────────────────────────────────────────

get_site_base_url() {
  local line url
  line=$(grep -m1 '^baseURL:' "$CONFIG_FILE" || true)
  if [ -z "$line" ]; then
    echo "ERROR: could not find baseURL in $CONFIG_FILE" >&2
    exit 1
  fi

  url=$(printf '%s' "$line" | sed -E 's/^baseURL:[[:space:]]*//')
  url="${url%\"}"
  url="${url#\"}"
  url="${url%\'}"
  url="${url#\'}"
  url="${url%/}"
  printf '%s' "$url"
}

REPLACEMENT="$(get_site_base_url)"

# 若无时间戳文件，则创建一个很久以前的时间戳
if [ ! -f "$TIMESTAMP_FILE" ]; then
  echo "⚠️  未检测到时间戳文件 '$TIMESTAMP_FILE'，将其创建为初始状态。"
  TEN_YEARS_AGO=$(date -v -10y +"%Y%m%d%H%M") || TEN_YEARS_AGO=""
  if [ -n "$TEN_YEARS_AGO" ]; then
    touch -t "$TEN_YEARS_AGO" "$TIMESTAMP_FILE" 2>/dev/null || :
  fi
  # 如果上面失败，则退而求其次
  [ -f "$TIMESTAMP_FILE" ] || touch "$TIMESTAMP_FILE"
  echo "  ↳ 已创建旧时间戳，下次仅处理真正新改动的文件。"
fi

echo
echo "─────────────────────────────────────────────────"
echo "▶ Step 1/5：检查 content/ 下哪些 .md 文件自上次构建以来被修改："
MODIFIED_MD=$(find "$SRC_DIR" -type f -name '*.md' -newer "$TIMESTAMP_FILE")

if [ -n "$MODIFIED_MD" ]; then
  echo "  以下 Markdown 源文件被检测到“已修改”："
  echo "$MODIFIED_MD"
  echo
  echo "  ▶ 正在把 '../../static' → '$REPLACEMENT' 并将 *.jpg/*.jpeg 扩展改为 .png …"
  while IFS= read -r mdfile; do
    [ -f "$mdfile" ] || continue
    if sed --version >/dev/null 2>&1; then
      sed -i "s|${PATTERN}|${REPLACEMENT}|g" "$mdfile"
      sed -i "s|\.\(jpg\|jpeg\)|.png|g" "$mdfile"
    else
      sed -i '' "s|${PATTERN}|${REPLACEMENT}|g" "$mdfile"
      sed -i '' "s|\.\(jpg\|jpeg\)|.png|g" "$mdfile"
    fi
    echo "    ✔ 已处理：${mdfile}"
  done <<< "$MODIFIED_MD"
else
  echo "  ▲ 暂无 .md 文件自上次构建以来发生改动，跳过此步。"
fi

echo
echo "─────────────────────────────────────────────────"
echo "▶ Step 2/5：检查并压缩 static/ 下修改过的图片文件："
MODIFIED_IMG=$(find "$IMAGE_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -newer "$TIMESTAMP_FILE")

if [ -n "$MODIFIED_IMG" ]; then
  echo "  以下图片文件被检测到“已修改”："
  echo "$MODIFIED_IMG"
  echo
  echo "  ▶ 调用 '${COMPRESS_SCRIPT}' 进行压缩…"
  pids=()
  while IFS= read -r imgfile; do
    [ -f "$imgfile" ] || continue
    python3 "$COMPRESS_SCRIPT" "$imgfile" &
    pids+=($!)
    echo "    ✔ 已启动压缩（后台）：${imgfile}"
  done <<< "$MODIFIED_IMG"
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
  echo "  → 图片并行压缩完成。"
else
  echo "  ▲ 暂无图片文件自上次构建以来修改，跳过此步。"
fi

echo
echo "─────────────────────────────────────────────────"
echo "▶ Step 3/5：清理 public/（保留 .git 及其全部内容）…"

if [ -d "$PUBLIC_DIR" ]; then
  find "$PUBLIC_DIR" -mindepth 1 \( -path "$PUBLIC_DIR/.git" -o -path "$PUBLIC_DIR/.git/*" \) -prune -o -exec rm -rf {} +
  echo "✔ public/ 已清空（仅保留 .git 目录及其内容）。"
else
  mkdir -p "$PUBLIC_DIR"
fi


echo
echo "─────────────────────────────────────────────────"
echo "▶ Step 4/5：运行 Hugo 生成 public/ …"
hugo
echo "✔ Hugo 构建完成：'${PUBLIC_DIR}/' 已更新。"

echo
echo "─────────────────────────────────────────────────"
echo "▶ Step 5/6：提交并推送到远端仓库…"
cd "$PUBLIC_DIR"
git add -A
git commit -m "${COMMIT_MESSAGE}"
git push
git gc --aggressive
cd ..

echo
echo "─────────────────────────────────────────────────"
echo "▶ Step 6/6：更新时间戳文件供下次运行："
touch "$TIMESTAMP_FILE"
echo "  ✔ 已将 '${TIMESTAMP_FILE}' 时间更新为当前。"

echo
echo "🎉 部署完成！所有更新已推送。"
