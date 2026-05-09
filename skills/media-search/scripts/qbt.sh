#!/usr/bin/env bash
# qBittorrent Web API 操作脚本
# 用法: qbt.sh <command> [options]
set -euo pipefail

QB_HOST="${QB_HOST:-http://localhost}"
QB_PORT="${QB_PORT:-8080}"
QB_USER="${QB_USER:-admin}"
QB_PASS="${QB_PASS:-adminadmin}"
QB_BASE="${QB_HOST}:${QB_PORT}"
COOKIE_JAR="${TMPDIR:-/tmp}/.qbt_session_$$"

usage() {
  cat <<'EOF'
qBittorrent Web API 脚本

用法:
  qbt.sh add <magnet|url|torrent文件> [选项]   添加下载任务
  qbt.sh list [选项]                            列出任务
  qbt.sh pause <hash|all>                       暂停
  qbt.sh resume <hash|all>                      恢复
  qbt.sh delete <hash> [--with-files]           删除任务
  qbt.sh info <hash>                            查看任务详情
  qbt.sh version                                查看 qBt 版本
  qbt.sh status                                 查看全局状态

add 选项:
  --save-path PATH      保存目录
  --category NAME       分类
  --tags TAG1,TAG2      标签
  --paused              添加后暂停
  --sequential          顺序下载
  --skip-check          跳过哈希检查

list 选项:
  --filter VALUE        all / downloading / completed / paused / errored
  --category NAME       按分类过滤
  --sort VALUE          排序字段
  --limit N             返回数量

通用选项:
  --host HOST           qBt 地址（默认 http://localhost）
  --port PORT           端口（默认 8080）
  --user USER           用户名（默认 admin）
  --pass PASS           密码（默认 adminadmin）
  -h, --help            显示帮助

环境变量:
  QB_HOST    QB_PORT    QB_USER    QB_PASS

示例:
  # 添加 magnet
  qbt.sh add "magnet:?xt=urn:btih:..."

  # 添加并指定目录和分类
  qbt.sh add "magnet:?xt=urn:btih:..." --save-path /downloads/movies --category movies

  # 添加 torrent 文件
  qbt.sh add /path/to/file.torrent --save-path /downloads

  # 配合 search-movie.sh 使用：把第一个 magnet 直接丢给 qBt
  search-movie.sh search "the matrix" --limit 1 | grep Magnet | awk '{print $2}' | xargs qbt.sh add

  # 列出正在下载的任务
  qbt.sh list --filter downloading

  # 删除任务（保留文件）
  qbt.sh delete abc123def456

  # 删除任务（同时删文件）
  qbt.sh delete abc123def456 --with-files
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

# 登录，保存 session cookie
login() {
  local resp
  resp=$(curl -fsSL \
    --connect-timeout 10 \
    --max-time 15 \
    -c "$COOKIE_JAR" \
    --data-urlencode "username=${QB_USER}" \
    --data-urlencode "password=${QB_PASS}" \
    "${QB_BASE}/api/v2/auth/login" 2>&1) || die "无法连接到 qBittorrent: $QB_BASE"

  [[ "$resp" == "Ok." ]] || die "登录失败（用户名或密码错误）: $resp"
}

# 登出
logout() {
  curl -fsSL \
    -b "$COOKIE_JAR" \
    --connect-timeout 5 \
    "${QB_BASE}/api/v2/auth/logout" &>/dev/null || true
  rm -f "$COOKIE_JAR"
}

# 通用 GET
qbt_get() {
  local path="$1"; shift
  curl -fsSL \
    -b "$COOKIE_JAR" \
    --connect-timeout 10 \
    --max-time 30 \
    -G "${QB_BASE}/api/v2/${path}" \
    "$@"
}

# 通用 POST（form）
qbt_post() {
  local path="$1"; shift
  curl -fsSL \
    -b "$COOKIE_JAR" \
    --connect-timeout 10 \
    --max-time 30 \
    "${QB_BASE}/api/v2/${path}" \
    "$@"
}

cmd_add() {
  local target="${1:-}"
  [[ -n "$target" ]] || die "add 需要提供 magnet/URL/torrent 文件路径"
  shift

  # 解析 add 专属选项
  local save_path="" category="" tags="" paused="false" sequential="false" skip_check="false"
  while (($#)); do
    case "$1" in
      --save-path)   save_path="$2";   shift 2 ;;
      --category)    category="$2";    shift 2 ;;
      --tags)        tags="$2";        shift 2 ;;
      --paused)      paused="true";    shift ;;
      --sequential)  sequential="true"; shift ;;
      --skip-check)  skip_check="true"; shift ;;
      *) die "add: 未知选项 $1" ;;
    esac
  done

  local -a args=()

  if [[ -f "$target" ]]; then
    # torrent 文件
    args+=(-F "torrents=@${target}")
  elif [[ "$target" == magnet:* || "$target" == http* ]]; then
    # magnet 或 URL
    args+=(--data-urlencode "urls=${target}")
  else
    die "无法识别的输入: $target（需要 magnet 链接、HTTP URL 或 .torrent 文件路径）"
  fi

  [[ -n "$save_path"  ]] && args+=(--data-urlencode "savepath=${save_path}")
  [[ -n "$category"   ]] && args+=(--data-urlencode "category=${category}")
  [[ -n "$tags"       ]] && args+=(--data-urlencode "tags=${tags}")
  [[ "$paused"       == "true" ]] && args+=(--data-urlencode "paused=true")
  [[ "$sequential"   == "true" ]] && args+=(--data-urlencode "sequentialDownload=true")
  [[ "$skip_check"   == "true" ]] && args+=(--data-urlencode "skipChecking=true")

  local resp
  resp=$(qbt_post "torrents/add" "${args[@]}" 2>&1) || die "添加失败: $resp"

  case "$resp" in
    "Ok.")      printf '✓ 已添加任务\n' ;;
    "Fails.")   die "添加失败（torrent 已存在或格式错误）" ;;
    *)          printf '响应: %s\n' "$resp" ;;
  esac
}

cmd_list() {
  local filter="all" category="" sort_by="added_on" limit=""
  while (($#)); do
    case "$1" in
      --filter)   filter="$2";   shift 2 ;;
      --category) category="$2"; shift 2 ;;
      --sort)     sort_by="$2";  shift 2 ;;
      --limit)    limit="$2";    shift 2 ;;
      *) die "list: 未知选项 $1" ;;
    esac
  done

  local -a args=(--data-urlencode "filter=${filter}" --data-urlencode "sort=${sort_by}")
  [[ -n "$category" ]] && args+=(--data-urlencode "category=${category}")
  [[ -n "$limit"    ]] && args+=(--data-urlencode "limit=${limit}")

  qbt_get "torrents/info" "${args[@]}" | jq -r '
    if length == 0 then "（无任务）"
    else .[] | [
      (.hash[0:8]),
      (if .state == "downloading" then "↓"
       elif .state == "uploading" then "↑"
       elif .state == "pausedDL" or .state == "pausedUP" then "⏸"
       elif .state == "error" then "✗"
       else .state end),
      ((.progress * 100) | floor | tostring) + "%",
      (.size / 1073741824 * 10 | floor / 10 | tostring) + "GB",
      (.dlspeed / 1048576 * 10 | floor / 10 | tostring) + "MB/s",
      .name
    ] | join("\t") end
  ' | column -t -s $'\t'
}

cmd_pause() {
  local hash="${1:-}"; [[ -n "$hash" ]] || die "pause 需要 hash 或 all"
  qbt_post "torrents/pause" --data-urlencode "hashes=${hash}" >/dev/null
  printf '⏸ 已暂停: %s\n' "$hash"
}

cmd_resume() {
  local hash="${1:-}"; [[ -n "$hash" ]] || die "resume 需要 hash 或 all"
  qbt_post "torrents/resume" --data-urlencode "hashes=${hash}" >/dev/null
  printf '▶ 已恢复: %s\n' "$hash"
}

cmd_delete() {
  local hash="${1:-}"; [[ -n "$hash" ]] || die "delete 需要 hash"
  local delete_files="false"
  [[ "${2:-}" == "--with-files" ]] && delete_files="true"

  qbt_post "torrents/delete" \
    --data-urlencode "hashes=${hash}" \
    --data-urlencode "deleteFiles=${delete_files}" >/dev/null

  [[ "$delete_files" == "true" ]] \
    && printf '🗑 已删除任务及文件: %s\n' "$hash" \
    || printf '🗑 已删除任务（文件保留）: %s\n' "$hash"
}

cmd_info() {
  local hash="${1:-}"; [[ -n "$hash" ]] || die "info 需要 hash"
  qbt_get "torrents/info" --data-urlencode "hashes=${hash}" | jq -r '
    .[] | [
      "名称:     " + .name,
      "Hash:     " + .hash,
      "状态:     " + .state,
      "进度:     " + ((.progress * 100 * 10 | floor / 10) | tostring) + "%",
      "大小:     " + ((.size / 1073741824 * 100 | floor / 100) | tostring) + " GB",
      "下载速度: " + ((.dlspeed / 1048576 * 10 | floor / 10) | tostring) + " MB/s",
      "上传速度: " + ((.upspeed / 1048576 * 10 | floor / 10) | tostring) + " MB/s",
      "保存路径: " + .save_path,
      "分类:     " + (.category // "-"),
      "标签:     " + (.tags // "-"),
      "添加时间: " + (.added_on | todate)
    ] | join("\n")
  '
}

cmd_version() {
  local ver
  ver=$(qbt_get "app/version" 2>&1) || die "获取版本失败"
  printf 'qBittorrent: %s\n' "$ver"
  qbt_get "app/webapiVersion" | xargs printf 'Web API:      %s\n'
}

cmd_status() {
  qbt_get "sync/maindata" | jq -r '
    .server_state | [
      "下载速度: " + ((.dl_info_speed / 1048576 * 10 | floor / 10) | tostring) + " MB/s",
      "上传速度: " + ((.up_info_speed / 1048576 * 10 | floor / 10) | tostring) + " MB/s",
      "已下载:   " + ((.dl_info_data / 1073741824 * 100 | floor / 100) | tostring) + " GB",
      "已上传:   " + ((.up_info_data / 1073741824 * 100 | floor / 100) | tostring) + " GB",
      "空闲空间: " + ((.free_space_on_disk / 1073741824 * 100 | floor / 100) | tostring) + " GB"
    ] | join("\n")
  '
}

parse_global_options() {
  # 从参数里提前提取 --host/--port/--user/--pass，其余留给子命令
  local -a remaining=()
  while (($#)); do
    case "$1" in
      --host) QB_HOST="$2"; QB_BASE="${QB_HOST}:${QB_PORT}"; shift 2 ;;
      --port) QB_PORT="$2"; QB_BASE="${QB_HOST}:${QB_PORT}"; shift 2 ;;
      --user) QB_USER="$2"; shift 2 ;;
      --pass) QB_PASS="$2"; shift 2 ;;
      *) remaining+=("$1"); shift ;;
    esac
  done
  printf '%s\n' "${remaining[@]+"${remaining[@]}"}"
}

main() {
  check_deps
  (($#)) || { usage; exit 0; }
  [[ "$1" == "-h" || "$1" == "--help" ]] && { usage; exit 0; }

  local command="$1"; shift

  # 提取全局选项，剩余传给子命令
  local -a sub_args=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && sub_args+=("$line")
  done < <(parse_global_options "$@")

  # 登录 + 注册退出时自动登出
  login
  trap logout EXIT

  case "$command" in
    add)        cmd_add     "${sub_args[@]+"${sub_args[@]}"}" ;;
    list)       cmd_list    "${sub_args[@]+"${sub_args[@]}"}" ;;
    pause)      cmd_pause   "${sub_args[@]+"${sub_args[@]}"}" ;;
    resume)     cmd_resume  "${sub_args[@]+"${sub_args[@]}"}" ;;
    delete)     cmd_delete  "${sub_args[@]+"${sub_args[@]}"}" ;;
    info)       cmd_info    "${sub_args[@]+"${sub_args[@]}"}" ;;
    version)    cmd_version ;;
    status)     cmd_status ;;
    *) die "未知命令: $command" ;;
  esac
}

main "$@"
