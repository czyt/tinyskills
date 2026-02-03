---
name: magnet-search
description: 磁力链接搜索技能。从 cilisousuo.co 搜索资源并提取磁力链接。当用户需要搜索磁力链接、BT种子、搜索资源下载时使用此技能。触发词包括：搜索磁力、找磁力链接、搜资源、找资源、磁力搜索。
---

# 磁力搜索

从 cilisousuo.co 搜索资源并提取磁力链接。

## 使用方法

运行 `scripts/magnet_search.sh`：

```bash
# 基本搜索（默认返回10个结果）
./scripts/magnet_search.sh "关键词"

# 限制结果数量
./scripts/magnet_search.sh "关键词" 5
```

## 输出格式

```
[1] 资源标题
    大小: 1.5 GB
    磁力: magnet:?xt=urn:btih:...

[2] 资源标题2
    大小: 2.0 GB
    磁力: magnet:?xt=urn:btih:...
```

## 工作原理

1. 搜索 `https://cilisousuo.co/search?q=<关键词>`
2. 从结果页提取详情链接 (`/magnet/xxxx`)
3. 访问每个详情页提取磁力链接

## 依赖

- curl
- python3 (用于 URL 编码)
- sed, grep (系统自带)
