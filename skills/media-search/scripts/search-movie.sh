#!/usr/bin/env bash
# YTS 电影搜索 - 输出 torrent 和 magnet 链接
# 用法: search-movie.sh <command> [options]
set -euo pipefail

BASE_URL="${YTS_API_BASE_URL:-https://movies-api.accel.li/api/v2}"
FORMAT="json"
OUTPUT="summary"
COMMAND=""
ENDPOINT=""
declare -a PARAMS=()

usage() {
  cat <<'EOF'
YTS 电影搜索

用法:
  search-movie.sh search "电影名" [选项]
  search-movie.sh list [选项]
  search-movie.sh details --movie-id ID | --imdb-id ID
  search-movie.sh suggestions --movie-id ID

选项:
  --limit N           返回数量 (1-50，默认 10)
  --page N            页码
  --quality VALUE     480p / 720p / 1080p / 2160p / 3D
  --minimum-rating N  最低 IMDb 评分 (0-9)
  --genre VALUE       类型 (action / comedy / drama ...)
  --sort-by VALUE     排序: title / year / rating / seeds / download_count
  --order-by asc|desc 排序方向
  --movie-id ID       YTS 电影 ID
  --imdb-id ID        IMDb ID (如 tt0133093)
  --full              输出完整格式化 JSON
  --raw               输出原始响应
  -h, --help          显示帮助

示例:
  search-movie.sh search "the matrix" --quality 1080p --limit 5
  search-movie.sh list --genre action --minimum-rating 7 --sort-by rating
  search-movie.sh details --imdb-id tt0133093
  search-movie.sh suggestions --movie-id 3525
EOF
}

die()        { printf 'Error: %s\n\n' "$*" >&2; usage >&2; exit 2; }
need_value() { [[ -n "${2:-}" && "${2:-}" != --* ]] || die "$1 requires a value"; }
add_param()  { PARAMS+=("$1=$2"); }
has_param()  { local p; for p in "${PARAMS[@]:-}"; do [[ "$p" == "$1="* ]] && return 0; done; return 1; }

check_deps() {
  local missing=()
  for cmd in curl jq; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  (( ${#missing[@]} == 0 )) || { printf 'Missing: %s\n' "${missing[*]}" >&2; exit 1; }
}

set_endpoint() {
  case "$1" in
    search|list|list_movies) COMMAND="list";        ENDPOINT="list_movies" ;;
    details|movie_details)   COMMAND="details";     ENDPOINT="movie_details" ;;
    suggestions|movie_suggestions) COMMAND="suggestions"; ENDPOINT="movie_suggestions" ;;
    *) die "unknown command: $1" ;;
  esac
}

parse_options() {
  while (($#)); do
    case "$1" in
      --full)            OUTPUT="full";                              shift ;;
      --raw)             OUTPUT="raw";                               shift ;;
      -h|--help)         usage; exit 0 ;;
      --limit)           need_value "$1" "${2:-}"; add_param limit "$2";            shift 2 ;;
      --page)            need_value "$1" "${2:-}"; add_param page "$2";             shift 2 ;;
      --quality)         need_value "$1" "${2:-}"; add_param quality "$2";          shift 2 ;;
      --minimum-rating)  need_value "$1" "${2:-}"; add_param minimum_rating "$2";   shift 2 ;;
      --query|--query-term) need_value "$1" "${2:-}"; add_param query_term "$2";   shift 2 ;;
      --genre)           need_value "$1" "${2:-}"; add_param genre "$2";            shift 2 ;;
      --sort-by)         need_value "$1" "${2:-}"; add_param sort_by "$2";          shift 2 ;;
      --order-by)        need_value "$1" "${2:-}"; add_param order_by "$2";         shift 2 ;;
      --with-rt-ratings) need_value "$1" "${2:-}"; add_param with_rt_ratings "$2"; shift 2 ;;
      --movie-id)        need_value "$1" "${2:-}"; add_param movie_id "$2";         shift 2 ;;
      --imdb-id)         need_value "$1" "${2:-}"; add_param imdb_id "$2";          shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
}

validate_params() {
  case "$COMMAND" in
    details)     has_param movie_id || has_param imdb_id || die "details 需要 --movie-id 或 --imdb-id" ;;
    suggestions) has_param movie_id || die "suggestions 需要 --movie-id" ;;
  esac
}

print_summary() {
  local jq_filter='
    def magnet($name):
      "magnet:?xt=urn:btih:" + (.hash // "") +
      "&dn=" + ($name | @uri) +
      "&tr=udp://tracker.opentrackr.org:1337/announce" +
      "&tr=udp://open.stealth.si:80/announce" +
      "&tr=udp://tracker.torrent.eu.org:451/announce";

    def torrents($m):
      if (($m.torrents // []) | length) == 0 then "  (无可用种子)"
      else $m.torrents[] | [
        "  质量: " + (.quality // "?") + " | 编码: " + (.video_codec // "-") +
        " | 大小: " + (.size // "-") + " | Seeds: " + ((.seeds // 0)|tostring) +
        " | Peers: " + ((.peers // 0)|tostring),
        "  Torrent: " + (.url // "-"),
        "  Magnet:  " + magnet($m.title_long // $m.title // "YTS")
      ] | join("\n") end;

    def block:
      [ "ID: "     + (.id|tostring),
        "Title: "  + (.title_long // .title // ""),
        "IMDb: "   + (.imdb_code // "-"),
        "Rating: " + ((.rating // "-")|tostring),
        "URL: "    + (.url // "-"),
        "Torrents:", torrents(.) ] | join("\n");
  '
  case "$COMMAND" in
    list|suggestions)
      jq -r "$jq_filter"'
        if .status != "ok" then "ERROR: " + (.status_message // .status)
        elif ((.data.movies // []) | length) == 0 then "未找到结果"
        else (.data.movies | unique_by(.id)[] | block), "" end' ;;
    details)
      jq -r "$jq_filter"'
        if .status != "ok" then "ERROR: " + (.status_message // .status)
        else .data.movie | block end' ;;
    *) jq -c . ;;
  esac
}

request() {
  local url="${BASE_URL%/}/${ENDPOINT}.${FORMAT}"
  local -a args=(-fsSL -G --connect-timeout 15 --max-time 60 "$url")
  local p
  for p in "${PARAMS[@]:-}"; do args+=(--data-urlencode "$p"); done

  local response
  if ! response=$(curl "${args[@]}" 2>&1); then
    printf 'Network error: %s\n' "$response" >&2
    exit 1
  fi

  case "$OUTPUT" in
    summary) printf '%s' "$response" | print_summary ;;
    full)    printf '%s' "$response" | jq . ;;
    raw)     printf '%s\n' "$response" ;;
  esac
}

main() {
  check_deps
  (($#)) || { usage; exit 0; }
  [[ "$1" == "-h" || "$1" == "--help" ]] && { usage; exit 0; }

  set_endpoint "$1"; shift

  # 允许 search "query" 的位置参数写法
  if [[ "$COMMAND" == "list" && $# -gt 0 && "${1:-}" != --* ]]; then
    add_param query_term "$1"; shift
  fi

  parse_options "$@"
  validate_params

  [[ "$COMMAND" == "list" ]] && ! has_param limit && add_param limit 10

  request
}

main "$@"
