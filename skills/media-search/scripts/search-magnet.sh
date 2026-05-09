#!/usr/bin/env bash
# 磁力搜索 - cilisousuo.co
# 用法: search-magnet.sh "关键词" [数量=10]
set -euo pipefail

KEYWORD="${1:-}"
MAX_RESULTS="${2:-10}"
BASE_URL="${MAGNET_BASE_URL:-https://cilisousuo.co}"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

usage() {
  cat <<'EOF'
磁力搜索

用法: search-magnet.sh "关键词" [数量=10]

示例:
  search-magnet.sh "MIDV-022" 5
  search-magnet.sh "周杰伦" 10

环境变量:
  MAGNET_BASE_URL   搜索站地址（默认 https://cilisousuo.co）
EOF
}

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

check_deps() {
  local missing=()
  for cmd in curl python3; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  (( ${#missing[@]} == 0 )) || { printf 'Missing: %s\n' "${missing[*]}" >&2; exit 1; }
}

url_encode() {
  python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

# 解码 HTML 实体
decode_html() {
  sed 's/&amp;amp;/\&/g; s/&amp;/\&/g; s/&#38;/\&/g'
}

fetch() {
  curl -fsSL \
    -A "$UA" \
    --connect-timeout 15 \
    --max-time 30 \
    --retry 2 \
    --retry-delay 1 \
    "$@"
}

extract_detail() {
  local html="$1"

  local title
  title=$(printf '%s' "$html" \
    | grep -oP '(?<=<h1 class="title">)[^<]+' \
    | head -1 \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  # 备用：sed 方式
  [[ -z "$title" ]] && title=$(printf '%s' "$html" \
    | sed -n 's/.*<h1 class="title">\([^<]*\)<\/h1>.*/\1/p' \
    | head -1)

  local size
  size=$(printf '%s' "$html" \
    | grep -oP '(?<=<dt>文件大小 :</dt> <dd>)[^<]+' \
    | head -1)
  [[ -z "$size" ]] && size=$(printf '%s' "$html" \
    | sed -n 's/.*<dt>文件大小 :<\/dt>[[:space:]]*<dd>\([^<]*\)<\/dd>.*/\1/p' \
    | head -1)

  local magnet
  magnet=$(printf '%s' "$html" \
    | grep -oP '(?<=id="input-magnet")[^>]*value="\K[^"]+' \
    | head -1 \
    | decode_html)
  [[ -z "$magnet" ]] && magnet=$(printf '%s' "$html" \
    | sed -n 's/.*id="input-magnet"[^>]*value="\([^"]*\)".*/\1/p' \
    | head -1 \
    | decode_html)

  printf '%s\t%s\t%s' "$title" "$size" "$magnet"
}

main() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && { usage; exit 0; }
  [[ -z "$KEYWORD" ]] && { usage >&2; exit 1; }

  check_deps

  local encoded
  encoded=$(url_encode "$KEYWORD")
  local search_url="${BASE_URL}/search?q=${encoded}"

  printf '正在搜索: %s\n' "$KEYWORD" >&2
  printf 'URL: %s\n\n' "$search_url" >&2

  local search_html
  if ! search_html=$(fetch "$search_url" 2>&1); then
    die "无法连接到搜索站: $search_html"
  fi

  local detail_links
  detail_links=$(printf '%s' "$search_html" \
    | grep -oE '/magnet/[a-zA-Z0-9]+' \
    | sort -u \
    | head -n "$MAX_RESULTS")

  if [[ -z "$detail_links" ]]; then
    printf '未找到结果\n' >&2
    exit 1
  fi

  local count
  count=$(printf '%s' "$detail_links" | wc -l | tr -d ' ')
  printf '找到 %s 个结果\n\n' "$count" >&2

  local index=1
  while IFS= read -r link; do
    local detail_url="${BASE_URL}${link}"
    local detail_html

    if ! detail_html=$(fetch "$detail_url" 2>&1); then
      printf '[%d] 获取详情失败: %s\n\n' "$index" "$link" >&2
      index=$((index + 1))
      continue
    fi

    local info
    info=$(extract_detail "$detail_html")
    local title size magnet
    IFS=$'\t' read -r title size magnet <<< "$info"

    if [[ -n "$magnet" ]]; then
      printf '[%d] %s\n' "$index" "${title:-（无标题）}"
      [[ -n "$size" ]] && printf '    大小: %s\n' "$size"
      printf '    磁力: %s\n\n' "$magnet"
    else
      printf '[%d] %s（未找到磁力链接）\n\n' "$index" "${title:-$link}" >&2
    fi

    index=$((index + 1))
    sleep 0.3
  done <<< "$detail_links"
}

main "$@"
