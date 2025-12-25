#!/bin/bash

# 安装脚本：将项目 skills 目录下的所有 skill 软链接到 ~/.claude/skills/
# 适用于 Linux 和 macOS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
TARGET_DIR="$HOME/.claude/skills"

echo "========================================="
echo "Installing Claude Skills..."
echo "========================================="
echo ""
echo "Source: $SKILLS_DIR"
echo "Target: $TARGET_DIR"
echo ""

# 确保目标目录存在
if [ ! -d "$TARGET_DIR" ]; then
    echo "Creating target directory: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi

# 检查 skills 目录是否存在
if [ ! -d "$SKILLS_DIR" ]; then
    echo "Error: Skills directory not found: $SKILLS_DIR"
    exit 1
fi

# 计数器
installed=0
skipped=0
errors=0

# 遍历 skills 目录
for skill_path in "$SKILLS_DIR"/*; do
    # 跳过非目录
    if [ ! -d "$skill_path" ]; then
        continue
    fi

    skill_name=$(basename "$skill_path")
    target_link="$TARGET_DIR/$skill_name"

    # 检查目标是否已存在
    if [ -L "$target_link" ]; then
        # 已存在软链接
        # 使用 readlink 或 realpath（兼容 Linux 和 macOS）
        if command -v realpath &> /dev/null; then
            existing_target=$(realpath "$target_link" 2>/dev/null || readlink "$target_link")
            skill_path_abs=$(realpath "$skill_path")
        else
            existing_target=$(readlink "$target_link")
            skill_path_abs="$skill_path"
        fi

        if [ "$existing_target" = "$skill_path_abs" ] || [ "$existing_target" = "$skill_path" ]; then
            echo "✓ $skill_name (already installed)"
            skipped=$((skipped + 1))
        else
            echo "⚠ $skill_name (exists, pointing to: $existing_target)"
            echo "  Run uninstall.sh first to remove existing links"
            errors=$((errors + 1))
        fi
    elif [ -e "$target_link" ]; then
        # 存在但不是软链接
        echo "⚠ $skill_name (exists as regular file/directory)"
        echo "  Please remove manually: $target_link"
        errors=$((errors + 1))
    else
        # 创建新软链接
        ln -s "$skill_path" "$target_link"
        echo "✓ $skill_name (installed)"
        installed=$((installed + 1))
    fi
done

echo ""
echo "========================================="
echo "Installation Summary"
echo "========================================="
echo "Installed: $installed"
echo "Skipped:   $skipped"
echo "Errors:    $errors"
echo ""

if [ $errors -gt 0 ]; then
    echo "⚠ Installation completed with errors"
    exit 1
elif [ $installed -eq 0 ] && [ $skipped -gt 0 ]; then
    echo "✓ All skills already installed"
else
    echo "✓ Installation completed successfully"
fi
