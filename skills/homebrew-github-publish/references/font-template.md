# Font Cask 模板与命名规范

## ⚠️ Font 特殊规则

### 1. 命名规范

**必须以 `font-` 开头**：

| 格式 | 正确 | 错误 |
|------|------|------|
| `font-{name}.rb` | ✅ | ❌ |
| 小写字母 + 连字符 | ✅ | ❌（下划线、驼峰） |

**正确示例**:
- ✅ `font-fira-code.rb`
- ✅ `font-source-code-pro.rb`
- ✅ `font-roboto-mono.rb`
- ✅ `font-jetbrains-mono.rb`

**错误示例**:
- ❌ `FiraCode.rb`（缺少 font- 前缀）
- ❌ `font_fira_code.rb`（使用下划线）
- ❌ `font-FiraCode.rb`（驼峰命名）

### 2. 仓库要求

字体必须放在独立的 `homebrew-fonts` Tap：

```
homebrew-fonts/
└── Casks/
    ├── font-fira-code.rb
    ├── font-source-code-pro.rb
    └── ...
```

**⚠️ 检查点**: 如果用户要发布字体：
```
询问用户：
「字体需要独立的 homebrew-fonts Tap 仓库。
是否需要创建新的 homebrew-fonts 仓库？」
```

### 3. 安装位置

- Font 安装到 `~/Library/Fonts`
- 使用 `font` 指令而非 `app`

---

## Font Cask 模板

### 单个字体文件

```ruby
cask "font-{name}" do
  version "{version}"
  sha256 "PLACEHOLDER"  # workflow 自动计算

  url "https://github.com/{owner}/{repo}/releases/download/v#{version}/{font}.ttf"

  name "{Font Name}"
  desc "{description}"
  homepage "https://github.com/{owner}/{repo}"

  livecheck do
    url :url
    strategy :github_latest
  end

  font "{font}.ttf"
end
```

**示例**:

```ruby
cask "font-my-custom" do
  version "1.0.0"
  sha256 "PLACEHOLDER"

  url "https://github.com/user/my-font/releases/download/v#{version}/MyFont.ttf"

  name "My Custom Font"
  desc "A custom designed font"
  homepage "https://github.com/user/my-font"

  font "MyFont.ttf"
end
```

### 字体家族（多个字重）

```ruby
cask "font-{name}-family" do
  version "{version}"
  sha256 "PLACEHOLDER"

  url "https://github.com/{owner}/{repo}/releases/download/v#{version}/{family}.zip"

  name "{Font Name} Family"
  desc "{description}"
  homepage "https://github.com/{owner}/{repo}"

  # 安装所有字重
  font "{family}-Thin.ttf"
  font "{family}-Light.ttf"
  font "{family}-Regular.ttf"
  font "{family}-Medium.ttf"
  font "{family}-SemiBold.ttf"
  font "{family}-Bold.ttf"
  font "{family}-ExtraBold.ttf"
  font "{family}-Black.ttf"

  # 斜体版本
  font "{family}-Italic.ttf"
  font "{family}-BoldItalic.ttf"
end
```

**示例**:

```ruby
cask "font-complete-family" do
  version "2.0.0"
  sha256 "PLACEHOLDER"

  url "https://github.com/user/complete-font/releases/download/v#{version}/CompleteFamily.zip"

  name "Complete Font Family"
  desc "Full font family with all weights"
  homepage "https://github.com/user/complete-font"

  font "CompleteFamily-Thin.ttf"
  font "CompleteFamily-Light.ttf"
  font "CompleteFamily-Regular.ttf"
  font "CompleteFamily-Medium.ttf"
  font "CompleteFamily-Bold.ttf"
  font "CompleteFamily-Italic.ttf"
end
```

### 字体在子目录中

```ruby
cask "font-{name}" do
  version "{version}"
  sha256 "PLACEHOLDER"

  url "https://github.com/{owner}/{repo}/releases/download/v#{version}/fonts.zip"

  name "{Font Name}"
  homepage "https://github.com/{owner}/{repo}"

  # 字体在 ZIP 的子目录
  font "fonts/ttf/{name}-Regular.ttf"
  font "fonts/ttf/{name}-Bold.ttf"
  font "fonts/otf/{name}-Regular.otf"
  font "fonts/otf/{name}-Bold.otf"
end
```

### 可变字体 (Variable Font)

```ruby
cask "font-{name}-vf" do
  version "{version}"
  sha256 "PLACEHOLDER"

  url "https://github.com/{owner}/{repo}/releases/download/v#{version}/{font}-VF.ttf"

  name "{Font Name} Variable"
  desc "Variable font with multiple weights and widths"
  homepage "https://github.com/{owner}/{repo}"

  font "{font}-VF.ttf"
end
```

---

## GitHub Actions Workflow (Font)

### 标准 Workflow

```yaml
name: Update font-{name} Version

on:
  workflow_dispatch:
    inputs:
      version:
        description: "Version. Leave empty to auto-detect."
        required: false
        type: string
  schedule:
    - cron: "0 */12 * * *"

jobs:
  update-cask:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Get latest version
        id: version_check
        run: |
          CURRENT=$(grep 'version "' Casks/font-{name}.rb | sed 's/.*version "\(.*\)".*/\1/')
          if [ -n "${{ inputs.version }}" ]; then
            NEW="${{ inputs.version }}"
          else
            NEW=$(curl -s https://api.github.com/repos/{owner}/{repo}/releases/latest | jq -r '.tag_name' | sed 's/^v//')
          fi
          echo "current=$CURRENT" >> $GITHUB_OUTPUT
          echo "new=$NEW" >> $GITHUB_OUTPUT
          echo "update=$([[ '$CURRENT' != '$NEW' ]] && echo true || echo false)" >> $GITHUB_OUTPUT

      - name: Download font file
        if: steps.version_check.outputs.update == 'true'
        run: |
          curl -f -L -o /tmp/font.ttf \
            "https://github.com/{owner}/{repo}/releases/download/v${{ steps.version_check.outputs.new }}/Font.ttf"

      - name: Calculate checksum
        if: steps.version_check.outputs.update == 'true'
        id: checksum
        run: |
          SHA256=$(sha256sum /tmp/font.ttf | awk '{print $1}')
          echo "sha256=$SHA256" >> $GITHUB_OUTPUT

      - name: Update cask file
        if: steps.version_check.outputs.update == 'true'
        run: |
          sed -i "s/version \".*\"/version \"${{ steps.version_check.outputs.new }}\"/" Casks/font-{name}.rb
          sed -i "s/sha256 \".*\"/sha256 \"${{ steps.checksum.outputs.sha256 }}\"/" Casks/font-{name}.rb

      - name: Commit and push
        if: steps.version_check.outputs.update == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add Casks/font-{name}.rb
          git commit -m "chore: update font-{name} to version ${{ steps.version_check.outputs.new }}"
          git push
```

---

## 本地验证

```bash
# 验证 Font Cask
brew audit --cask font-{name}
brew style --cask font-{name}

# 本地安装测试
brew install --cask font-{name}

# 验证字体已安装
ls ~/Library/Fonts/
```

---

## 常见问题

### 1. 命名不规范

❌ 错误: `MyFont.rb` 或 `font_my_font.rb`
✅ 正确: `font-my-font.rb`

### 2. 使用错误的安装指令

❌ 错误: `app "Font.ttf"`
✅ 正确: `font "Font.ttf"`

### 3. 仓库位置错误

字体应放在独立的 `homebrew-fonts` Tap，而非混合在其他 Tap 中。

### 4. 多字重未全部列出

应显式列出所有字重，而非使用通配符：

❌ 不推荐: `font "*.ttf"`
✅ 推荐: 显式列出每个文件

---

## 参考链接

- [Homebrew Cask Fonts](https://github.com/Homebrew/homebrew-cask-fonts)
- [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)
- [Homebrew Font 安装指南](https://czyt.tech/post/homebrew-repo-simple-guide/)