---
name: rime-custom
description: Rime 输入法配置定制助手。支持 custom.yaml 覆写、Emoji/OpenCC、模糊拼音、Lua 扩展、多设备同步。覆盖雾凇/白霜/薄荷/万象方案。何时用：用户需要定制输入法配置、修改候选词数量、启用模糊拼音、配置Emoji、添加Lua扩展、导入词库、多设备同步时。触发词：Rime配置、小狼毫、鼠须管、custom.yaml、模糊拼音、辅助码、候选词、词库导入、Rime定制、输入法配置。
---

# Rime 输入法配置定制助手

帮助用户定制 Rime 输入法配置，通过 `custom.yaml` 覆写实现个性化设置，不修改原始方案文件，升级时保留配置。

## TL;DR 快速入口

> ⚡ **新手**：首次配置？→ Step 1 确定方案 → Step 3 直接生成配置 → Step 4 部署
> ⚡ **常见需求**：
> - 候选词数量/外观 → [候选词数量和布局](#候选词数量和布局)
> - 模糊拼音 → [模糊拼音设置](#模糊拼音设置)
> - Emoji → [Emoji 配置](#emoji-配置-opencc)
> - 繁简转换 → [Emoji 配置](#emoji-配置-opencc) 方式二
> - Lua扩展 → [Lua 功能扩展](#lua-功能扩展)
> - 词库导入 → [第三方词库导入](#第三方词库导入)
> - 同步备份 → [多设备同步](#多设备同步)

**完整工作流**: Step 1确定方案 → Step 2确认目录 → Step 3生成配置 → Step 4部署生效

## 快速决策树

```
用户需求 → 快速定位
├── 首次配置/新安装
│   ├── 不确定方案 → Step 1 + 主流方案概览对比表
│   ├── 知道方案 → Step 2确认目录 → Step 3生成配置
│
├── 修改现有配置
│   ├── 基础设置 → 查阅对应章节（候选词/外观/快捷键）
│   ├── 功能配置 → 查阅对应章节（模糊音/Emoji/Lua）
│   └── 高级定制 → 先读 patch-guide.md 理解覆写语法
│
├── 问题排查
│   ├── 部署失败 → 调试与问题排查 → YAML语法检查
│   ├── 配置不生效 → 检查文件名是否匹配方案名
│   └── 其他错误 → 查看日志 + faq.md
│
└── 方案选择建议
    ├── 日常简体输入 → 雾凇 (词库丰富+Emoji)
    ├── 极简纯净风格 → 白霜 (墨奇辅码)
    ├── 新手入门 → 薄荷 (配置简单)
    ├── 繁体/高级定制 → 万象 (7种辅码+语法模型)
```

## MCP 工具（优先使用）

当可用时，优先使用以下 MCP 工具获取信息：

| 工具 | 功能 | 使用场景 |
|------|------|---------|
| `query_oh-my-rime` | 语义搜索薄荷输入法知识库 | 用户提问、配置查询、方案对比 |
| `get_download_links` | 获取客户端和配置包下载链接 | 安装引导、客户端选择 |
| `get_schema_list` | 获取支持的输入方案列表 | 方案选择、推荐合适的输入方案 |
| `get_author_info` | 获取作者信息 | 方案介绍、了解方案背景 |

### MCP 工具调用示例

```
# 用户询问配置问题时
用户："怎么配置模糊拼音？"
→ 调用 query_oh-my-rime({"query": "模糊拼音配置方法"})
→ 返回知识库中的配置说明 + Skill 中的代码示例

# 用户需要安装时
用户："帮我下载鼠须管"
→ 调用 get_download_links({"platform": "macOS"})
→ 返回下载链接 + 安装指引

# 用户选择方案时
用户："哪个方案适合我？"
→ 调用 get_schema_list()
→ 返回方案列表 + Skill 中的对比表
```

---

## 参考文档体系

### 核心知识 (core/)
| 文档 | 内容 | 用途 |
|------|------|------|
| [schema-nodes.md](references/core/schema-nodes.md) | Schema.yaml节点详解 | 理解配置文件结构 |
| [schema-design.md](references/core/schema-design.md) | 方案设计原理 (69KB) | 创建新方案 |
| [spelling-algebra.md](references/core/spelling-algebra.md) | 拼写运算规则 (28KB) | 双拼/模糊音配置 |
| [configuration.md](references/core/configuration.md) | **配置详解** ⭐ | 完整配置参考 |
| [api-development.md](references/core/api-development.md) | librime API 开发 | 程序级扩展 |
| [introduction.md](references/core/introduction.md) | Rime 架构原理 | 了解底层机制 |
| [getting-started.md](references/core/getting-started.md) | 快速入门指南 | 新手入门 |
| [faq.md](references/core/faq.md) | 常见问题解答 | 问题排查 |
| [design-principles.md](references/core/design-principles.md) | 设计理念 | 理解设计哲学 |
| [shared-data.md](references/core/shared-data.md) | 共享数据机制 | 多方案共享 |
| [downloads.md](references/core/downloads.md) | 客户端下载 | 安装指引 |

### 客户端集成 (core/)
| 文档 | 内容 | 用途 |
|------|------|------|
| [squirrel-client.md](references/core/squirrel-client.md) | 鼠须管配置 (macOS) | macOS特定设置 |
| [squirrel-integration.md](references/core/squirrel-integration.md) | 鼠须管集成指南 | macOS深度配置 |
| [weasel-client.md](references/core/weasel-client.md) | 小狼毫配置 (Windows) | Windows特定设置 |
| [weasel-integration.md](references/core/weasel-integration.md) | 小狼毫集成指南 | Windows深度配置 |
| [ibus-integration.md](references/core/ibus-integration.md) | IBus集成 (Linux) | Linux配置 |
| [emacs-integration.md](references/core/emacs-integration.md) | Emacs集成 | Emacs使用 |

### 定制指南 (customization/)
| 文档 | 内容 | 用途 |
|------|------|------|
| [patch-guide.md](references/customization/patch-guide.md) | **Patch语法详解** ⭐ | custom.yaml 覆写 |
| [recipes.md](references/customization/recipes.md) | 配方/食谱 ⭐ | 快速配置模板 |
| [user-manual.md](references/customization/user-manual.md) | 用户操作手册 | 打字/选字/切换 |
| [userdata.md](references/customization/userdata.md) | 用户数据管理 | 同步/备份/词库 |
| [dictionary-pack.md](references/customization/dictionary-pack.md) | 词库打包 | 词库制作发布 |
| [mood-collection.md](references/customization/mood-collection.md) | 懂我心意体验 | 输入体验优化 |

### 方案详解 (schemes/)
| 文档 | 内容 | 用途 |
|------|------|------|
| [rime-ice.md](references/schemes/rime-ice.md) | 雾凇词库设计 (42KB) | 简体拼音配置 |
| [rime-wanxiang.md](references/schemes/rime-wanxiang.md) | 万象完整文档 (94KB) | 辅助码/语法模型 |
| [rime-frost.md](references/schemes/rime-frost.md) | 白霜词频优化 (32KB) | 墨奇辅助码 |
| [mint-guide.md](references/schemes/mint-guide.md) | 薄荷新手指南 | 新手入门教程 |
| [oh-my-rime.md](references/schemes/oh-my-rime.md) | Oh-My-Rime配置包 (52KB) | 薄荷完整方案 |
| [combopinyin.md](references/schemes/combopinyin.md) | 宫保拼音专题 | 并击输入 |

### 原始抓取 (scraped/)
31个原始文档 (~800KB)，包含上述所有内容的未整理版本。

> 📖 **使用策略**：优先查 `rime-knowledge-base.md` 获取摘要，需要深入时查阅分类目录。AI编写配置工具时，应先读 `customization/patch-guide.md` 理解Patch语法，查阅 `customization/recipes.md` 获取配置模板。

---

## 主流方案概览

| 方案 | 特点 | 配置文件 | 适用场景 |
|------|------|---------|---------|
| **雾凇 (rime-ice)** | 简体拼音、词库丰富(100万+)、Emoji、拆字反查 | `rime_ice.schema.yaml` | 日常输入、简体用户 |
| **白霜 (rime-frost)** | 词频优化(745M语料)、纯净、墨奇辅助码 | `rime_frost.schema.yaml` | 极简风格、辅助码爱好者 |
| **薄荷 (rime_mint)** | 简体拼音、新手友好、MCP知识库 | `rime_mint.schema.yaml` | 新手入门 |
| **万象 (wanxiang)** | 繁简混输、语法模型、7种辅助码 | `wanxiang.schema.yaml` | 繁体用户、高级定制 |

> 🔍 选择建议：日常用雾凇/白霜，繁体用万象，新手用薄荷。

---

## 配置工作流 ⚠️

> 🛑 **入口检查点（需求确认）**：开始配置前，先了解用户需求：
> - "您是首次配置还是修改现有配置？"
> - "您需要配置什么功能？（候选词数量、模糊拼音、Emoji、Lua扩展等）"
> - 根据需求快速定位：
>   - 基础设置（候选词/外观）→ Step 3 直接配置
>   - 功能配置（模糊音/Emoji）→ 查阅对应章节
>   - 高级扩展（Lua/词库）→ 先确认方案兼容性

### Step 1: 确定方案 ⚠️

**重要规则**：先查看配置目录中实际的 `schema_id` 和现有 `*.schema.yaml` 文件名，再决定对应的 `*.custom.yaml` 文件名。**不要只按方案中文名猜测文件名**，不同衍生版本可能有不同的命名。

**输入**：用户描述需求或提及方案名
**输出**：确定方案类型，对应 custom.yaml 文件名

询问用户使用的输入方案：

| 用户提及 | 方案 | custom.yaml 文件 |
|---------|------|-----------------|
| "雾凇/冰/雪" | rime-ice | `rime_ice.custom.yaml` |
| "白霜/霜/纯净" | rime-frost | `rime_frost.custom.yaml` |
| "薄荷/Mint" | rime_mint | `rime_mint.custom.yaml` |
| "万象(标准版)" | wanxiang | `wanxiang.custom.yaml` |
| "万象Pro/增强版" | wanxiang_pro | `wanxiang_pro.custom.yaml` |
| "朙月" | luna_pinyin | `luna_pinyin.custom.yaml` |
| "双拼" | double_pinyin | `double_pinyin.custom.yaml` |

> 🛑 **检查点（方案确认）**：确认方案后再继续。不确定时问用户：
> - "您用的是哪个方案？雾凇、白霜、薄荷还是万象？"
> - 如果用户不知道方案名，询问："您是刚安装还是已配置？刚安装请查看当前使用的配置文件名。"
> - 提供决策辅助：
>   - 需要丰富词库+Emoji → 雾凇
>   - 需要纯净+墨奇辅码 → 白霜
>   - 新手入门+简单配置 → 薄荷
>   - 繁简混输+高级定制 → 万象

---

## 方案配置差异详解 ⚠️

不同方案的文件结构、配置方式、功能支持各不相同，修改前务必确认。

### 雾凇拼音 (rime-ice)

| 文件类型 | 文件名 | 说明 |
|---------|-------|------|
| Schema主文件 | `rime_ice.schema.yaml` | 主方案配置，勿直接修改 |
| Custom覆写 | `rime_ice.custom.yaml` | 用户定制配置 |
| 词库文件 | `rime_ice.dict.yaml` | 主词库（100万+词条） |
| 扩展词库 | `rime_ice.ext.dict.yaml` | 扩展词条 |
| Emoji映射 | `opencc/emoji.json` | Emoji自动映射 |

**特有功能配置**：
- 拆字反查：`uU` + 拼音（方案内置，无需配置）
- 以词定字：配置 `engine/translators` 添加 `select_words`
- 特殊符号：`v` + 缩写（全拼）/ `V` + 缩写（双拼）

**配置示例**：
```yaml
# rime_ice.custom.yaml - 雾凇专用配置
patch:
  # 模糊音（雾凇内置模糊音开关，无需手动配置）
  # 'speller/algebra' 仅用于自定义拼写规则

  # 以词定字
  'engine/translators/@next': select_words

  # 词库扩展
  'translator/dictionary': rime_ice.ext
```

### 白霜拼音 (rime-frost)

| 文件类型 | 文件名 | 说明 |
|---------|-------|------|
| Schema主文件 | `rime_frost.schema.yaml` | 主方案配置 |
| Custom覆写 | `rime_frost.custom.yaml` | 用户定制配置 |
| 词库文件 | `rime_frost.dict.yaml` | 词频优化词库 |
| 墨奇辅码 | `moqi.dict.yaml` | 辅助码映射 |

**特有功能配置**：
- 墨奇辅助码：按 `` ` `` 开启（方案内置）
- 符号扩展：`/fh` `/yd` 等（通过 `punctuator/symbols` 配置）
- 日期时间：`rq` `sj` `xq` 直接输入

**配置示例**：
```yaml
# rime_frost.custom.yaml - 白霜专用配置
patch:
  # 辅码相关配置已内置，一般无需修改

  # 自定义符号
  'punctuator/symbols':
    "/my": ["自定义符号1", "自定义符号2"]
```

### 万象拼音 (wanxiang)

万象有两个主要版本：

**标准版 (Standard)**：
| 文件类型 | 文件名 | 说明 |
|---------|-------|------|
| Schema主文件 | `wanxiang.schema.yaml` | 主方案（含多种双拼） |
| Custom覆写 | `wanxiang.custom.yaml` | 用户定制配置 |
| 语法模型 | `grammar.bin` | kenlm语言模型（需单独下载） |

**Pro增强版**：
| 文件类型 | 文件名 | 说明 |
|---------|-------|------|
| Schema主文件 | `wanxiang_pro.schema.yaml` | 仅支持双拼，含7种辅助码 |
| Custom覆写 | `wanxiang_pro.custom.yaml` | 用户定制配置 |
| 辅码文件 | `aux_code.dict.yaml` | 辅助码映射 |
| 反查库 | `reverse.dict.yaml` | 拼音反查 |

**特有功能配置**：
- 7种辅助码：墨奇、鹤形、自然、虎码、五笔、汉心、首右
- 方案切换指令：`/flypy` `/mspy` `/zrm` `/sogou` `/pinyin`
- 语法模型：需下载 `grammar.bin` 放入用户目录
- 声调辅助：`7890` 代表 `1234` 声

**配置示例**：
```yaml
# wanxiang.custom.yaml - 万象专用配置
patch:
  # 切换默认双拼方案（万象内置切换指令，此处仅设置默认）
  wanxiang_lookup:
    key: "`"  # 辅码触发键

  # 语法模型路径（需先下载grammar.bin）
  grammar_translator:
    model: grammar.bin
```

**特殊指令**（输入状态直接输入）：
```
/flypy   → 切换小鹤双拼
/mspy    → 切换微软双拼
/zrm     → 切换自然码
/sogou   → 切换搜狗双拼
/pinyin  → 切换全拼
```

### 薄荷输入法 (rime_mint)

> **注意**：此处以 Mintimate/oh-my-rime 官方 upstream 当前命名为准。不同薄荷衍生包可能使用不同文件名（如早期版本使用 `mint.schema.yaml`），请先查看实际文件确认。

| 文件类型 | 文件名 | 说明 |
|---------|-------|------|
| Schema主文件 | `rime_mint.schema.yaml` | 主方案配置 |
| Custom覆写 | `rime_mint.custom.yaml` | 用户定制配置 |

**特点**：
- 新手友好，配置简单
- 支持 MCP 知识库查询（薄荷官方提供）
- 基础功能齐全，适合入门

**配置示例**：
```yaml
# rime_mint.custom.yaml - 薄荷专用配置
patch:
  "menu/page_size": 7
  "style/color_scheme": native
```

### 朙月拼音 (luna_pinyin)

| 文件类型 | 文件名 | 说明 |
|---------|-------|------|
| Schema主文件 | `luna_pinyin.schema.yaml` | 官方默认方案 |
| Custom覆写 | `luna_pinyin.custom.yaml` | 用户定制配置 |
| 词库文件 | `luna_pinyin.dict.yaml` | 繁体词库 |
| 自定义短语 | `custom_phrase.txt` | 用户短语（Tab分隔） |

**特有功能配置**：
- 繁简转换：通过 `simplifier` + OpenCC 配置
- 自定义短语：创建 `custom_phrase.txt` 文件

**配置示例**：
```yaml
# luna_pinyin.custom.yaml - 朙月专用配置
patch:
  # 简体输出
  switches/@next:
    name: zh_simp
    reset: 1
    states: ["漢字", "汉字"]

  'simplifier/opencc_config': t2s.json
```

### 双拼方案

| 方案 | Schema文件 | 特点 |
|------|-----------|------|
| 自然码 | `double_pinyin.schema.yaml` | 经典双拼 |
| 小鹤双拼 | `double_pinyin_flypy.schema.yaml` | 常用双拼 |
| 微软双拼 | `double_pinyin_mspy.schema.yaml` | Windows内置 |

**配置差异**：
- 双拼方案共享朙月拼音词库
- 通过 `speller/algebra` 定义双拼映射
- 模糊音配置与全拼不同（作用于双拼编码）

---

### 方案配置冲突处理 ⚠️

> 🛑 **检查点（冲突确认）**：涉及多方案或方案切换时，先确认：
> - "您是要切换方案还是在现有方案上配置？"
> - 切换方案 → 提醒可能需要重新配置 custom.yaml
> - 配置现有方案 → 确认文件名匹配方案名

⚠️ **多方案共存时的注意事项**：

1. **custom.yaml 文件名必须匹配方案名**
   - 雾凇用 `rime_ice.custom.yaml`，不是 `default.custom.yaml`
   - 白霜用 `rime_frost.custom.yaml`
   - 错误文件名会导致配置不生效

2. **default.custom.yaml 仅用于全局设置**
   ```yaml
   # default.custom.yaml - 全局配置（所有方案共用）
   patch:
     schema_list:
       - schema: rime_ice      # 默认方案
       - schema: luna_pinyin
       - schema: double_pinyin
   ```

3. **方案切换需重新部署**
   - 修改任何 custom.yaml 后必须「重新部署」
   - 切换方案指令（万象）也需要部署生效

4. **词库文件不可混用**
   - 雾凇词库与朙月词库编码格式不同
   - 白霜词库与万象词库辅码格式不同
   - 导入词库需确认与当前方案兼容

---

### Step 2: 确认配置目录

**输入**：用户操作系统
**输出**：配置目录路径

| 平台 | 客户端 | 配置目录 |
|------|-------|---------|
| Windows | 小狼毫 | `%APPDATA%\Rime\` |
| macOS | 鼠须管 | `~/Library/Rime/` |
| Linux (IBus) | 中州韵 | `~/.config/ibus/rime/` |
| Linux (Fcitx5) | 中州韵 | `~/.local/share/fcitx5/rime/` |
| Android | 同文/fcitx5 | `/rime` 或 `.../data/rime` |
| iOS | 仓输入法 | 应用内文件管理 |

### Step 3: 创建/修改 custom.yaml ⚠️

**输入**：方案名、用户需求
**输出**：custom.yaml 配置内容

> 🛑 **检查点（备份确认）**：修改现有配置前，先询问用户：
> - "您是否已有 custom.yaml 文件？如有，建议先备份。"
> - "这是首次配置还是修改现有配置？"
> - 首次配置 → 直接生成配置文件
> - 修改现有 → 先读取现有配置，确认修改位置

```yaml
# 示例：rime_ice.custom.yaml
patch:
  "menu/page_size": 9  # 候选词数量
```

> 🛑 **检查点（配置预览）**：复杂配置前，先向用户展示完整配置预览，确认："这个配置符合您的需求吗？修改后需要重新部署才能生效。"

### Step 4: 部署生效 ⚠️

**输入**：配置文件已修改
**输出**：部署成功确认

> 🛑 **检查点（部署确认）**：部署前确认：
> - "配置文件已保存，现在可以部署。是否继续？"
> - 提示用户：部署可能需要几秒钟，期间输入法不可用
> - 如有多个方案切换，提醒用户"部署后会切换到默认方案"

修改后需要重新部署：
1. 右键托盘图标
2. 选择「重新部署」或「部署」
3. 等待编译完成

**异常处理**：
- 部署失败 → 检查 YAML 语法（空格缩进，不用 Tab）
- 候选未变化 → 确认 custom.yaml 在正确目录
- 日志报错 → 查看日志定位问题：
  - Windows: `%TEMP%\rime.*.log`
  - macOS: `$TMPDIR/rime.squirrel.*`
  - Linux: `/tmp/rime.ibus.*`

---

## 配置覆写和定制

### custom.yaml 基础结构

```yaml
patch:
  # 所有覆写配置放在 patch 节点下
  "key/path": value
```

### 覆写语法

```yaml
# 覆写单个值
patch:
  "menu/page_size": 9

# 覆写数组元素（追加）
patch:
  "engine/translators/@next": emoji_translator

# 覆写数组元素（插入到指定位置）
patch:
  "engine/filters/@before 0": simplifier

# 删除数组元素
patch:
  "engine/translators/@before 0": null

# 覆写嵌套对象
patch:
  "speller/algebra":
    - derive/^([zcs])h/$1/
```

---

## 自定义默认激活方案

### 设置默认方案

```yaml
patch:
  # 方案列表
  schema_list:
    - schema: rime_ice        # 雾凇（默认）
    - schema: luna_pinyin     # 朙月拼音
    - schema: double_pinyin   # 双拼

  # 默认激活（方案列表第一个）
```

### 方案切换快捷键

```yaml
patch:
  "switcher/hotkeys":
    - "Control+Shift+1"
    - "Control+Shift+2"
```

---

## Emoji 配置 (OpenCC)

> **重要**：Emoji 功能通过 `engine/filters` 实现，添加方式取决于方案已有的 filter 配置。常见形式为 `simplifier@emoji` 或 `simplifier@emoji_suggestion`。请先查看方案原 `*.schema.yaml` 中的 `engine/filters` 配置，再决定 patch 写法。

### 方式一：在已有 simplifier filter 上添加 Emoji

如果方案已有 `simplifier` filter（如雾凇、白霜），可直接追加 Emoji：

```yaml
patch:
  # 在现有 filters 中追加 Emoji（使用 @next 在末尾添加）
  'engine/filters/@next': simplifier@emoji
  
  # 或在指定位置插入
  'engine/filters/@before 0': simplifier@emoji_suggestion
  
  # Emoji OpenCC 配置
  'simplifier@emoji/opencc_config': emoji.json
  'simplifier@emoji/tips': all
```

### 方式二：添加新的 Emoji filter

如果方案没有 Emoji filter，需完整配置：

```yaml
patch:
  # 添加 Emoji filter 到 filters 列表
  'engine/filters/@next': simplifier@emoji
  
  # Emoji 配置
  simplifier@emoji:
    opencc_config: emoji.json
    option_name: emoji
    tips: all  # 显示 Emoji 提示

### 方式二：OpenCC 繁简转换

```yaml
patch:
  # 添加简体开关
  switches/@next:
    name: zh_simp
    reset: 1  # 默认简体
    states: ["漢字", "汉字"]

  # 启用简化器
  'engine/filters/@next': simplifier

  # OpenCC 配置
  'simplifier/opencc_config': s2t.json  # 简转繁
  # 或 t2s.json 繁转简
  # 或 s2tw.json 简转台湾繁体
```

### 常用 OpenCC 配置文件

| 配置文件 | 功能 |
|---------|------|
| `s2t.json` | 简体 → 繁体 |
| `t2s.json` | 繁体 → 简体 |
| `s2tw.json` | 简体 → 台湾繁体 |
| `t2tw.json` | 繁体 → 台湾繁体 |
| `emoji.json` | Emoji 映射 |

---

## 模糊拼音设置

### 常用模糊音配置

```yaml
patch:
  'speller/algebra':
    # 基础规则
    - erase/^xx$/                      # 去掉拼音 xx
    - abbrev/^([a-z]).+$/$1/           # 简拼（首字母）
    - abbrev/^([zcs]h).+$/$1/          # 声母简拼

    # 模糊音
    - derive/^([zcs])h/$1/             # zh/ch/sh → z/c/s
    - derive/([zcs])h$/$1/             # zh/ch/sh → z/c/s（反向）

    - derive/([aei])n$/$1ng/           # en → eng
    - derive/([aei])ng$/$1n/           # eng → en

    - derive/in$/ing/                  # in → ing
    - derive/ing$/in/                  # ing → in

    - derive/an$/ang/                  # an → ang
    - derive/ang$/an/                  # ang → an

    - derive/([iu])an$/$1ian/          # uan → üan
    - derive/([iu])ang$/$1an/          # uang → an

    - derive/l/n/                      # l → n
    - derive/n/l/                      # n → l

    - derive/f/h/                      # f → h
    - derive/h/f/                      # h → f

    - derive/([iu])v$/$1u/             # v → u/ü

    # 前后鼻音（可选）
    - derive/eng$/en/                  # eng → en
    - derive/en$/eng/                  # en → eng
```

### 模糊音开关（方案支持时）

```yaml
patch:
  switches/@next:
    name: fuzzy_correction
    reset: 1  # 默认开启
    states: ["精准", "模糊"]
```

---

## 设置语言模型

> **推荐**：万象、雾凇、白霜、薄荷等现代方案通过 `grammar` 配置实现语法模型支持，这是当前主流方式。

### 现代主流配置（推荐）

```yaml
patch:
  # 语法模型配置（主流方式）
  grammar:
    language: grammar.bin  # 语言模型文件
  
  # 相关可选配置
  grammar/collocation_max_length: 4  # 搭配词最大长度
  grammar/collocation_min_length: 2  # 搭配词最小长度
  
  # 上下文建议（部分方案支持）
  translator/contextual_suggestions: true
  translator/max_homophones: 5  # 同音字最大数量
  translator/max_homographs: 5  # 同形字最大数量
```

### 旧式 grammar_translator 配置（特定方案可用）

> ⚠️ **注意**：以下 `grammar_translator` 配置是旧式写法，不是当前万象/雾凇/白霜/薄荷的主流 patch 方式。仅适用于特定方案或旧版本，新用户建议使用上述 `grammar/language` 配置。

```yaml
patch:
  # 添加语法翻译器（旧式）
  'engine/translators/@next': grammar_translator

  # 语法分析器配置
  grammar_translator:
    type: grammar
    grammar:
      model: grammar.bin  # 语言模型文件
```

### 词库扩展

```yaml
patch:
  # 扩展词库（雾凇方案）
  'translator/dictionary': rime_ice.ext

  # 或自定义词库
  'translator/dictionary': custom_dict
```

### 创建自定义词库

在配置目录创建 `custom_dict.dict.yaml`：

```yaml
---
name: custom_dict
version: "1.0"
sort: by_weight
---
# 自定义词条
你好	ni hao	100
世界	shi jie	100
```

---

## 符号输入配置

### 快捷符号映射

```yaml
patch:
  # 符号映射
  punctuator:
    full_shape:
      "," : ["，", "、"]
      "." : ["。", "．"]
      "?" : ["？", "？"]
      ";" : ["；", "；"]
      ":" : ["：", "："]
      "!" : ["！", "！"]
    half_shape:
      "," : ["，", "、"]
      "." : ["。", "."]
```

### 特殊符号输入

```yaml
patch:
  # 通过 / 开头输入符号
  'recognizer/patterns/punct': "^/[a-z]*$"

  # 符号方案
  'punctuator/symbols':
    "/star": ["★", "☆", "✦", "✧"]
    "/heart": ["♥", "♡", "❤", "❥"]
    "/arrow": ["→", "←", "↑", "↓", "↔"]
    "/math": ["+", "-", "×", "÷", "="]
    "/check": ["✓", "✔", "✕", "✖"]
```

---

## Lua 功能扩展 ⚠️

> 🛑 **检查点（Lua调试提醒）**：启用Lua扩展前，确认：
> - "Lua脚本出错会导致输入法崩溃，建议先在测试环境验证。"
> - "Lua文件修改后也需要重新部署才能生效。"
> - 提供调试方法：查看日志中的Lua错误信息

### lua_filter（候选过滤）

在配置目录创建 `rime.lua`：

```lua
-- 候选词过滤：添加序号
function filter_candidate_number(input, env)
  for cand in input:iter() do
    cand.text = cand.text .. " [" .. cand.preedit .. "]"
    yield(cand)
  end
end

-- 候选词过滤：时间戳
function time_filter(input, env)
  for cand in input:iter() do
    if cand.text == "time" then
      cand.text = os.date("%H:%M:%S")
    end
    yield(cand)
  end
end
```

在 custom.yaml 中启用：

```yaml
patch:
  'engine/filters/@next': lua_filter@filter_candidate_number
```

### lua_processor（按键处理）

```lua
-- 按键处理：快捷输入
function date_processor(key, env)
  if key:repr() == "Control+d" then
    local ctx = env.engine.context
    ctx.input = os.date("%Y-%m-%d")
    return 1  -- 已处理
  end
  return 2  -- 未处理
end
```

在 custom.yaml 中启用：

```yaml
patch:
  'engine/processors/@next': lua_processor@date_processor
```

### lua_translator（翻译器）

```lua
-- 时间日期翻译
function time_translator(input, seg, env)
  if input == "time" then
    yield(Candidate("time", seg.start, seg._end, os.date("%H:%M:%S"), "时间"))
  end
  if input == "date" then
    yield(Candidate("date", seg.start, seg._end, os.date("%Y-%m-%d"), "日期"))
  end
end
```

在 custom.yaml 中启用：

```yaml
patch:
  'engine/translators/@next': lua_translator@time_translator
```

### Lua 进阶功能（万象特色）

万象拼音通过 Lua 实现了多项创新功能，可作为高级定制参考：

| 功能 | 快捷键 | 说明 |
|------|--------|------|
| 手动排序 | Ctrl+J/K/L/P | 调整候选顺序，数据存于 `sequence.userdb` |
| 输入统计 | `/ztj` `/ytj` `/ntj` `/rtj` `/tj` | 实时统计输入数据 |
| 翻译模式 | Ctrl+E | 中英文互译（需词表支持） |
| 声调显示 | Ctrl+S | 输入码动态显示全拼+音调 |
| 模式切换 | Shift+Space | 中文/英文/混合模式切换 |

**手动排序示例**：
```lua
-- 万象手动排序核心逻辑（简化版）
-- Ctrl+J: 下移候选
-- Ctrl+K: 上移候选
-- Ctrl+L: 置顶候选
-- Ctrl+P: 恢复原位

function sequence_processor(key, env)
  local ctx = env.engine.context
  if key:repr() == "Control+j" then
    -- 下移当前候选
    local selected = ctx:get_selected_candidate()
    -- 更新排序数据库...
    return 1
  end
  return 2
end
```

**Tips扩展提示**：
```lua
-- 化学式、翻译、表情等提示
-- 数据存于 tips.userdb
-- 用户按 `,` 上屏提示内容

function tips_translator(input, seg, env)
  -- 从 tips.userdb 查询提示内容
  local tips_db = env.engine.user_db:get("tips")
  local tip = tips_db:lookup(input)
  if tip then
    yield(Candidate("tips", seg.start, seg._end, tip, "提示"))
  end
end
```

**快符Lua（字母+/快速上屏）**：
```yaml
# 快符配置
patch:
  'engine/translators/@next': lua_translator@quick_symbol
  
# 使用：输入字母后按 / 直接上屏
# 如：a/ → 上屏 a，避免选字
```

---

## 第三方词库导入 ⚠️

> 🛑 **检查点（词库兼容性）**：导入词库前，确认：
> - "词库文件编码必须是UTF-8(no BOM)，格式需与方案匹配。"
> - "不同方案的词库格式不同，雾凇词库不能直接用于朙月方案。"
> - "导入前建议先备份现有词库。"
> - 询问用户："您要导入的词库是哪个方案的？是否确认格式兼容？"

### 词库文件格式

Rime 词库文件格式（`.dict.yaml`）：

```yaml
---
name: 词库名            # 必须与文件名一致
version: "版本号"
sort: by_weight        # 按权重排序 | original 按原序
columns:               # 列定义（可选）
  - text               # 词条
  - code               # 编码
  - weight             # 权重
import_tables:         # 导入子词库（可选）
  - sub_dict_name
---
# 词条内容：文字<Tab>编码<Tab>权重
你好	ni hao	100
世界	shi jie	50
```

### 导入词库步骤

**方法一：扩展词库（推荐）**

```yaml
# 在主方案的 .dict.yaml 中导入
---
name: rime_ice
import_tables:
  - rime_ice.ext       # 扩展词库
  - my_custom_dict     # 自定义词库
---
```

**方法二：完全替换词库**

将新词库命名为 `luna_pinyin.dict.yaml`（或其他方案名），放入用户文件夹，重新部署即可完全替换。

> ⚠️ 替换会覆盖原词库，谨慎操作。

**方法三：导入到用户词典**

```bash
# 使用 rime_dict_manager 工具
# 1. 关闭输入法
# 2. 进入用户文件夹
# 3. 执行导入命令
rime_dict_manager --import luna_pinyin my_dict.txt
```

### 词库格式转换要点

| 检查项 | 要求 | 转换方法 |
|--------|------|---------|
| 编码格式 | UTF-8 (no BOM) | `:set fenc=utf8 nobomb` (Vim) |
| 行分隔 | 制表符 (Tab) | 正则替换或脚本转换 |
| 字形一致 | 繁/简与源词库一致 | OpenCC 转换 |
| 编码形式 | 标准形式（非简拼） | 拼写运算生成 |

**Vim 转换命令**：
```vim
:set fenc=utf8 nobomb ff=unix
```

### 自定义短语 (custom_phrase.txt)

```txt
# 格式：词条<Tab>编码<Tab>权重（可选）
的	d		# 非完整编码，可参与造词
邮箱	vmail		# 完整编码，置顶显示

# ⚠️ 完整编码会阻止造词，建议使用非完整编码
```

---

## 调试与问题排查 ⚠️

> 🛑 **检查点（问题诊断）**：遇到问题时，先确认：
> - "您是在哪个步骤遇到问题？部署前/部署时/部署后？"
> - "是否有错误提示或日志信息？"

### 日志位置

| 平台 | 日志路径 |
|------|---------|
| Windows | `%TEMP%\rime.weasel.*.log` |
| macOS | `$TMPDIR/rime.squirrel.*.log` |
| Linux | `/tmp/rime.ibus.*.log` 或 `/tmp/rime.fcitx.*.log` |

### 部署失败处理流程

**Step 1: 检查 YAML 语法**
```bash
# Python 快速验证 YAML
python3 -c "import yaml; yaml.safe_load(open('rime_ice.custom.yaml'))"

# 如果报错，常见问题：
# 1. 缩进错误（必须用空格，不能用Tab）
# 2. 引号未闭合
# 3. key/value 格式错误（缺少冒号或空格）
```

**Step 2: 检查文件名匹配**
```
常见错误：文件名不匹配方案名
- 雾凇用 rime_ice.custom.yaml，不是 custom.yaml
- 白霜用 rime_frost.custom.yaml
- 检查文件是否在正确目录
```

**Step 3: 查看日志错误**
```
日志关键字：
- ERROR: 严重错误，必须修复
- WARNING: 警告，可能影响功能
- 搜索关键词：custom.yaml 文件名

Windows: 用 %TEMP% 打开临时文件夹，搜索 rime.weasel
macOS: 终端执行 open $TMPDIR 查看日志
Linux: cat /tmp/rime.ibus.*.log | grep ERROR
```

**Step 4: 回滚配置**
```
如果无法修复，回滚到备份版本：
1. 删除/移除问题配置文件
2. 恢复备份文件（如有）
3. 或删除 custom.yaml 恢复默认
4. 重新部署确认基础功能正常
```

### 常见错误诊断表

| 错误现象 | 可能原因 | 解决方案 |
|----------|----------|---------|
| 部署失败 | YAML 语法错误 | 检查缩进（用空格，不用Tab） |
| 候选未变化 | custom.yaml 文件名错误 | 确认文件名匹配方案名 |
| 配置不生效 | 未重新部署 | 右键托盘 → 重新部署 |
| 词库不加载 | 编码格式错误 | 转换为 UTF-8 (no BOM) |
| 候选闪退 | Lua 脚本错误 | 检查 rime.lua 语法 |
| 内存占用高 | 词库过大 | 禁用不必要的词库 |

### YAML 语法检查

```bash
# Python 快速验证 YAML
python3 -c "import yaml; yaml.safe_load(open('rime_ice.custom.yaml'))"
```

### 部署调试技巧

1. **逐步验证**：先部署最小配置，确认生效后逐步添加
2. **日志分析**：查看日志中的 `ERROR` 和 `WARNING` 行
3. **隔离测试**：删除疑似问题配置，确认是否该配置导致
4. **版本回退**：保留配置备份，出问题时快速恢复

### 首次配置完整流程

**场景：新安装用户首次配置**

```
Step 1: 确认方案（如不知道，先查看配置目录文件名）
Step 2: 确认配置目录（根据平台）
Step 3: 创建最小配置（先测试基础功能）
  ┌─────────────────────────────────┐
  │ patch:                          │
  │   "menu/page_size": 5           │  ← 最小配置测试
  └─────────────────────────────────┘
Step 4: 部署测试
  - 部署成功 → 基础功能正常，可继续添加配置
  - 部署失败 → 检查 YAML 语法和文件名
Step 5: 逐步添加功能（模糊音、Emoji等）
```

**迁移场景：从其他输入法迁移**

| 来源 | 建议方案 | 迁移要点 |
|------|---------|---------|
| 搜狗拼音 | 雾凇 | 词库格式不同，需转换后导入 |
| 百度拼音 | 雾凇 | 同上 |
| 微软拼音 | 雾凇/白霜 | Windows双拼可用万象切换 |
| 手心输入法 | 雾凇 | 同搜狗 |

> ⚠️ **迁移提醒**：
> - 其他输入法词库不能直接导入，需转换格式
> - 用户词频/习惯无法迁移，需重新积累
> - 推荐使用官方词库或雾凇扩展词库

### 配置备份建议

```bash
# 备份用户配置
tar -czf rime_backup_$(date +%Y%m%d).tar.gz \
  *.custom.yaml *.dict.yaml rime.lua custom_phrase.txt

# 或使用 git 管理
cd ~/Library/Rime  # 或对应配置目录
git init
git add *.custom.yaml *.dict.yaml rime.lua
git commit -m "backup"
```

---

## 辅助码系统（万象/白霜）

万象拼音和白霜拼音支持辅助码，通过部首或字形快速筛选候选。

### 墨奇辅助码（白霜）

触发方式：按 `` ` ``（Tab上方的键）开启辅助码模式

```yaml
# 白霜辅助码启用（方案已内置）
patch:
  # 无需额外配置，直接使用
```

**使用示例**：
- 输入 `ni` → 候选"你、尼、拟..."
- 按 `` ` `` 再按 `r`（人字旁）→ 精选带"人"的字
- 按 `` `re`` → 更精准筛选

### 万象辅助码（PRO版）

万象支持 7 种辅助码：墨奇码、鹤形、自然码、虎码、五笔、汉心、首右

**直接辅助码**（双拼+辅码）：
- 示例：`vfj` = `vf`(镇的双拼) + `j`(金字旁声母)
- 聚拢：末尾加 `/` 强制单字优先，如 `vfj/`

**间接辅助码**（拼音/辅码）：
- 示例：`ni/re` = "你"字拼音 + 辅码
- 不干扰整句切分

**声调辅助**（万象特色）：
- `7890` 代表 `1234` 声
- 示例：`ni9` → 第一声，`ni0` → 第四声

```yaml
# 万象辅助码配置（PRO版）
patch:
  wanxiang_lookup:
    tags: [abc]
    key: "`"
    lookup: [wanxiang_reverse]
    data_source: [aux, db]  # aux=词库辅码, db=反查库
```

### 辅码切换指令（万象）

在输入状态输入 `/` 指令切换方案：

```
/flypy   → 小鹤双拼
/mspy    → 微软双拼  
/zrm     → 自然码
/sogou   → 搜狗双拼
/pinyin  → 全拼
```

切换后需**重新部署**生效。

---

## 语法模型（万象）

万象支持 kenlm 语法模型，提升整句预测准确度。

### 安装方法

1. 下载语法模型文件（`grammar.bin`）
2. 放置于 Rime 用户文件夹根目录
3. 无需额外配置，自动加载

**Android 注意事项**：
- Fcitx5 数据在系统 `/data` 目录
- 使用输入法自带"导入文件"功能
- 直接复制可能导致权限错误

---

## 快速功能速查

| 需求 | 方案 | 触发方式 |
|------|------|---------|
| Emoji | 雾凇/万象 | 自动或 `emoji_suggestion` |
| 拆字反查 | 雾凇 | `uU` + 拼音 |
| 辅助码 | 白霜/万象 | `` ` `` + 辅码 |
| Unicode | 全方案 | `U` + 码位（如 `U62fc`=拼） |
| 数字大写 | 全方案 | `R` + 数字 |
| 农历 | 雾凇/万象 | `N` + 8位数字 |
| 计算器 | 雾凇 | `cC` + 算式 / 万象 `V` + 算式 |
| 特殊符号 | 雾凇 | `v` + 缩写 / 万象 `/sx` |
| 日期时间 | 白霜 | `rq` `sj` `xq` / 万象 `/rq` `/sj` |
| 方案切换 | 万象 | `/flypy` `/mspy` 等 |

---

## 输入法快捷键

### 常用快捷键配置

```yaml
patch:
  # 候选选择键（1234567890）
  "key_binder/bindings":
    - {accept: "0", send: "0", when: has_menu}
    - {accept: "1", send: "1", when: has_menu}
    - {accept: "2", send: "2", when: has_menu}

    # 分页
    - {accept: "Page_Up", send: "Page_Up", when: composing}
    - {accept: "Page_Down", send: "Page_Down", when: composing}

    # 翻页（-, =）
    - {accept: "-", send: "Page_Up", when: has_menu}
    - {accept: "=", send: "Page_Down", when: has_menu}

    # 翻页（Tab, Shift+Tab）
    - {accept: "Tab", send: "Page_Down", when: has_menu}
    - {accept: "Shift+Tab", send: "Page_Up", when: has_menu}

    # 回车确认
    - {accept: "Return", send: "Return", when: has_menu}

    # ESC 清空
    - {accept: "Escape", send: "Escape", when: composing}

    # 删除
    - {accept: "BackSpace", send: "BackSpace", when: composing}

    # 方案切换
    - {accept: "Control+Shift+1", toggle: zh_simp, when: always}
    - {accept: "Control+Shift+2", toggle: ascii_mode, when: always}
```

### 功能开关快捷键

```yaml
patch:
  "key_binder/bindings":
    # 简繁切换
    - {accept: "Control+Shift+1", toggle: zh_simp, when: always}

    # 中英文切换
    - {accept: "Shift_L", toggle: ascii_mode, when: always}
    - {accept: "Shift_R", toggle: ascii_mode, when: always}

    # 全半角切换
    - {accept: "Control+Shift+3", toggle: full_shape, when: always}
```

---

## 输入个性定制

### 外观主题

```yaml
patch:
  "style/color_scheme": native      # 主题名
  "style/horizontal": true          # 横向候选栏
  "style/font_face": "Microsoft YaHei"  # 字体
  "style/font_point": 14            # 字号
  "style/inline_preedit": true      # 内嵌预编辑
  "style/display_tray_icon": true   # 显示托盘图标
```

### 常用主题（鼠须管）

| 主题名 | 说明 |
|-------|------|
| `native` | 系统原生风格 |
| `aqua` | 水蓝色 |
| `ink` | 墨色 |
| `dark` | 深色模式 |
| `light` | 亮色模式 |

### 候选词数量和布局

```yaml
patch:
  "menu/page_size": 9           # 候选词数量（通常 5-10）
  "menu/alternative_select_keys": "1234567890"  # 选择键
```

---

## 多设备同步

### 同步机制

Rime 使用 Git 仓库同步配置和词库。

### 配置同步

在配置目录创建 `sync.conf`（或 `user.yaml` 中的 sync 配置）：

```yaml
# sync.conf
sync:
  user_id: "your_device_name"  # 设备标识
  repository: "your_git_repo"  # Git 仓库地址（可选）
```

### 同步命令

```bash
# 小狼毫（Windows）
右键托盘 → 同步用户数据

# 鼠须管（macOS）
偏好设置 → 同步

# 或手动
rime_dict_manager --sync
```

### 同步内容

| 内容 | 说明 |
|------|------|
| `user.yaml` | 用户配置 |
| `*.custom.yaml` | 定制配置 |
| `*.userdb.kct*` | 用户词库 |
| `build/*.reverse.bin` | 反查词典 |

### 同步工作流

```yaml
patch:
  # 启用同步（方案支持时）
  "translator/enable_user_dict": true  # 启用用户词库
```

---

## 部署流程

修改任何配置后都需要重新部署：

1. **Windows（小狼毫）**：右键托盘 → 重新部署
2. **macOS（鼠须管）**：偏好设置 → 部署
3. **Linux（中州韵）**：重启 IBus/Fcitx5 或运行 `rime_deployer --build`

### 部署日志

如遇问题，查看日志：
- Windows: `%TEMP%\rime.*.log`
- macOS: `$TMPDIR/rime.*.log`
- Linux: `/tmp/rime.*.log`

---

## 快速配置模板

### 雾凇基础定制

```yaml
# rime_ice.custom.yaml
patch:
  "menu/page_size": 9
  "style/horizontal": true

  # 简繁开关
  switches/@next:
    name: zh_simp
    reset: 1
    states: ["漢字", "汉字"]

  # 模糊拼音
  'speller/algebra/@before 0':
    - derive/^([zcs])h/$1/
    - derive/([aei])n$/$1ng/

  # Emoji（在 filters 中添加）
  'engine/filters/@next': simplifier@emoji
  'simplifier@emoji/opencc_config': emoji.json
```

### 薄荷基础定制

```yaml
# rime_mint.custom.yaml
patch:
  "menu/page_size": 7
  "style/color_scheme": native

  # 快捷键
  "key_binder/bindings":
    - {accept: "Tab", send: "Page_Down", when: has_menu}
    - {accept: "Shift_L", toggle: ascii_mode, when: always}
```

---

## 参考资料

| 来源 | 链接 |
|------|------|
| 官方Wiki | https://github.com/rime/home/wiki |
| Schema配置详解 | https://github.com/LEOYoon-Tsaw/Rime_collections |
| 雾凇拼音 | https://github.com/iDvel/rime-ice |
| 白霜拼音 | https://github.com/gaboolic/rime-frost |
| 万象拼音 | https://github.com/amzxyz/rime-wanxiang |
| 薄荷输入法 | https://www.mintimate.cc |

更多配置细节可通过 MCP 工具 `query_oh-my-rime` 查询薄荷输入法知识库，或查阅 references/rime-knowledge-base.md。

---

## 能力边界说明

本 skill 的能力范围：

**✅ 能够做的**
- 生成/修改 `custom.yaml` 配置文件模板
- 解释 Rime 配置原理和 Patch 语法
- 提供各方案的配置差异和特有功能说明
- 指导部署流程和调试排查

**❌ 不能做的**
- 编写独立脚本（Python/Shell 等）自动生成配置
- 直接修改方案源码（schema.yaml）
- 提供客户端安装包下载（可提供下载链接）
- 词库转换/导入的完整工具（可指导方法）

> 如需脚本级自动化，请使用其他专门工具，或手动参考本 skill 提供的配置模板编写。

---

**使用提示**：如果您的需求涉及"写一个脚本"、"生成代码文件"等，请明确告知，skill 会提供配置模板而非脚本。