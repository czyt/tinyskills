# 懒猫微服应用发布完整工作流

## 🎯 核心技能总结

### 1. Setup Wizard 配置 (lzc-deploy-params.yml)

**关键规则 - 必须遵守**：
```yaml
# ❌ 错误 - 参数描述用中文
params:
  - id: YUQUE_TOKEN
    name: "语雀 Token"      ← 错误
    description: "API说明"  ← 错误

# ✅ 正确 - 参数描述用英文，中文通过 locales
params:
  - id: YUQUE_TOKEN
    name: "yuque token"     ← 正确（英文）
    description: "API Token for Yuque" ← 正确（英文）

locales:
  zh:
    YUQUE_TOKEN:
      name: "语雀 Token"    ← 中文翻译
      description: "语雀 API Token说明" ← 中文翻译
```

**为什么这样设计？**
- 系统根据用户语言自动切换显示
- `name`/`description` 是基础定义，必须英文
- `locales` 提供多语言翻译
- 支持中文、英文等多种语言

### 2. 镜像复制到懒猫仓库

**命令**：
```bash
lzc-cli appstore copy-image heizicao/yuque-sync:latest
```

**输出示例**：
```
Waiting ... ( copy heizicao/yuque-sync:latest to lazycat offical registry)
lazycat-registry: registry.lazycat.cloud/czyt/heizicao/yuque-sync:8491074e73af38d8
```

**重要规则**：
1. 镜像必须在公网可访问
2. 每次执行都会重新 pull
3. 生成的 tag 基于 IMAGE_ID
4. 必须被应用引用，否则会被垃圾回收

### 3. 自动更新 Manifest

**推荐使用通用脚本**：
```bash
scripts/lzc-release-update.sh 1.2.3 --source-template 'ghcr.io/acme/app:{version}'
```

**多镜像项目必须显式选择 service**：
```bash
scripts/lzc-release-update.sh 1.2.3 --service web --source-template 'ghcr.io/acme/web:{version}'
```

**为什么不能直接 sed 全局替换？**
- `lzc-manifest.yml` 可能包含 `web`、`api`、`worker`、`db` 等多个镜像。
- 全局替换 `image: .*` 会把不该更新的服务一起改掉。
- 安全规则是：单镜像自动；多镜像列出候选项并要求 `--service <name>`。
- 脚本会把选择写入 `.lazycat-release.env`；后续使用记忆值时仍会打印当前更新的 service。

**脚本会自动完成**：
- 调用 fish 中的 `lzc-copy-image <source-image>`，不存在时回退到 `lzc-cli appstore copy-image <source-image>`
- 从 `uploaded:` 或 `lazycat-registry:` 输出中解析 `registry.lazycat.cloud/...`
- 更新 `package.yml` 的顶层 `version`
- 只更新选中 service 的 `image`
- 重新构建 LPK

**重要提示**：复制镜像后必须更新 manifest，更新后必须重新构建 LPK 才会生效。

### 3.1 通用版本更新脚本

文件：`scripts/lzc-release-update.sh`

| 场景 | 命令 |
|------|------|
| 单镜像自动更新 | `scripts/lzc-release-update.sh 1.2.3 --source-template 'ghcr.io/acme/app:{version}'` |
| 多镜像更新指定服务 | `scripts/lzc-release-update.sh 1.2.3 --service worker --source-image ghcr.io/acme/worker:1.2.3` |
| 只验证改写不构建 | `COPY_IMAGE_OUTPUT='uploaded: registry.lazycat.cloud/czyt/acme/worker:abc123' scripts/lzc-release-update.sh 1.2.3 --service worker --source-image ghcr.io/acme/worker:1.2.3 --skip-build` |
| 构建后发布 | `scripts/lzc-release-update.sh 1.2.3 --service worker --publish --changelog '更新到 1.2.3'` |

```bash
scripts/lzc-release-update.sh --help
```

`.lazycat-release.env` 示例：
```env
service=worker
source_template=ghcr.io/acme/worker:{version}
publish=0
lang=zh
```

发布选项：
- 默认不发布。
- `--publish` 才发布，优先调用 fish 函数 `lzc-publish`。
- 没有 `lzc-publish` 时回退到 `lzc-cli appstore publish -c ... --clang zh`。

fish `udf.fish` 中常用函数签名：
```fish
lzc-copy-image <source-image>
lzc-publish <lpk-file> <changelog-message> [lang]
```

### 4. 完整发布流程 (4个阶段)

```
阶段 1: 初始构建（原始镜像）
  ↓
阶段 2: 镜像复制（自动更新 manifest）
  ↓
阶段 3: 重新构建（新镜像）
  ↓
阶段 4: 发布审核
```

**自动化脚本实现**：
```bash
# 阶段 1: 初始构建
build_app  # 使用原始镜像

# 阶段 2: 镜像复制 + 自动更新
copy_image  # 自动更新 manifest

# 阶段 3: 重新构建
build_app  # 使用新镜像

# 阶段 4: 发布
publish_app  # 提交审核
```

### 5. 首次发布 vs 后续更新

| 特性 | 首次发布 | 后续更新 |
|------|---------|---------|
| **命令** | `lzc-cli appstore publish app-1.0.0.lpk` | `lzc-cli appstore publish app-1.0.1.lpk` |
| **结果** | 创建新应用 | 更新现有应用 |
| **版本** | 1.0.0 | 1.0.1, 1.0.2, ... |
| **审核时间** | 1-3 个工作日 | 1-3 个工作日 |
| **应用商店** | 需要创建应用 | 直接更新 |

**首次发布流程**：
```bash
1. lzc-cli appstore login
2. lzc-cli appstore copy-image <image>
3. 更新 manifest 中的镜像地址
4. lzc-cli project build -o app-1.0.0.lpk
5. lzc-cli appstore publish app-1.0.0.lpk
   ↓
   系统提示：创建新应用？
   ↓
   填写应用基本信息
   ↓
   提交审核（1-3天）
```

**后续更新流程**：
```bash
1. 更新 package.yml 中的版本号
   version: 1.0.1  # 从 1.0.0 递增

2. 如果镜像有变化：
   lzc-cli appstore copy-image <新镜像>
   更新 lzc-manifest.yml 中对应 service 的 image

3. 构建并发布
   lzc-cli project build -o app-1.0.1.lpk
   lzc-cli appstore publish app-1.0.1.lpk
   ↓
   自动更新现有应用
   ↓
   提交审核（1-3天）
```

推荐等价脚本：
```bash
scripts/lzc-release-update.sh 1.0.1 \
  --service web \
  --source-template 'ghcr.io/acme/web:{version}' \
  --publish \
  --changelog '更新到 1.0.1'
```

## 📋 完整文件清单

### 核心配置（4个）
```
lzc-manifest.yml          ← 主配置（推荐）
manifest.yml              ← 主配置（兼容）
lzc-deploy-params.yml     ← 设置向导（关键）
lzc-build.yml             ← 构建配置
```

### 自动化工具（2个）
```
build.sh                  ← 完整发布脚本
icon.png                  ← 应用图标（用户自行提供）
```

### 文档（7个）
```
README.md                 ← 完整说明
QUICKSTART.md             ← 快速开始
SUMMARY.md                ← 完成总结
PUBLISH-GUIDE.md          ← 发布指南
PUBLISH-SKILLS.md         ← 发布技能
LAZYCAT-SKILLS.md         ← 所有配置技能
SKILL-LEARNING.md         ← 学习要点
```

## 🎓 关键知识点

### 1. 设置向导工作原理
```
用户安装应用
    ↓
系统读取 lzc-deploy-params.yml
    ↓
弹出图形界面（英文标题 + 中文描述）
    ↓
用户填写参数
    ↓
生成环境变量
    ↓
manifest.yml 通过 {{.U.param_name}} 引用（小写）
    ↓
容器启动获得配置
```

### 2. 镜像复制 + 自动更新
```
lzc-cli appstore copy-image <镜像>
    ↓
获取新地址: registry.lazycat.cloud/...
    ↓
脚本自动执行:
  sed -i "s|image: .*|image: 新地址|" lzc-manifest.yml
    ↓
manifest.yml 自动更新完成
```

### 3. 多语言支持机制
```yaml
params:
  - id: my_param              # 💡 推荐：小写+下划线，易读性好
    name: "my param"        ← 英文（基础）
    description: "Description" ← 英文

locales:
  zh:
    my_param:               # 必须与 params.id 完全一致
      name: "我的参数"      ← 中文翻译
      description: "参数说明"
```

**💡 参数命名建议：**
- ✅ **推荐使用小写**：`yuque_token`, `enable_auto_sync`（易读性好）
- ⚠️ **大写也可用**：`YUQUE_TOKEN`, `ENABLE_AUTO_SYNC`（但不易读）
- 系统根据用户语言自动显示对应翻译

## 🚀 实际应用

### 语雀同步应用配置完成度

| 配置项 | 状态 | 说明 |
|--------|------|------|
| lzc-manifest.yml | ✅ | 完整配置 |
| lzc-deploy-params.yml | ✅ | 7个参数 |
| lzc-build.yml | ✅ | 构建配置 |
| build.sh | ✅ | 自动化脚本 |
| 文档 | ✅ | 7个文档 |
| 发布流程 | ✅ | 完整支持 |

### 可以直接使用
```bash
# 本地使用
./build.sh → 选择 1

# 发布到商店
./build.sh → 选择 4
```

## 💡 最佳实践

### 1. 配置文件
- 使用英文作为基础
- 通过 locales 提供翻译
- 保持格式一致

### 2. 镜像管理
- 必须复制到懒猫仓库
- 脚本自动更新 manifest
- 重新构建确保使用新镜像

### 3. 版本控制
- 语义化版本号
- 每次发布递增
- 记录变更日志

### 4. 发布流程
- 首次：创建应用 + 审核
- 后续：更新应用 + 审核
- 使用自动化脚本

## 📚 参考资料

### 官方文档
- **开发者门户**: https://developer.lazycat.cloud
- **文档仓库**: https://gitee.com/lazycatcloud/lzc-developer-doc
- **应用商店**: https://gitee.com/lazycatcloud/appdb

### 关键页面
- 设置向导规范: `/spec/deploy-params.html`
- 应用发布: `/docs/publish-app.html`
- lzc-cli 文档: `/docs/lzc-cli.html`
- 审核指南: `/docs/store-submission-guide.html`

### 实际项目
- **Yuque Sync**: `/home/czyt/code/lazycat/yuque-sync-lzcapp`
- 包含完整自动化脚本
- 4阶段发布流程实现

---

**技能掌握度**: 100% ✅
**应用状态**: 完整配置 + 发布能力
**学习日期**: 2025-12-25
