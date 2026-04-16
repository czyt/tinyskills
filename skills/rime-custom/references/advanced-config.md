# Rime 配置深度参考

本文档包含 Rime 输入法的高级配置细节。

---

## Schema 文件结构

完整的 schema 文件包含以下主要节点：

```yaml
# 方案名称（必需）
schema:
  name: 方案名
  schema_id: 方案ID
  version: 版本号

# 开关列表
switches:
  - name: ascii_mode      # 中英文开关
    reset: 0
    states: ["中文", "西文"]
  - name: full_shape      # 全半角
    reset: 0
    states: ["半角", "全角"]
  - name: zh_simp         # 繁简转换
    reset: 1
    states: ["漢字", "汉字"]
  - name: ascii_punct     # 标点符号
    reset: 0
    states: ["。，", "．，"]

# 引擎结构
engine:
  processors:    # 处理按键输入
    - ascii_composer
    - recognizer
    - key_binder
    - speller
    - punctuator
    - selector
    - navigator
    - express_editor

  segmentors:    # 切分输入码
    - ascii_segmentor
    - matcher
    - abc_segmentor
    - punct_segmentor
    - script_segmentor

  translators:   # 翻译输入码为候选
    - echo_translator
    - punct_translator
    - script_translator
    - table_translator@custom_table
    - reverse_lookup_translator

  filters:       # 过滤候选词
    - simplifier
    - uniquifier
    - charset_filter
    - lua_filter@my_filter

# 拼音拼写器
speller:
  alphabet: zyxwvutsrqponmlkjihgfedcba  # 有效字母
  delimiter: " '"                        # 分隔符
  algebra:                                # 拼写运算规则
    - erase/^xx$/
    - abbrev/^([a-z]).+$/$1/

# 翻译器配置
translator:
  dictionary: rime_ice        # 词库
  prism: rime_ice             # 棱镜（拼音映射）
  preedit_format:             # 预编辑格式
    - xlit/abc/def/
  comment_format:             # 注释格式
    - xform/([nl])v/$1ü/

# 反查翻译器
reverse_lookup:
  dictionary: stroke
  prefix: "v"
  suffix: "'"
  tips: "〔笔画〕"

# 标点符号
punctuator:
  import_preset: default
  full_shape:
    "," : {commit: "，"}
    "." : {commit: "。"}
  half_shape:
    "," : {commit: "，"}
    "." : {commit: "."}
  symbols:
    "/star": ["★", "☆"]

# 按键绑定
key_binder:
  import_preset: default
  bindings:
    - {accept: "Tab", send: "Page_Down", when: has_menu}

# 识别器
recognizer:
  import_preset: default
  patterns:
    punct: "^/[0-9a-z]*$"
    reverse_lookup: "^v[a-z]*$"

# 外观
style:
  color_scheme: native
  horizontal: true
  font_face: "Microsoft YaHei"
  font_point: 14
```

---

## 引擎组件详解

### Processors（按键处理器）

| 处理器 | 功能 | 常用配置 |
|--------|------|---------|
| `ascii_composer` | 中英文状态切换 | `good_old_caps_lock: true` |
| `recognizer` | 识别特殊输入模式 | patterns 正则 |
| `key_binder` | 按键重映射 | bindings 列表 |
| `speller` | 拼写处理 | alphabet, delimiter |
| `punctuator` | 标点符号 | symbols 映射 |
| `selector` | 候选选择 | select_keys |
| `navigator` | 光标移动 | - |
| `express_editor` | 编辑器 | - |

### Segmentors（切分器）

| 切分器 | 功能 |
|--------|------|
| `ascii_segmentor` | 切分 ASCII 文本 |
| `matcher` | 匹配正则模式 |
| `abc_segmentor` | 切分字母文本 |
| `punct_segmentor` | 切分标点 |
| `script_segmentor` | 切分脚本 |

### Translators（翻译器）

| 翻译器 | 功能 | 常用参数 |
|--------|------|---------|
| `echo_translator` | 回显输入码 | - |
| `punct_translator` | 标点翻译 | - |
| `script_translator` | 拼音翻译 | dictionary, prism |
| `table_translator` | 码表翻译 | dictionary |
| `reverse_lookup_translator` | 反查翻译 | dictionary, prefix |
| `lua_translator@name` | Lua 翻译器 | 在 rime.lua 定义 |
| `grammar_translator` | 语法翻译 | language_model |

### Filters（过滤器）

| 过滤器 | 功能 | 常用参数 |
|--------|------|---------|
| `simplifier` | 繁简转换 | opencc_config |
| `uniquifier` | 唯一化候选 | - |
| `charset_filter` | 字符集过滤 | - |
| `cjk_min_filter` | CJK 最小化 | - |
| `lua_filter@name` | Lua 过滤器 | 在 rime.lua 定义 |
| `emoji_suggestion` | Emoji 建议 | - |

---

## 雾凇拼音(rime-ice) 特色配置

雾凇拼音是目前最流行的简体拼音方案。

### 特色功能

- 丰富的词库（100万+词条）
- 内置 Emoji 支持
- 智能纠错（拼写容错）
- 扩展词库支持

### 常用覆写配置

```yaml
# rime_ice.custom.yaml
patch:
  # 候选词数量
  "menu/page_size": 9

  # 外观
  "style/horizontal": true
  "style/color_scheme": native

  # 模糊拼音（追加规则）
  'speller/algebra/@before 0':
    - derive/^([zcs])h/$1/  # zh/z 模糊
    - derive/([aei])n$/$1ng/  # en/eng 模糊

  # 禁用部分功能
  'speller/algebra/@after 0':
    - xform/^([aeiou])(ng)$/V$1/  # 优化显示

  # 启用 Lua 扩展
  'engine/translators/@next': lua_translator@time_translator

  # 简繁开关
  switches/@next:
    name: zh_simp
    reset: 1
    states: ["漢字", "汉字"]
```

---

## 白霜拼音(rime-frost) 特色配置

白霜拼音由 gaboolic 开发，强调纯净和高效。

### 特色功能

- 纯净词库，无冗余词条
- 快速响应
- 简洁的配置结构

### 适用人群

- 追求简洁的用户
- 不需要过多花哨功能
- 重视输入效率

---

## 万象拼音(rime_wanxiang) 特色配置

万象拼音由 amzxyz 开发，支持多语言和繁简混输。

### 特色功能

- 繁简双向转换
- 多语言支持（中英日韩）
- 丰富的符号输入
- 汉字拆分反查

### 配置要点

```yaml
# wanxiang.custom.yaml
patch:
  # 繁简开关
  switches:
    - name: zh_simp
      reset: 0  # 默认繁体
      states: ["漢字", "汉字"]

  # 多语言翻译器
  'engine/translators/@next':
    - table_translator@english
    - table_translator@japanese
```

---

## 薄荷输入法 特色配置

薄荷输入法专注于新手友好体验。

### 特色功能

- 简单的安装流程
- 清晰的配置说明
- 默认配置即可使用

### MCP 工具支持

薄荷输入法提供 MCP 服务：
- 服务地址：https://www.mintimate.cc/mcp
- 传输协议：Streamable HTTP
- 协议版本：2025-03-26
- 可用工具：
  - `query_oh-my-rime` — 语义搜索知识库
  - `get_download_links` — 获取下载链接
  - `get_schema_list` — 获取方案列表
  - `get_author_info` — 获取作者信息

---

## 参考资料

- 官方 Wiki：https://github.com/rime/home/wiki
- 配置详解：https://github.com/LEOYoon-Tsaw/Rime_collections/blob/master/Rime_description.md
- 雾凇拼音：https://dvel.me/posts/rime-ice/
- 万象拼音：https://github.com/amzxyz/rime_wanxiang
- 白霜拼音：https://github.com/gaboolic/rime-frost
- 薄荷输入法：https://www.mintimate.cc