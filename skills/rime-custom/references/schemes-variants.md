# 输入法方案变体详细参考

本文档包含各主流方案的详细变体列表，用于 Progressive Disclosure 三级加载。

---

## 万象拼音 (wanxiang) 变体详情

万象是**系列方案**，包含多种变体，配置前请先确认实际使用的 schema 文件名。

> ⚠️ **重要**：万象通过 `/` 指令在输入状态动态切换双拼/全拼模式（如 `/flypy`），但不同变体有不同的 schema 文件和 custom.yaml 配置。

### 万象系列方案变体

| 方案变体 | Schema文件 | Custom文件 | 特点 |
|---------|-----------|-----------|------|
| **标准版** | `wanxiang.schema.yaml` | `wanxiang.custom.yaml` | 全拼/双拼通用，自动调频 |
| **Pro增强版** | `wanxiang_pro.schema.yaml` | `wanxiang_pro.custom.yaml` | 仅双拼，7种辅助码，手动造词 |
| **英文方案** | `wanxiang_english.schema.yaml` | `wanxiang_english.custom.yaml` | 英文整句输入 |
| **混合编码** | `wanxiang_mixedcode.schema.yaml` | `wanxiang_mixedcode.custom.yaml` | 中英混合编码 |
| **反查方案** | `wanxiang_reverse.schema.yaml` | `wanxiang_reverse.custom.yaml` | 拼音反查专用 |
| **T9九宫格** | `wanxiang_t9.schema.yaml` | `wanxiang_t9.custom.yaml` | 九宫格输入（移动端） |

### 标准版 vs Pro 版对比

| 差异项 | 标准版 | Pro版 |
|--------|--------|-------|
| 支持类型 | 全拼、任意双拼 | 仅双拼 |
| 自动调频 | 默认开启 | 默认关闭 |
| 辅助码 | 仅声调辅助 | 7种可选辅助码 |
| 用户词记录 | 自动积累 | 手动造词（`` 引导） |

### 特有功能配置

- 7种辅助码：墨奇、鹤形、自然、虎码、五笔、汉心、首右
- 方案切换指令：`/flypy` `/mspy` `/zrm` `/sogou` `/pinyin` `/wxsp` `/zrlong` `/hxlong`
- 语法模型：需下载 `grammar.bin` 放入用户目录
- 声调辅助：`7890` 代表 `1234` 声

### 配置示例

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

### 特殊指令（输入状态直接输入）

```
/flypy   → 切换小鹤双拼
/mspy    → 切换微软双拼
/zrm     → 切换自然码
/sogou   → 切换搜狗双拼
/pinyin  → 切换全拼
```

---

## 薄荷输入法 (rime_mint) 变体详情

> **注意**：此处以 Mintimate/oh-my-rime 官方 upstream 当前命名为准。不同薄荷衍生包可能使用不同文件名（如早期版本使用 `mint.schema.yaml`），请先查看实际文件确认。

薄荷是**系列方案**，包含多种输入方式。

### 薄荷系列方案变体

| 方案变体 | Schema文件 | Custom文件 | 特点 |
|---------|-----------|-----------|------|
| **全拼输入** | `rime_mint.schema.yaml` | `rime_mint.custom.yaml` | 默认方案，新手友好 |
| **小鹤双拼** | `rime_mint_flypy.schema.yaml` | `rime_mint_flypy.custom.yaml` | 小鹤双拼+辅码支持 |
| **通用双拼** | `double_pinyin.schema.yaml` | `double_pinyin.custom.yaml` | 通用双拼框架 |
| **ABC双拼** | `double_pinyin_abc.schema.yaml` | `double_pinyin_abc.custom.yaml` | ABC双拼 |
| **微软双拼** | `double_pinyin_mspy.schema.yaml` | `double_pinyin_mspy.custom.yaml` | Windows内置双拼 |
| **搜狗双拼** | `double_pinyin_sogou.schema.yaml` | `double_pinyin_sogou.custom.yaml` | 搜狗双拼 |
| **紫光双拼** | `double_pinyin_ziguang.schema.yaml` | `double_pinyin_ziguang.custom.yaml` | 紫光双拼 |
| **地球拼音** | `terra_pinyin.schema.yaml` | `terra_pinyin.custom.yaml` | 带调拼音输入 |
| **九宫格T9** | `t9.schema.yaml` | `t9.custom.yaml` | 九宫格输入（移动端） |
| **86五笔** | `wubi86_jidian.schema.yaml` | `wubi86_jidian.custom.yaml` | 极点五笔86 |
| **98五笔** | `wubi98_mint.schema.yaml` | `wubi98_mint.custom.yaml` | 五笔98版 |

### 特点

- 新手友好，配置简单
- 支持 MCP 知识库查询（薄荷官方提供）
- 词库使用万象拼音词库（2025-07后）

### 配置示例

```yaml
# rime_mint.custom.yaml - 薄荷专用配置
patch:
  "menu/page_size": 7
  "style/color_scheme": native
```

---

## 白霜拼音 (rime-frost) 变体详情

白霜是**系列方案**，包含多种输入方式。

### 白霜系列方案变体

| 方案变体 | Schema文件 | Custom文件 | 特点 |
|---------|-----------|-----------|------|
| **全拼输入** | `rime_frost.schema.yaml` | `rime_frost.custom.yaml` | 默认方案，词频优化 |
| **双拼输入** | `rime_frost_double.schema.yaml` | `rime_frost_double.custom.yaml` | 双拼变体（部分发行版） |

> ⚠️ 不同白霜发行版可能包含不同变体，请先查看实际文件。

### 主要文件

| 文件类型 | 文件名 | 说明 |
|---------|-------|------|
| Schema主文件 | `rime_frost.schema.yaml` | 主方案配置 |
| Custom覆写 | `rime_frost.custom.yaml` | 用户定制配置 |
| 词库文件 | `rime_frost.dict.yaml` | 词频优化词库 |
| 墨奇辅码 | `moqi.dict.yaml` | 辅助码映射 |

### 特有功能配置

- 墨奇辅助码：按 `` ` `` 开启（方案内置）
- 符号扩展：`/fh` `/yd` 等（通过 `punctuator/symbols` 配置）
- 日期时间：`rq` `sj` `xq` 直接输入

### 配置示例

```yaml
# rime_frost.custom.yaml - 白霜专用配置
patch:
  # 辅码相关配置已内置，一般无需修改

  # 自定义符号
  'punctuator/symbols':
    "/my": ["自定义符号1", "自定义符号2"]
```

---

## 双拼方案通用变体

| 方案 | Schema文件 | 特点 |
|------|-----------|------|
| 自然码 | `double_pinyin.schema.yaml` | 经典双拼 |
| 小鹤双拼 | `double_pinyin_flypy.schema.yaml` | 常用双拼 |
| 微软双拼 | `double_pinyin_mspy.schema.yaml` | Windows内置 |

### 配置差异

- 双拼方案共享朙月拼音词库
- 通过 `speller/algebra` 定义双拼映射
- 模糊音配置与全拼不同（作用于双拼编码）