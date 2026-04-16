# Rime 输入法知识库

本文档整合了 Rime 官方文档、雾凇拼音、万象拼音、白霜拼音的核心知识，供 rime-custom skill 参考。

---

## 目录

1. [配置文件结构](#配置文件结构)
2. [Engine 组件详解](#engine-组件详解)
3. [Patch 语法详解](#patch-语法详解)
4. [词库设计与维护](#词库设计与维护)
5. [辅助码系统](#辅助码系统)
6. [Lua 扩展开发](#lua-扩展开发)
7. [同步与备份](#同步与备份)
8. [各方案特色功能](#各方案特色功能)

---

## 配置文件结构

### Schema.yaml 核心节点

```yaml
schema:
  name: 方案名          # 显示名称（方案选单）
  schema_id: 方案ID    # 内部引用名
  version: 版本号
  author: 作者列表
  dependencies: 依赖方案

switches:
  - name: ascii_mode
    reset: 0
    states: ["中文", "西文"]
  - name: full_shape
    states: ["半角", "全角"]
  - name: zh_simp
    states: ["漢字", "汉字"]

engine:
  processors: [...]
  segmentors: [...]
  translators: [...]
  filters: [...]

speller:
  alphabet: 字母表
  delimiter: 分隔符
  algebra: 拼写运算规则

translator:
  dictionary: 词库文件
  prism: 棱镜文件
  preedit_format: 预编辑格式

style:
  color_scheme: 主题
  horizontal: 横排
  font_face: 字体
```

---

## Engine 组件详解

### Processors（按键处理器）

| 处理器 | 功能 | 关键配置 |
|--------|------|---------|
| `ascii_composer` | 中英文切换 | `good_old_caps_lock`, `switch_key` |
| `recognizer` | 识别特殊模式 | `patterns` 正则匹配 |
| `key_binder` | 按键重映射 | `bindings` 列表 |
| `speller` | 拼写处理 | `alphabet`, `delimiter`, `algebra` |
| `punctuator` | 标点符号 | `full_shape`, `half_shape`, `symbols` |
| `selector` | 候选选择 | `select_keys` |
| `navigator` | 光标移动 | - |
| `express_editor` | 编辑器 | - |

### Translators（翻译器）

| 翻译器 | 功能 | 关键参数 |
|--------|------|---------|
| `script_translator` | 拼音翻译 | `dictionary`, `prism`, `enable_correction` |
| `table_translator` | 码表翻译 | `dictionary`, `enable_encoder` |
| `reverse_lookup_translator` | 反查翻译 | `dictionary`, `prefix` |
| `lua_translator@name` | Lua翻译器 | `rime.lua` 中定义 |

### Filters（过滤器）

| 过滤器 | 功能 | 关键参数 |
|--------|------|---------|
| `simplifier` | 繁简转换 | `opencc_config`, `option_name` |
| `uniquifier` | 唯一化候选 | - |
| `lua_filter@name` | Lua过滤器 | `rime.lua` 中定义 |
| `emoji_suggestion` | Emoji建议 | - |

---

## Patch 语法详解

### custom.yaml 覆写规则

```yaml
patch:
  # 覆写单个值
  "menu/page_size": 9

  # 覆写嵌套值（用 / 分隔）
  "speller/algebra":
    - derive/^([zcs])h/$1/

  # 覆写数组元素
  "switches/@next":
    name: zh_simp
    reset: 1
    states: ["漢字", "汉字"]

  # 在数组末尾追加
  "engine/translators/@next": lua_translator@time_translator

  # 合并数组（使用 +）
  "key_binder/bindings/+":
    - {accept: comma, send: Page_Up, when: paging}

  # 删除元素（设为 null）
  "engine/translators/@before 0": null
```

### 配置引用机制

```yaml
# import_preset: 导入成套配置
key_binder:
  import_preset: default

# __include: 包含另一 YAML 节点
punctuator:
  full_shape:
    __include: default:/punctuator/full_shape
```

---

## 词库设计与维护

### 词库文件结构

```yaml
---
name: 词库名
version: "版本"
sort: by_weight | original
columns:
  - text    # 词条
  - code    # 编码
  - weight  # 权重
import_tables:
  - sub_dict
---
词条	编码	权重
你好	ni hao	100
```

### 多音字处理

雾凇方案的多音字策略：
- 保证 `tencent` 词库只被一种音注音
- 手动注音其他音的词汇
- 确保字表权重满足：`de * 0.05 > di`

### 自定义短语 (custom_phrase.txt)

```
# 格式：词条<Tab>编码
的	d      # 非完整编码，可参与造词
邮箱	vmail  # 完整编码，置顶显示
```

⚠️ 完整编码会阻止造词，建议使用非完整编码。

---

## 辅助码系统

### 万象拼音辅助码

万象支持 7 种辅助码方案：
- 墨奇码、鹤形、自然码、虎码首末、五笔、汉心、首右

**直接辅助码 (PRO版)**：
- 格式：双拼 + 辅码
- 示例：`vfj` = `vf`(镇的双拼) + `j`(金字旁)
- 聚拢：末尾加 `/` 强制单字优先

**间接辅助码**：
- 格式：拼音 `/` 辅码
- 示例：`ni/re`
- 不干扰整句切分

**输入后辅筛**：
- 按 ` 键引导
- 支持两分、多分、笔画、声调
- 可对候选词进行二次筛选

### 白霜拼音辅助码

- 按 ` 开启墨奇辅助码
- 不影响正常打字
- 配合 lua 实现

---

## Lua 扩展开发

### lua_translator

```lua
-- rime.lua
function time_translator(input, seg, env)
  if input == "time" then
    yield(Candidate("time", seg.start, seg._end, os.date("%H:%M:%S"), "时间"))
  end
  if input == "date" then
    yield(Candidate("date", seg.start, seg._end, os.date("%Y-%m-%d"), "日期"))
  end
end

-- 在 schema 中启用
-- engine/translators/@next: lua_translator@time_translator
```

### lua_filter

```lua
-- 候选过滤：添加序号
function filter_number(input, env)
  for cand in input:iter() do
    cand.text = cand.text .. " [" .. cand.preedit .. "]"
    yield(cand)
  end
end
```

### lua_processor

```lua
-- 按键处理：快捷日期
function date_processor(key, env)
  if key:repr() == "Control+d" then
    env.engine.context.input = os.date("%Y-%m-%d")
    return 1  -- 已处理
  end
  return 2  -- 未处理
end
```

### 万象 Lua 特色功能

- **超级注释**：辅助码提示、声调提示、拆分提示
- **手动排序**：Ctrl+j/k/l/p 调整候选顺序
- **Tips扩展**：化学式、翻译、表情等提示
- **快符Lua**：字母+/ 快速上屏符号
- **短语格式化**：\n \s \t 转义支持

---

## 同步与备份

### 同步配置

在 `installation.yaml` 中配置：

```yaml
installation_id: "设备名"    # 设备标识
sync_dir: "/path/sync"      # 同步目录
```

### 同步内容

| 文件 | 说明 |
|------|------|
| `*.custom.yaml` | 定制配置 |
| `*.userdb.kct*` | 用户词库 |
| `build/*.reverse.bin` | 反查词典 |

### 同步操作

1. 右键托盘 → 同步用户数据
2. 导出 txt 到同步目录
3. 另一设备同步导入

### 万象排序信息同步

1. 创建 `sequence_device_list.txt`
2. 列出各设备的 `sequence_xxx.txt`
3. 部署时自动合并

---

## 各方案特色功能

### 雾凇拼音 (rime-ice)

| 功能 | 触发方式 |
|------|---------|
| Emoji | 自动映射 |
| 拆字反查 | `uU` + 拼音 |
| 拆字辅码 | 拼音 + `` ` `` + 辅码 |
| 以词定字 | `[`、`]` 取首尾字 |
| Unicode | `U` + 码位 |
| 数字大写 | `R` + 数字 |
| 农历 | `N` + 8位数字 |
| 计算器 | `cC` + 算式 |
| 特殊符号 | `v` + 缩写（全拼）/ `V` + 缩写（双拼） |

### 白霜拼音 (rime-frost)

| 功能 | 触发方式 |
|------|---------|
| 辅助码 | `` ` `` 开启墨奇码 |
| 符号扩展 | `/fh` |
| 带调韵母 | `/a` `/e` `/u` |
| 日期时间 | `rq` `sj` `xq` `dt` `ts` |
| Unicode | `U` |
| 数字大写 | `R` |
| 农历 | `N` |
| 计算器 | `V` |

### 万象拼音 (rime-wanxiang)

| 功能 | 触发方式 |
|------|---------|
| 方案切换指令 | `/flypy` `/mspy` `/zrm` 等 |
| 辅助码筛选 | `` ` `` + 辅码（声调7890） |
| 语法模型 | 自动加载 `grammar.bin` |
| 输入统计 | `/rtj` `/ztj` `/ytj` `/ntj` `/tj` |
| 锁定句子 | F1 |
| 翻译模式 | Ctrl+E |
| Tips提示 | 自动显示，`,` 上屏 |
| 符号扩展 | `/sx` `/yd` 等 |
| 日期时间 | `/rq` `/sj` `/nl` 等（支持占位符） |

### 双拼方案对照

| 方案 | 特点 |
|------|------|
| 小鹤双拼 | 常用、声母韵母分离 |
| 自然码双拼 | 经典方案 |
| 微软双拼 | Windows内置 |
| 搜狗双拼 | 搜狗输入法风格 |
| 智能ABC | 老牌方案 |
| 紫光双拼 | 紫光输入法 |
| 万象双拼 | 万象独创 |

---

## 参考资料

- Rime 官方 Wiki: https://github.com/rime/home/wiki
- Schema 配置详解: https://github.com/LEOYoon-Tsaw/Rime_collections/blob/master/Rime_description.md
- 雾凇拼音: https://dvel.me/posts/rime-ice/
- 万象拼音: https://github.com/amzxyz/rime_wanxiang
- 白霜拼音: https://github.com/gaboolic/rime-frost
- 薄荷输入法: https://www.mintimate.cc