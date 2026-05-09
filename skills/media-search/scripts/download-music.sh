#!/usr/bin/env bash
# JOOX 专辑下载（音频 + 歌词）
# 用法: download-music.sh ALBUM_ID [下载目录]
set -euo pipefail

ALBUM_ID="${1:-}"
ROOT_DIR="${2:-${JOOX_ROOT_DIR:-/tmp/joox-downloads}}"
JOOX_COOKIE="${JOOX_COOKIE:-wmid=142420656; user_type=1; country=id; session_key=2a5d97d05dc8fe238150184eaf3519ad;}"
JOOX_XFF="${JOOX_XFF:-36.73.34.109}"
JOOX_COUNTRY="${JOOX_COUNTRY:-hk}"
JOOX_LANG="${JOOX_LANG:-zh_TW}"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

usage() {
  cat <<'EOF'
JOOX 专辑下载

用法: download-music.sh ALBUM_ID [下载目录=/tmp/joox-downloads]

示例:
  download-music.sh 12345
  download-music.sh 12345 ~/Music/joox

  # 配合 search-music.sh:
  ./search-music.sh "周杰伦" 5 2>/dev/null | head -1 | awk -F'\t' '{print $3}' | xargs ./download-music.sh

状态输出 (Tab 分隔):
  START            专辑名  曲名
  DONE_AUDIO       曲名    路径
  SKIP_EXISTS      曲名    路径
  FAIL_NO_URL      曲名
  FAIL_AUDIO       曲名
  DONE_LRC         曲名    路径
  NO_LRC           曲名
  DONE_ALBUM       艺术家  专辑名  目录

环境变量:
  JOOX_ROOT_DIR   默认下载目录
  JOOX_COOKIE     JOOX Cookie
  JOOX_XFF        X-Forwarded-For
  JOOX_COUNTRY    地区（默认 hk）
  JOOX_LANG       语言（默认 zh_TW）
EOF
}

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

check_deps() {
  local missing=()
  for cmd in curl jq perl; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  (( ${#missing[@]} == 0 )) || { printf 'Missing: %s\n' "${missing[*]}" >&2; exit 1; }
}

sanitize() {
  printf '%s' "$1" | sed 's|[/\\:*?"<>|]|_|g; s/[[:space:]]*$//'
}

curl_joox() {
  curl -fsSL \
    -H "user-agent: ${UA}" \
    -H "cookie: ${JOOX_COOKIE}" \
    -H "x-forwarded-for: ${JOOX_XFF}" \
    --connect-timeout 15 \
    --max-time 120 \
    --retry 2 \
    --retry-delay 2 \
    "$@"
}

extract_next_data() {
  perl -0777 -ne '
    if (/<script id="__NEXT_DATA__" type="application\/json"[^>]*>(.*?)<\/script>/s) {
      print $1
    }'
}

get_song_url() {
  local song_id="$1"
  local raw info url

  for attempt in 1 2 3; do
    raw=$(curl -fsSG 'https://api.joox.com/web-fcgi-bin/web_get_songinfo' \
      --data-urlencode "songid=${song_id}" \
      --data-urlencode "lang=${JOOX_LANG}" \
      --data-urlencode "country=${JOOX_COUNTRY}" \
      -H "user-agent: ${UA}" \
      -H "cookie: ${JOOX_COOKIE}" \
      -H "x-forwarded-for: ${JOOX_XFF}" \
      --connect-timeout 15 \
      --max-time 30 \
      2>/dev/null || true)

    info=$(printf '%s' "$raw" \
      | perl -0777 -pe 's/^\s*MusicInfoCallback\((.*)\)\s*$/$1/s' 2>/dev/null || true)

    if printf '%s' "$info" | jq -e . >/dev/null 2>&1; then
      url=$(printf '%s' "$info" | jq -r '
        .master_tapeUrl // .master_tapeURL //
        .hiresUrl // .hiresURL //
        .flacUrl // .flacURL //
        .r320Url // .r320url //
        .r192Url // .r192url //
        .mp3Url // .m4aUrl // ""
      ')
      [[ -n "$url" ]] && { printf '%s' "$url"; return 0; }
    fi

    [[ $attempt -lt 3 ]] && sleep 2
  done

  return 1
}

download_lyric() {
  local song_id="$1" out_path="$2" song_name="$3"

  local raw lyric_json lyric_b64
  raw=$(curl -fsSG 'https://api.joox.com/web-fcgi-bin/web_lyric' \
    --data-urlencode "musicid=${song_id}" \
    --data-urlencode "country=${JOOX_COUNTRY}" \
    --data-urlencode "lang=${JOOX_LANG}" \
    -H "user-agent: ${UA}" \
    -H "cookie: ${JOOX_COOKIE}" \
    -H "x-forwarded-for: ${JOOX_XFF}" \
    --connect-timeout 15 \
    --max-time 30 \
    2>/dev/null || true)

  lyric_json=$(printf '%s' "$raw" \
    | perl -0777 -pe 's/^\s*MusicJsonCallback\((.*)\)\s*$/$1/s' 2>/dev/null || true)

  lyric_b64=$(printf '%s' "$lyric_json" \
    | jq -r '.lyric // empty' 2>/dev/null || true)

  if [[ -n "$lyric_b64" ]]; then
    printf '%s' "$lyric_b64" | base64 -d > "$out_path" 2>/dev/null || { rm -f "$out_path"; return 1; }
    [[ -s "$out_path" ]] && { printf 'DONE_LRC\t%s\t%s\n' "$song_name" "$out_path"; return 0; }
    rm -f "$out_path"
  fi

  printf 'NO_LRC\t%s\n' "$song_name"
  return 0
}

main() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && { usage; exit 0; }
  [[ -z "$ALBUM_ID" ]] && { usage >&2; exit 1; }

  check_deps

  printf '正在获取专辑信息: %s\n' "$ALBUM_ID" >&2

  local page_html
  if ! page_html=$(curl_joox "https://www.joox.com/hk/album/${ALBUM_ID}" 2>&1); then
    die "无法获取专辑页面: $page_html"
  fi

  local album_json
  album_json=$(printf '%s' "$page_html" | extract_next_data)
  [[ -z "$album_json" ]] && die "未找到专辑数据（可能需要更新 Cookie）"

  local album_name artist_name
  album_name=$(printf '%s' "$album_json" | jq -r '.props.pageProps.albumData.title // empty')
  artist_name=$(printf '%s' "$album_json" | jq -r '.props.pageProps.albumData.artistList[0].name // empty')

  [[ -z "$album_name" ]] && die "无法解析专辑名称"
  [[ -z "$artist_name" ]] && artist_name="Unknown"

  local album_dir="${ROOT_DIR}/$(sanitize "$artist_name")/$(sanitize "$album_name")"
  mkdir -p "$album_dir"

  printf '\n专辑: %s - %s\n目录: %s\n\n' "$artist_name" "$album_name" "$album_dir" >&2

  local total=0 done=0 failed=0
  while IFS= read -r track; do
    local song_id song_name
    song_id=$(printf '%s' "$track" | jq -r '.id')
    song_name=$(printf '%s' "$track" | jq -r '.name')
    total=$((total + 1))

    printf 'START\t%s\t%s\n' "$album_name" "$song_name"

    local safe_name
    safe_name=$(sanitize "$song_name")

    # 获取音频 URL
    local url=""
    url=$(get_song_url "$song_id") || true

    if [[ -z "$url" ]]; then
      printf 'FAIL_NO_URL\t%s\n' "$song_name"
      failed=$((failed + 1))
      continue
    fi

    # 确定扩展名
    local ext="${url%%\?*}"; ext="${ext##*.}"
    [[ -n "$ext" && "$ext" =~ ^[a-z0-9]{2,4}$ ]] || ext="mp3"

    local out="${album_dir}/${safe_name}.${ext}"

    if [[ -s "$out" ]]; then
      printf 'SKIP_EXISTS\t%s\t%s\n' "$song_name" "$out"
    else
      if curl_joox --retry 3 -o "$out" "$url"; then
        printf 'DONE_AUDIO\t%s\t%s\n' "$song_name" "$out"
        done=$((done + 1))
      else
        rm -f "$out"
        printf 'FAIL_AUDIO\t%s\n' "$song_name"
        failed=$((failed + 1))
        continue
      fi
    fi

    # 下载歌词
    local lrc="${album_dir}/${safe_name}.lrc"
    if [[ ! -s "$lrc" ]]; then
      download_lyric "$song_id" "$lrc" "$song_name"
    fi

  done < <(printf '%s' "$album_json" \
    | jq -c '.props.pageProps.albumTrackData.tracks.items[]' 2>/dev/null)

  printf '\nDONE_ALBUM\t%s\t%s\t%s\n' "$artist_name" "$album_name" "$album_dir"
  printf '\n完成: %d 首，失败: %d 首，共 %d 首\n' "$done" "$failed" "$total" >&2
}

main "$@"
