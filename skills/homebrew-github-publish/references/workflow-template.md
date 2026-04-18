# GitHub Actions Workflow 模板

## Cask 自动更新 Workflow

### 基本模板

```yaml
name: Update {AppName} Version

on:
  workflow_dispatch:
    inputs:
      version:
        description: "Version number (e.g., 1.0.0). Leave empty to auto-detect."
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
          CURRENT_VERSION=$(grep 'version "' Casks/{name}.rb | sed 's/.*version "\(.*\)".*/\1/')
          echo "current_version=$CURRENT_VERSION" >> $GITHUB_OUTPUT

          if [ -n "${{ inputs.version }}" ]; then
            NEW_VERSION="${{ inputs.version }}"
          else
            NEW_VERSION=$(curl -s https://api.github.com/repos/{owner}/{repo}/releases/latest | jq -r '.tag_name' | sed 's/^v//')
          fi
          echo "new_version=$NEW_VERSION" >> $GITHUB_OUTPUT

          if [ "$CURRENT_VERSION" = "$NEW_VERSION" ]; then
            echo "should_update=false" >> $GITHUB_OUTPUT
          else
            echo "should_update=true" >> $GITHUB_OUTPUT
          fi

      - name: Download files and calculate checksums
        if: steps.version_check.outputs.should_update == 'true'
        id: checksums
        run: |
          # Download arm64 file
          curl -f -L -o /tmp/{name}-arm64.dmg \
            "https://github.com/{owner}/{repo}/releases/download/v${{ steps.version_check.outputs.new_version }}/{file}-v${{ steps.version_check.outputs.new_version }}-mac-arm64.dmg"

          # Download x64 file
          curl -f -L -o /tmp/{name}-x64.dmg \
            "https://github.com/{owner}/{repo}/releases/download/v${{ steps.version_check.outputs.new_version }}/{file}-v${{ steps.version_check.outputs.new_version }}-mac-x64.dmg"

          # Calculate checksums
          ARM64_SHA256=$(sha256sum /tmp/{name}-arm64.dmg | awk '{print $1}')
          X64_SHA256=$(sha256sum /tmp/{name}-x64.dmg | awk '{print $1}')

          echo "arm64_sha256=$ARM64_SHA256" >> $GITHUB_OUTPUT
          echo "x64_sha256=$X64_SHA256" >> $GITHUB_OUTPUT

      - name: Update cask file
        if: steps.version_check.outputs.should_update == 'true'
        run: |
          # Update version
          sed -i "s/version \".*\"/version \"${{ steps.version_check.outputs.new_version }}\"/" Casks/{name}.rb

          # Update arm64 sha256
          sed -i '/on_arm do/,/end/{s/sha256 ".*"/sha256 "${{ steps.checksums.outputs.arm64_sha256 }}"/}' Casks/{name}.rb

          # Update x64 sha256
          sed -i '/on_intel do/,/end/{s/sha256 ".*"/sha256 "${{ steps.checksums.outputs.x64_sha256 }}"/}' Casks/{name}.rb

      - name: Commit and push changes
        if: steps.version_check.outputs.should_update == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add Casks/{name}.rb
          git commit -m "chore: update {AppName} to version ${{ steps.version_check.outputs.new_version }}"
          git push
```

## Formula 自动更新 Workflow

### Go/Rust 二进制 Formula

```yaml
name: Update {FormulaName} Version

on:
  workflow_dispatch:
    inputs:
      version:
        description: "Version number. Leave empty to auto-detect."
        required: false
        type: string
  schedule:
    - cron: "0 */12 * * *"

jobs:
  update-formula:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Get latest version
        id: version_check
        run: |
          CURRENT_VERSION=$(grep 'version "' Formula/{name}.rb | sed 's/.*version "\(.*\)".*/\1/')

          if [ -n "${{ inputs.version }}" ]; then
            NEW_VERSION="${{ inputs.version }}"
          else
            NEW_VERSION=$(curl -s https://api.github.com/repos/{owner}/{repo}/releases/latest | jq -r '.tag_name' | sed 's/^v//')
          fi

          echo "current_version=$CURRENT_VERSION" >> $GITHUB_OUTPUT
          echo "new_version=$NEW_VERSION" >> $GITHUB_OUTPUT
          echo "should_update=$([[ '$CURRENT_VERSION' != '$NEW_VERSION' ]] && echo true || echo false)" >> $GITHUB_OUTPUT

      - name: Download binaries
        if: steps.version_check.outputs.should_update == 'true'
        run: |
          curl -f -L -o /tmp/{name}-macos-arm64 \
            "https://github.com/{owner}/{repo}/releases/download/v${{ steps.version_check.outputs.new_version }}/{file}-v${{ steps.version_check.outputs.new_version }}-macos-arm64"

          curl -f -L -o /tmp/{name}-macos-x64 \
            "https://github.com/{owner}/{repo}/releases/download/v${{ steps.version_check.outputs.new_version }}/{file}-v${{ steps.version_check.outputs.new_version }}-macos-x64"

      - name: Calculate checksums
        if: steps.version_check.outputs.should_update == 'true'
        id: checksums
        run: |
          ARM64_SHA256=$(sha256sum /tmp/{name}-macos-arm64 | awk '{print $1}')
          X64_SHA256=$(sha256sum /tmp/{name}-macos-x64 | awk '{print $1}')

          echo "arm64_sha256=$ARM64_SHA256" >> $GITHUB_OUTPUT
          echo "x64_sha256=$X64_SHA256" >> $GITHUB_OUTPUT

      - name: Update formula file
        if: steps.version_check.outputs.should_update == 'true'
        run: |
          # Update version
          sed -i "s/version \".*\"/version \"${{ steps.version_check.outputs.new_version }}\"/" Formula/{name}.rb

          # Update URLs
          sed -i "s|/v[0-9.]*\/|/v${{ steps.version_check.outputs.new_version }}/|g" Formula/{name}.rb
          sed -i "s|-v[0-9.]*-macos|-v${{ steps.version_check.outputs.new_version }}-macos|g" Formula/{name}.rb

          # Update checksums
          sed -i '/if Hardware::CPU.arm?/,/if Hardware::CPU.intel?/{s/sha256 ".*"/sha256 "${{ steps.checksums.outputs.arm64_sha256 }}"/}' Formula/{name}.rb
          sed -i '/if Hardware::CPU.intel?/,/end/{s/sha256 ".*"/sha256 "${{ steps.checksums.outputs.x64_sha256 }}"/}' Formula/{name}.rb

      - name: Commit and push changes
        if: steps.version_check.outputs.should_update == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add Formula/{name}.rb
          git commit -m "chore: update {FormulaName} to version ${{ steps.version_check.outputs.new_version }}"
          git push
```

## 常用 Workflow 模式

### 1. 手动触发 + 自动检测

```yaml
on:
  workflow_dispatch:
    inputs:
      version:
        description: "Version (optional)"
        required: false
  schedule:
    - cron: "0 */12 * * *"
```

### 2. 文件大小验证

```yaml
- name: Verify file size
  run: |
    if [ $(stat -c%s /tmp/file) -lt 100000 ]; then
      echo "File too small, download may have failed"
      exit 1
    fi
```

### 3. 错误处理

```yaml
- name: Download files
  run: |
    curl -f -L -o /tmp/file.dmg "${URL}" || {
      echo "Download failed"
      exit 1
    }
```

### 4. Dry Run 模式

```yaml
- name: Show changes (dry run)
  run: |
    git diff Casks/{name}.rb
```

### 5. 创建 PR 而非直接推送

```yaml
- name: Create Pull Request
  uses: peter-evans/create-pull-request@v8
  with:
    title: "Update {AppName} to version ${{ steps.version_check.outputs.new_version }}"
    body: |
      Automated version update

      - Version: ${{ steps.version_check.outputs.new_version }}
      - Previous: ${{ steps.version_check.outputs.current_version }}
    branch: update-{name}-${{ steps.version_check.outputs.new_version }}
```

## 参考链接

- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [peter-evans/create-pull-request](https://github.com/peter-evans/create-pull-request)

---

## ⚠️ GitHub Actions 版本检查

**在使用本模板之前，请检查以下 GitHub Actions 的最新版本**：

```bash
# 检查 actions/checkout 最新版本
curl -s https://api.github.com/repos/actions/checkout/releases/latest | jq -r '.tag_name'

# 检查 peter-evans/create-pull-request 最新版本
curl -s https://api.github.com/repos/peter-evans/create-pull-request/releases/latest | jq -r '.tag_name'
```

| Action | 当前模板版本 | 检查最新 |
|--------|-------------|---------|
| `actions/checkout` | v6 | [releases](https://github.com/actions/checkout/releases) |
| `peter-evans/create-pull-request` | v8 | [releases](https://github.com/peter-evans/create-pull-request/releases) |

**最佳实践**: 每次创建新 workflow 时，先检查上述 Actions 是否有新版本发布，使用最新版本可以获得更好的性能和安全性。