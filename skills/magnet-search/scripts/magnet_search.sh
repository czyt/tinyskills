#!/bin/bash
# 磁力搜索脚本 - 从 cilisousuo.co 搜索并提取磁力链接
# 使用方法: ./magnet_search.sh "关键词" [结果数量]

set -e

KEYWORD="${1:-}"
MAX_RESULTS="${2:-10}"
BASE_URL="https://cilisousuo.co"
USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

if [ -z "$KEYWORD" ]; then
    echo "用法: $0 <关键词> [结果数量]" >&2
    echo "示例: $0 \"MIDV-022\" 5" >&2
    exit 1
fi

# URL 编码关键词
ENCODED_KEYWORD=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$KEYWORD'))")
SEARCH_URL="${BASE_URL}/search?q=${ENCODED_KEYWORD}"

echo "正在搜索: $KEYWORD" >&2
echo "URL: $SEARCH_URL" >&2
echo "" >&2

# 获取搜索结果页面
SEARCH_HTML=$(curl -s "$SEARCH_URL" -A "$USER_AGENT" --connect-timeout 30)

# 提取详情页链接 (格式: /magnet/xxxx)
DETAIL_LINKS=$(echo "$SEARCH_HTML" | grep -oE '/magnet/[a-zA-Z0-9]+' | head -n "$MAX_RESULTS")

if [ -z "$DETAIL_LINKS" ]; then
    echo "未找到结果" >&2
    exit 1
fi

COUNT=$(echo "$DETAIL_LINKS" | wc -l | tr -d ' ')
echo "找到 $COUNT 个结果" >&2
echo "" >&2

# 遍历每个详情页获取磁力链接
INDEX=1
echo "$DETAIL_LINKS" | while read -r LINK; do
    DETAIL_URL="${BASE_URL}${LINK}"

    # 获取详情页
    DETAIL_HTML=$(curl -s "$DETAIL_URL" -A "$USER_AGENT" --connect-timeout 30)

    # 提取标题 (使用 sed)
    TITLE=$(echo "$DETAIL_HTML" | sed -n 's/.*<h1 class="title">\([^<]*\)<\/h1>.*/\1/p' | head -1)

    # 提取文件大小
    SIZE=$(echo "$DETAIL_HTML" | sed -n 's/.*<dt>文件大小 :<\/dt> <dd>\([^<]*\)<\/dd>.*/\1/p' | head -1)

    # 提取磁力链接 (从 input-magnet 的 value 中)
    MAGNET=$(echo "$DETAIL_HTML" | sed -n 's/.*id="input-magnet"[^>]*value="\([^"]*\)".*/\1/p' | head -1)

    # 处理 HTML 实体
    MAGNET=$(echo "$MAGNET" | sed 's/&amp;amp;/\&/g; s/&amp;/\&/g')

    if [ -n "$MAGNET" ]; then
        echo "[$INDEX] $TITLE"
        [ -n "$SIZE" ] && echo "    大小: $SIZE"
        echo "    磁力: $MAGNET"
        echo ""
    fi

    INDEX=$((INDEX + 1))

    # 延迟避免请求过快
    sleep 0.5
done
