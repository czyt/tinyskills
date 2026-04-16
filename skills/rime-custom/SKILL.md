---
name: rime-custom
description: Rime 输入法配置定制助手。支持 custom.yaml 覆写、Emoji/OpenCC、模糊拼音、Lua 扩展、多设备同步。覆盖雾凇/白霜/薄荷/万象方案。触发词：Rime配置、小狼毫、鼠须管、custom.yaml、模糊拼音、辅助码。
---

# Rime 输入法配置定制助手

帮助用户定制 Rime 输入法配置，通过 `custom.yaml` 覆写实现个性化设置，不修改原始方案文件，升级时保留配置。

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
| [api-development.md](references/core/api-development.md) | librime API 开发 | 程序级扩展 |
| [introduction.md](references/core/introduction.md) | Rime 架构原理 | 了解底层机制 |
| [downloads.md](references/core/downloads.md) | 客户端下载 | 安装指引 |

### 定制指南 (customization/)
| 文档 | 内容 | 用途 |
|------|------|------|
| [patch-guide.md](references/customization/patch-guide.md) | **Patch语法详解** ⭐ | custom.yaml 覆写 |
| [user-manual.md](references/customization/user-manual.md) | 用户操作手册 | 打字/选字/切换 |
| [userdata.md](references/customization/userdata.md) | 用户数据管理 | 同步/备份/词库 |

### 方案详解 (schemes/)
| 文档 | 内容 | 用途 |
|------|------|------|
| [rime-ice.md](references/schemes/rime-ice.md) | 雾凇词库设计 (42KB) | 简体拼音配置 |
| [rime-wanxiang.md](references/schemes/rime-wanxiang.md) | 万象完整文档 (94KB) | 辅助码/语法模型 |
| [rime-frost.md](references/schemes/rime-frost.md) | 白霜词频优化 (32KB) | 墨奇辅助码 |
| [combopinyin.md](references/schemes/combopinyin.md) | 宫保拼音专题 | 并击输入 |

### 原始抓取 (scraped/)
14个原始文档 (544KB, 12000行)，包含上述所有内容的未整理版本。

> 📖 **使用策略**：优先查 `rime-knowledge-base.md` 获取摘要，需要深入时查阅分类目录。AI编写配置工具时，应先读 `customization/patch-guide.md` 理解Patch语法。

---

## 主流方案概览

| 方案 | 特点 | 配置文件 | 适用场景 |
|------|------|---------|---------|
| **雾凇 (rime-ice)** | 简体拼音、词库丰富(100万+)、Emoji、拆字反查 | `rime_ice.schema.yaml` | 日常输入、简体用户 |
| **白霜 (rime-frost)** | 词频优化(745M语料)、纯净、墨奇辅助码 | `rime_frost.schema.yaml` | 极简风格、辅助码爱好者 |
| **薄荷 (mint)** | 简体拼音、新手友好、MCP知识库 | `mint.schema.yaml` | 新手入门 |
| **万象 (wanxiang)** | 繁简混输、语法模型、7种辅助码 | `wanxiang.schema.yaml` | 繁体用户、高级定制 |

> 🔍 选择建议：日常用雾凇/白霜，繁体用万象，新手用薄荷。

---

## 配置工作流

### Step 1: 确定方案 ⚠️

**输入**：用户描述需求或提及方案名
**输出**：确定方案类型，对应 custom.yaml 文件名

询问用户使用的输入方案：

| 用户提及 | 方案 | custom.yaml 文件 |
|---------|------|-----------------|
| "雾凇/冰/雪" | rime-ice | `rime_ice.custom.yaml` |
| "白霜/霜/纯净" | rime-frost | `rime_frost.custom.yaml` |
| "薄荷/Mint" | mint | `mint.custom.yaml` |
| "万象" | wanxiang | `wanxiang.custom.yaml` |
| "朙月" | luna_pinyin | `luna_pinyin.custom.yaml` |
| "双拼" | double_pinyin | `double_pinyin.custom.yaml` |

> 🛑 **检查点**：确认方案后再继续。不确定时问用户："您用的是哪个方案？雾凇、白霜、薄荷还是万象？"

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

### Step 3: 创建/修改 custom.yaml

**输入**：方案名、用户需求
**输出**：custom.yaml 配置内容

```yaml
# 示例：rime_ice.custom.yaml
patch:
  "menu/page_size": 9  # 候选词数量
```

> 🛑 **检查点**：复杂配置前，先向用户展示配置预览，确认："这个配置符合您的需求吗？"

### Step 4: 部署生效

**输入**：配置文件已修改
**输出**：部署成功确认

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
  "engine/transforms/@before 0": emoji_suggestion

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

### 方式一：内置 Emoji 支持

```yaml
patch:
  # 启用 Emoji 候选
  'engine/transforms/@before 0': emoji_suggestion

  # Emoji 匹配规则
  'emoji_suggestion/opencc_config': emoji.json
```

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

### 启用语法分析

```yaml
patch:
  # 添加语法翻译器
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

## Lua 功能扩展

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

  # Emoji
  'engine/transforms/@before 0': emoji_suggestion
```

### 薄荷基础定制

```yaml
# mint.custom.yaml
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