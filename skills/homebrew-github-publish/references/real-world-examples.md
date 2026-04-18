# 真实项目示例

## Homebrew Cask 实例

### 实例 1: 单架构 Universal DMG

来源: homebrew-tap/Casks/antigravity-tools.rb

```ruby
cask "antigravity-tools" do
  version "3.3.49"
  sha256 "67dc4bb450cbd68913e1c9c5c463ec75be1df323f9fc404b2e19893504151487"

  url "https://github.com/lbjlaq/Antigravity-Manager/releases/download/v#{version}/Antigravity.Tools_#{version}_universal.dmg"

  name "Antigravity Tools"
  desc "Antigravity remote client"
  homepage "https://github.com/lbjlaq/Antigravity-Manager"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Antigravity Tools.app"
end
```

**特点**:
- Universal DMG（同时支持 arm64 和 x64）
- 使用 livecheck 自动版本检测
- sha256 使用 workflow 自动更新

### 实例 2: 多架构 DMG

来源: homebrew-tap/Casks/blink1control2.rb

```ruby
cask "blink1control2" do
  version "2.2.9"

  on_arm do
    sha256 "5201cc77aa1b51b927d90e59f6221ff55f147f5910f6e75b6acd0966b3f4c099"
    url "https://github.com/todbot/Blink1Control2/releases/download/v#{version}/Blink1Control2-#{version}-mac-arm64.dmg"
  end

  on_intel do
    sha256 "fa4a8457f905b6e7ef288c621fed646305ac31408932a9cfa7181fde41499ec2"
    url "https://github.com/todbot/Blink1Control2/releases/download/v#{version}/Blink1Control2-#{version}-mac-x64.dmg"
  end

  name "Blink1Control2"
  desc "Blink1Control GUI to control blink(1) USB RGB LED devices"
  homepage "https://github.com/todbot/Blink1Control2"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Blink1Control2.app"
end
```

**特点**:
- 使用 `on_arm` / `on_intel` 分架构支持
- 分别下载不同的 DMG 文件
- 各架构独立的 sha256

### 实例 3: postflight 和 zap

来源: homebrew-tap/Casks/fcitx5.rb

```ruby
cask "fcitx5" do
  version "0.3.1"
  sha256 "67dc4bb450cbd68913e1c9c5c463ec75be1df323f9fc404b2e19893504151487"

  url "https://github.com/fcitx-contrib/fcitx5-macos-installer/releases/download/#{version}/Fcitx5Installer.zip"

  name "Fcitx5"
  desc "Fcitx5 input method framework for macOS"
  homepage "https://github.com/fcitx-contrib/fcitx5-macos-installer"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :big_sur"

  app "Fcitx5Installer.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Fcitx5Installer.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Application Support/Fcitx5",
    "~/Library/Caches/org.fcitx.inputmethod.Fcitx5",
    "~/Library/Preferences/org.fcitx.inputmethod.Fcitx5.plist",
    "~/Library/Saved Application State/org.fcitx.inputmethod.Fcitx5.savedState",
  ]
end
```

**特点**:
- 使用 `depends_on` 限制 macOS 版本
- `postflight` 清除 xattr（解决 macOS Gatekeeper 问题）
- `zap` 配置完全删除残留文件

---

## Homebrew Formula 实例

### 实例 1: 多架构二进制

来源: homebrew-tap/Formula/mise-bin.rb

```ruby
class MiseBin < Formula
  desc "The front-end to your dev env (polyglot version manager)"
  homepage "https://mise.jdx.dev/"
  version "2026.4.11"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/jdx/mise/releases/download/v2026.4.11/mise-v2026.4.11-macos-arm64"
      sha256 "265ffb4990785d2d3c6178ebfa97c2c7d845c091fb3b5940525c06b1d70e281c"

      def install
        bin.install "mise-v2026.4.11-macos-arm64" => "mise"
      end
    end

    if Hardware::CPU.intel?
      url "https://github.com/jdx/mise/releases/download/v2026.4.11/mise-v2026.4.11-macos-x64"
      sha256 "dc356331acc6aa14d0b6885a20e32f8f9a577791de5cfdecb39a330a6a4e82e6"

      def install
        bin.install "mise-v2026.4.11-macos-x64" => "mise"
      end
    end
  end

  def caveats
    <<~EOS
      mise has been installed!

      To get started, run:
        mise --version

      For shell integration, add to your shell profile:
        # For Bash
        echo 'eval "$(mise activate bash)"' >> ~/.bashrc

        # For Zsh
        echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
    EOS
  end

  test do
    system "#{bin}/mise", "--version"
  end
end
```

**特点**:
- 使用 `on_macos` + `Hardware::CPU.arm?/intel?` 分架构
- URL 包含版本号，workflow 自动更新
- `caveats` 提供使用说明
- `test do` 包含版本测试

---

## GitHub Actions Workflow 实例

### 实例 1: 单文件 Cask 自动更新

来源: homebrew-tap/.github/workflows/update-antigravity-tools-version.yml

```yaml
name: Update Antigravity Tools Version

on:
  workflow_dispatch:
    inputs:
      version:
        description: "Version number. Leave empty to auto-detect."
        required: false
        type: string
  schedule:
    - cron: "0 12 * * *"

jobs:
  update-cask:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Get latest version and check for updates
        id: version_check
        run: |
          CURRENT_VERSION=$(grep 'version \"' Casks/antigravity-tools.rb | sed 's/.*version \"\\(.*\\)\".*/\\1/')
          echo "Current version: $CURRENT_VERSION"

          if [ -n "${{ inputs.version }}" ]; then
            NEW_VERSION="${{ inputs.version }}"
          else
            RELEASE_INFO=$(curl -f -s "https://api.github.com/repos/lbjlaq/Antigravity-Manager/releases/latest")
            NEW_VERSION=$(echo "$RELEASE_INFO" | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -n 1)
          fi

          if [ "$CURRENT_VERSION" = "$NEW_VERSION" ]; then
            echo "should_update=false" >> $GITHUB_OUTPUT
          else
            echo "should_update=true" >> $GITHUB_OUTPUT
          fi

          echo "new_version=$NEW_VERSION" >> $GITHUB_OUTPUT
          echo "current_version=$CURRENT_VERSION" >> $GITHUB_OUTPUT

      - name: Download macOS dmg
        if: steps.version_check.outputs.should_update == 'true'
        run: |
          curl -f -L -o /tmp/antigravity-tools.dmg \
            "https://github.com/lbjlaq/Antigravity-Manager/releases/download/v${{ steps.version_check.outputs.new_version }}/Antigravity.Tools_${{ steps.version_check.outputs.new_version }}_universal.dmg"

      - name: Calculate checksum
        if: steps.version_check.outputs.should_update == 'true'
        id: checksum
        run: |
          if [ ! -s /tmp/antigravity-tools.dmg ] || [ $(stat -c%s /tmp/antigravity-tools.dmg) -lt 100000 ]; then
            echo "dmg file is missing or too small"
            exit 1
          fi
          SHA256=$(sha256sum /tmp/antigravity-tools.dmg | awk '{print $1}')
          echo "sha256=$SHA256" >> $GITHUB_OUTPUT

      - name: Update cask file
        if: steps.version_check.outputs.should_update == 'true'
        run: |
          sed -i 's/version ".*"/version "${{ steps.version_check.outputs.new_version }}"/' Casks/antigravity-tools.rb
          sed -i 's/sha256 :no_check/sha256 "${{ steps.checksum.outputs.sha256 }}"/' Casks/antigravity-tools.rb

      - name: Commit and push changes
        if: steps.version_check.outputs.should_update == 'true'
        run: |
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git config user.name "github-actions[bot]"
          git add Casks/antigravity-tools.rb
          git diff --cached --quiet || git commit -m "chore: update Antigravity Tools to version ${{ steps.version_check.outputs.new_version }}"
          git push
```

**关键点**:
- `curl -f` 失败时报错
- 文件大小验证 (`stat -c%s`)
- `git diff --cached --quiet` 防止空提交

### 实例 2: 多文件批量更新

来源: homebrew-tap/.github/workflows/update-fcitx5-versions.yml

```yaml
name: Update Fcitx5 Versions

on:
  workflow_dispatch:
    inputs:
      version:
        description: "Version number. Leave empty to auto-detect."
        required: false
        type: string
  schedule:
    - cron: "0 12 * * 5"

jobs:
  update-casks:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Download files
        if: steps.version_check.outputs.should_update == 'true'
        run: |
          curl -f -L -o /tmp/Fcitx5-Pinyin.zip "https://github.com/fcitx-contrib/fcitx5-macos-installer/releases/download/${{ steps.version_check.outputs.new_version }}/Fcitx5-Pinyin.zip"
          curl -f -L -o /tmp/Fcitx5-Rime.zip "https://github.com/fcitx-contrib/fcitx5-macos-installer/releases/download/${{ steps.version_check.outputs.new_version }}/Fcitx5-Rime.zip"
          curl -f -L -o /tmp/Fcitx5Installer.zip "https://github.com/fcitx-contrib/fcitx5-macos-installer/releases/download/${{ steps.version_check.outputs.new_version }}/Fcitx5Installer.zip"

      - name: Calculate checksums
        if: steps.version_check.outputs.should_update == 'true'
        id: checksums
        run: |
          # Verify files exist and have reasonable size
          for file in /tmp/Fcitx5-Pinyin.zip /tmp/Fcitx5-Rime.zip /tmp/Fcitx5Installer.zip; do
            if [ ! -s "$file" ] || [ $(stat -c%s "$file") -lt 100000 ]; then
              echo "$file is missing or too small"
              exit 1
            fi
          done

          SHA256_PINYIN=$(sha256sum /tmp/Fcitx5-Pinyin.zip | awk '{print $1}')
          SHA256_RIME=$(sha256sum /tmp/Fcitx5-Rime.zip | awk '{print $1}')
          SHA256_INSTALLER=$(sha256sum /tmp/Fcitx5Installer.zip | awk '{print $1}')

          echo "sha256_pinyin=$SHA256_PINYIN" >> $GITHUB_OUTPUT
          echo "sha256_rime=$SHA256_RIME" >> $GITHUB_OUTPUT
          echo "sha256_installer=$SHA256_INSTALLER" >> $GITHUB_OUTPUT

      - name: Update cask files
        if: steps.version_check.outputs.should_update == 'true'
        run: |
          # Update multiple casks
          sed -i "s/version \".*\"/version \"${{ steps.version_check.outputs.new_version }}\"/" Casks/fcitx5-pinyin.rb
          sed -i "s/sha256 \".*\"/sha256 \"${{ steps.checksums.outputs.sha256_pinyin }}\"/" Casks/fcitx5-pinyin.rb

          sed -i "s/version \".*\"/version \"${{ steps.version_check.outputs.new_version }}\"/" Casks/fcitx5-rime.rb
          sed -i "s/sha256 \".*\"/sha256 \"${{ steps.checksums.outputs.sha256_rime }}\"/" Casks/fcitx5-rime.rb

          sed -i "s/version \".*\"/version \"${{ steps.version_check.outputs.new_version }}\"/" Casks/fcitx5.rb
          sed -i "s/sha256 \".*\"/sha256 \"${{ steps.checksums.outputs.sha256_installer }}\"/" Casks/fcitx5.rb

      - name: Commit and push changes
        if: steps.version_check.outputs.should_update == 'true'
        run: |
          git add Casks/fcitx5-pinyin.rb Casks/fcitx5-rime.rb Casks/fcitx5.rb
          git commit -m "chore: update Fcitx5 to version ${{ steps.version_check.outputs.new_version }}"
          git push
```

**关键点**:
- 同时更新多个相关 Cask
- 使用循环验证多个文件
- 批量提交多个文件

### 实例 3: 多架构 Formula 更新

来源: homebrew-tap/.github/workflows/update-mise-bin-version.yml

```yaml
- name: Update formula file
  run: |
    # Update version
    sed -i "s/version \".*\"/version \"${{ steps.version_check.outputs.new_version }}\"/" Formula/mise-bin.rb

    # Update version in URLs and install paths
    sed -i "s|/v[0-9.]*\/|/v${{ steps.version_check.outputs.new_version }}/|g" Formula/mise-bin.rb
    sed -i "s|mise-v[0-9.]*-macos|mise-v${{ steps.version_check.outputs.new_version }}-macos|g" Formula/mise-bin.rb

    # Update intel sha256
    sed -i '/if Hardware::CPU.intel?/,/end/{s/sha256 ".*"/sha256 "${{ steps.checksums.outputs.x64_sha256 }}"/}' Formula/mise-bin.rb

    # Update arm sha256
    sed -i '/if Hardware::CPU.arm?/,/if Hardware::CPU.intel?/{s/sha256 ".*"/sha256 "${{ steps.checksums.outputs.arm64_sha256 }}"/}' Formula/mise-bin.rb
```

**关键点**:
- URL 中版本号替换（`/v[0-9.]*\/`）
- 安装路径版本号替换（`mise-v[0-9.]*-macos`）
- 复杂的 sed 块匹配更新 sha256

---

## Workflow 最佳实践总结

### 1. 错误处理

```yaml
# 使用 curl -f 失败时报错
curl -f -L -o /tmp/file.dmg "${URL}"

# 验证文件大小
if [ $(stat -c%s /tmp/file) -lt 100000 ]; then
  echo "File too small"
  exit 1
fi
```

### 2. 版本比较

```bash
# 简单比较
if [ "$CURRENT_VERSION" = "$NEW_VERSION" ]; then
  echo "No update needed"
fi
```

### 3. 防止空提交

```bash
git diff --cached --quiet || git commit -m "..."
```

### 4. 使用 GitHub Step Summary

```yaml
- name: Summary
  if: always()
  run: |
    echo "## Update Summary" >> $GITHUB_STEP_SUMMARY
    echo "- **Current**: $CURRENT" >> $GITHUB_STEP_SUMMARY
    echo "- **New**: $NEW" >> $GITHUB_STEP_SUMMARY
```

---

## 参考链接

- [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)
- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [GitHub Actions 文档](https://docs.github.com/en/actions)