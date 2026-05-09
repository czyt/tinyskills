#!/usr/bin/env bash
# JOOX 音乐专辑搜索
# 用法: search-music.sh "关键词" [数量=10]
set -euo pipefail

KEYWORD="${1:-}"
LIMIT="${2:-10}"
JOOX_COOKIE="${JOOX_COOKIE:-wmid=142420656; user_type=1; country=id; session_key=2a5d97d05dc8fe238150184eaf3519ad;}"
JOOX_XFF="${JOOX_XFF:-36.73.34.109}"
JOOX_COUNTRY="${JOOX_COUNTRY:-hk}"
JOOX_LANG="${JOOX_LANG:-zh_TW}"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

usage() {
  cat <<'EOF'
JOOX 专辑搜索

用法: search-music.sh "关键词" [数量=10]

输出: 专辑名<TAB>发行日期<TAB>专辑ID（可 pipe 给 download-music.sh）

示例:
  search-music.sh "周杰伦" 10
  search-music.sh "Taylor Swift" 5
  # 搜索并下载第一个结果
  search-music.sh "周杰伦" 1 | head -1 | awk -F'\t' '{print $3}' | xargs ./download-music.sh

环境变量:
  JOOX_COOKIE     JOOX 登录 Cookie
  JOOX_XFF        X-Forwarded-For 头
  JOOX_COUNTRY    地区代码（默认 hk）
  JOOX_LANG       语言（默认 zh_TW）
EOF
}

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

check_deps() {
  local missing=()
  for cmd in curl jq; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  (( ${#missing[@]} == 0 )) || { printf 'Missing: %s\n' "${missing[*]}" >&2; exit 1; }
}

main() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && { usage; exit 0; }
  [[ -z "$KEYWORD" ]] && { usage >&2; exit 1; }

  check_deps

  printf '正在搜索专辑: %s\n\n' "$KEYWORD" >&2

  local response
  if ! response=$(curl -fsSG 'https://cache.api.joox.com/openjoox/v2/search_type' \
    --data-urlencode "country=${JOOX_COUNTRY}" \
    --data-urlencode "lang=${JOOX_LANG}" \
    --data-urlencode "key=${KEYWORD}" \
    --data-urlencode 'type=1' \
    -H "user-agent: ${UA}" \
    -H "cookie: ${JOOX_COOKIE}" \
    -H "x-forwarded-for: ${JOOX_XFF}" \
    --connect-timeout 15 \
    --max-time 30 \
    2>&1); then
    die "请求失败: $response"
  fi

  local count
  count=$(printf '%s' "$response" | jq '.albums | length' 2>/dev/null || echo 0)

  if [[ "$count" == "0" || "$count" == "null" ]]; then
    printf '未找到专辑\n' >&2
    exit 1
  fi

  printf '找到 %s 个专辑（显示前 %s 个）\n\n' "$count" "$LIMIT" >&2

  printf '%s' "$response" | jq -r --argjson limit "$LIMIT" '
    .albums[0:$limit][] |
    [ (.name // ""), (.publish_date // ""), (.id // "") ] | @tsv
  ' | while IFS=$'\t' read -r name date id; do
    # 同时打印到 stderr 供阅读，stdout 保持干净 TSV
    printf '  %-40s %s\tID: %s\n' "$name" "$date" "$id" >&2
    printf '%s\t%s\t%s\n' "$name" "$date" "$id"
  done
}

main "$@"
