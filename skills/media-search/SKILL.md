---
name: media-search
description: 搜索电影种子/磁力链接、搜索下载音乐专辑、管理 qBittorrent 下载任务。触发词：找资源、下载、磁力、种子、torrent、magnet、影视、音乐下载、qBt、搜电影、下电影、搜歌、下歌
---

# 资源搜索 Skill

## 触发条件

当用户请求以下任意内容时使用此 Skill：

- 搜索电影种子 / magnet / torrent 链接
- 搜索磁力资源
- 搜索、下载音乐专辑
- 添加/管理 qBittorrent 下载任务
- 提到"找资源"、"下载"、"磁力"、"种子"、"torrent"、"magnet"、"影视"、"音乐下载"、"qBt"、"搜电影"、"下电影"、"搜歌"、"下歌"

---

## 文件清单

| 文件 | 功能 | 依赖 |
|------|------|------|
| `scripts/search-movie.sh` | YTS 电影搜索，输出 torrent + magnet | curl, jq |
| `scripts/search-magnet.sh` | cilisousuo.co 磁力搜索 | curl, python3 |
| `scripts/search-music.sh` | JOOX 专辑搜索，输出 TSV | curl, jq |
| `scripts/download-music.sh` | JOOX 专辑下载（音频 + 歌词） | curl, jq, perl |
| `scripts/qbt.sh` | qBittorrent Web API 操作 | curl, jq |

赋予可执行权限：
```bash
chmod +x scripts/*.sh
```

---

## 工作流

根据用户意图，选择对应流程执行：

### 流程 A：电影搜索

```
Step 1: 解析用户意图，提取搜索关键词
Step 2: 执行搜索
  ./scripts/search-movie.sh search "关键词" --limit 5
Step 3: 展示结果（标题、年份、评分、质量、大小）
Step 4: 🔍 确认 — 询问用户选择哪条结果（编号），或调整搜索条件
Step 5: 用户选择后，展示该条目的 magnet 链接
Step 6: 🔍 确认 — 询问是否添加到 qBittorrent
  - 是 → 执行 流程D（qBt 投递）
  - 否 → 结束
```

### 流程 B：音乐搜索与下载

```
Step 1: 解析用户意图，提取艺术家/专辑关键词
Step 2: 执行搜索
  ./scripts/search-music.sh "关键词" 10
Step 3: 展示搜索结果（专辑名、艺术家、年份、曲目数）
Step 4: 🔍 确认 — 询问用户选择哪张专辑（编号）
Step 5: 用户选择后，执行下载
  ./scripts/download-music.sh {album_id}
Step 6: 展示下载状态（START/DONE_AUDIO/FAIL_* 等状态行）
Step 7: 告知下载目录位置 {JOOX_ROOT_DIR}/{艺术家}/{专辑名}/
```

### 流程 C：磁力搜索

```
Step 1: 解析用户意图，提取搜索关键词
Step 2: 执行搜索
  ./scripts/search-magnet.sh "关键词" 5
Step 3: 展示结果（标题、大小、磁力链接）
Step 4: 🔍 确认 — 询问用户选择哪条结果
Step 5: 用户选择后，展示磁力链接
Step 6: 🔍 确认 — 询问是否添加到 qBittorrent
  - 是 → 执行 流程D（qBt 投递）
  - 否 → 结束
```

### 流程 D：qBittorrent 投递

```
Step 1: 确认 magnet 链接或 torrent URL 已获取
Step 2: 询问保存路径和分类（提供默认值）
  - 默认保存路径：/downloads
  - 默认分类：无
Step 3: 执行添加
  ./scripts/qbt.sh add "magnet:..." --save-path PATH --category NAME
Step 4: 验证添加是否成功
  ./scripts/qbt.sh list --filter downloading --limit 5
Step 5: 报告结果
  - 成功 → 展示任务名和状态
  - 失败 → 检查 qBt 连接（./scripts/qbt.sh status）并报告错误
```

---

## 快速用法

```bash
# 电影搜索
./scripts/search-movie.sh search "the matrix" --quality 1080p --limit 5
./scripts/search-movie.sh list --genre action --minimum-rating 7 --sort-by rating
./scripts/search-movie.sh details --imdb-id tt0133093
./scripts/search-movie.sh suggestions --movie-id 3525

# 磁力搜索
./scripts/search-magnet.sh "MIDV-022" 5
./scripts/search-magnet.sh "关键词" 10

# 音乐搜索
./scripts/search-music.sh "周杰伦" 10

# 音乐下载
./scripts/download-music.sh 12345
./scripts/download-music.sh 12345 ~/Music/joox

# 搜索并直接下载第一个结果
./scripts/search-music.sh "周杰伦" 1 2>/dev/null | head -1 | awk -F'\t' '{print $3}' | xargs ./scripts/download-music.sh

# qBittorrent
./scripts/qbt.sh add "magnet:?xt=urn:btih:..."
./scripts/qbt.sh list --filter downloading
./scripts/qbt.sh status
./scripts/qbt.sh delete abc123def456 --with-files
```

### 组合用法（搜索 → 直接投递 qBt）

```bash
# 电影搜索 → 添加第一个 magnet 到 qBt
./scripts/search-movie.sh search "the matrix" --limit 1 \
  | grep 'Magnet:' | awk '{print $2}' \
  | xargs ./scripts/qbt.sh add --category movies --save-path /downloads/movies

# 磁力搜索 → 添加第一条到 qBt
./scripts/search-magnet.sh "关键词" 3 \
  | grep '磁力:' | head -1 | awk '{print $2}' \
  | xargs ./scripts/qbt.sh add
```

---

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `YTS_API_BASE_URL` | `https://movies-api.accel.li/api/v2` | YTS API 地址 |
| `MAGNET_BASE_URL` | `https://cilisousuo.co` | 磁力搜索站地址 |
| `JOOX_COOKIE` | 内置默认值 | JOOX 登录 Cookie（需定期更新） |
| `JOOX_XFF` | `36.73.34.109` | X-Forwarded-For 头 |
| `JOOX_COUNTRY` | `hk` | JOOX 地区代码 |
| `JOOX_LANG` | `zh_TW` | JOOX 语言 |
| `JOOX_ROOT_DIR` | `/tmp/joox-downloads` | 音乐下载根目录 |
| `QB_HOST` | `http://localhost` | qBittorrent 地址 |
| `QB_PORT` | `8080` | qBittorrent Web UI 端口 |
| `QB_USER` | `admin` | qBittorrent 用户名 |
| `QB_PASS` | `adminadmin` | qBittorrent 密码 |

建议写入 `~/.bashrc` 或 `~/.zshrc`：
```bash
export JOOX_COOKIE="wmid=xxx; session_key=yyy; ..."
export JOOX_ROOT_DIR="$HOME/Music/joox"
export QB_HOST="http://localhost"
export QB_PORT="8080"
export QB_USER="admin"
export QB_PASS="your_password"
```

---

## search-movie.sh 参数详情

```
命令:
  search "电影名"       搜索电影
  list                  按条件列出电影
  details               查看单部电影详情
  suggestions           查看相关推荐

选项:
  --limit N             返回数量 (1-50，list 默认 10)
  --page N              页码
  --quality VALUE       480p / 720p / 1080p / 1080p.x265 / 2164p / 3D
  --minimum-rating N    最低 IMDb 评分 (0-9)
  --genre VALUE         action / comedy / drama / horror / sci-fi ...
  --sort-by VALUE       title / year / rating / peers / seeds / download_count
  --order-by asc|desc   排序方向
  --movie-id ID         YTS 电影 ID（details/suggestions 必填）
  --imdb-id ID          IMDb ID，如 tt0133093（details 可用）
  --full                输出完整格式化 JSON
  --raw                 输出原始 API 响应
```

输出示例：
```
ID: 12345
Title: The Matrix (1999)
IMDb: tt0133093
Rating: 8.7
URL: https://yts.mx/movies/the-matrix-1999
Torrents:
  质量: 1080p | 编码: x264 | 大小: 2.01 GB | Seeds: 1823 | Peers: 142
  Torrent: https://...
  Magnet:  magnet:?xt=urn:btih:...
```

---

## qbt.sh 参数详情

```
命令:
  add <magnet|url|.torrent文件>   添加下载任务
  list                            列出任务
  pause <hash|all>                暂停
  resume <hash|all>               恢复
  delete <hash> [--with-files]    删除任务
  info <hash>                     查看任务详情
  status                          全局状态
  version                         qBt 版本信息

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

通用选项（优先级高于环境变量）:
  --host HOST           qBt 地址
  --port PORT           端口
  --user USER           用户名
  --pass PASS           密码
```

---

## search-magnet.sh 说明

抓取流程：
1. 请求 `/search?q={keyword}` 获取列表页
2. 提取 `/magnet/[id]` 详情页路径
3. 逐一访问详情页，解析标题、大小、磁力链接
4. 请求间隔 0.3s，避免被封

解析策略：grep + sed 双重备用，单条失败跳过不中断。

---

## download-music.sh 状态输出

脚本输出 Tab 分隔的状态行，可用 awk 解析：

| 状态 | 含义 |
|------|------|
| `START` | 开始处理曲目 |
| `DONE_AUDIO` | 音频下载成功 |
| `SKIP_EXISTS` | 文件已存在，跳过 |
| `FAIL_NO_URL` | 未获取到音频 URL |
| `FAIL_AUDIO` | 音频下载失败 |
| `DONE_LRC` | 歌词下载成功 |
| `NO_LRC` | 无歌词 |
| `DONE_ALBUM` | 专辑全部完成 |

下载目录结构：
```
{JOOX_ROOT_DIR}/
└── {艺术家}/
    └── {专辑名}/
        ├── 曲名.flac
        ├── 曲名.lrc
        └── ...
```

音频 URL 优先级：
```
master_tapeUrl > hiresUrl > flacUrl > r320Url > r192Url > mp3Url > m4aUrl
```

---

## 异常处理

| 场景 | 处理方式 |
|------|---------|
| JOOX Cookie 失效 | 提示用户重新获取并更新 `JOOX_COOKIE` 环境变量 |
| YTS API 不可用 | 提示用户检查网络或通过 `YTS_API_BASE_URL` 切换镜像地址 |
| 磁力搜索站改版 | 提示用户 search-magnet.sh 的 grep/sed 规则可能需要更新 |
| qBt 连接失败 | 先用 `./scripts/qbt.sh status` 检查连接，提示检查 QB_HOST/QB_PORT/凭据 |
| 搜索无结果 | 建议用户换关键词、调整 quality/rating 过滤条件 |
| 下载中断 | download-music.sh 支持断点续传（SKIP_EXISTS 跳过已有文件），直接重跑即可 |

---

## 注意事项

- **JOOX Cookie** 有时效性，失效后需重新获取并更新 `JOOX_COOKIE`
- **QB_PASS** 建议通过环境变量传入，避免明文出现在命令行历史里
- `search-magnet.sh` 依赖目标网站页面结构，站点改版后可能需要调整 grep/sed 规则
- YTS API 为第三方镜像，如不可用可通过 `YTS_API_BASE_URL` 切换地址
- 所有脚本启动时自动检测依赖，缺失时输出安装提示
- qBt session 使用临时 cookie 文件，脚本退出时自动登出清理
