#!/bin/bash

# 卸载脚本：删除 ~/.claude/skills/ 下指向本项目的软链接
# 适用于 Linux 和 macOS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
TARGET_DIR="$HOME/.claude/skills"

echo "========================================="
echo "Uninstalling Claude Skills..."
echo "========================================="
echo ""
echo "Source: $SKILLS_DIR"
echo "Target: $TARGET_DIR"
echo ""

# 检查目标目录是否存在
if [ ! -d "$TARGET_DIR" ]; then
    echo "Target directory does not exist: $TARGET_DIR"
    echo "Nothing to uninstall."
    exit 0
fi

# 检查 skills 目录是否存在
if [ ! -d "$SKILLS_DIR" ]; then
    echo "Error: Skills directory not found: $SKILLS_DIR"
    exit 1
fi

# 计数器
removed=0
skipped=0

# 遍历 skills 目录
for skill_path in "$SKILLS_DIR"/*; do
    # 跳过非目录
    if [ ! -d "$skill_path" ]; then
        continue
    fi

    skill_name=$(basename "$skill_path")
    target_link="$TARGET_DIR/$skill_name"

    # 检查目标是否存在
    if [ -L "$target_link" ]; then
        # 是软链接，检查是否指向本项目
        # 使用 readlink 或 realpath（兼容 Linux 和 macOS）
        if command -v realpath &> /dev/null; then
            existing_target=$(realpath "$target_link" 2>/dev/null || readlink "$target_link")
            skill_path_abs=$(realpath "$skill_path")
        else
            existing_target=$(readlink "$target_link")
            skill_path_abs="$skill_path"
        fi

        if [ "$existing_target" = "$skill_path_abs" ] || [ "$existing_target" = "$skill_path" ]; then
            rm "$target_link"
            echo "✓ $skill_name (removed)"
            removed=$((removed + 1))
        else
            echo "⚠ $skill_name (skipped, points to: $existing_target)"
            skipped=$((skipped + 1))
        fi
    elif [ -e "$target_link" ]; then
        # 存在但不是软链接
        echo "⚠ $skill_name (skipped, not a symlink)"
        skipped=$((skipped + 1))
    else
        # 不存在
        echo "- $skill_name (not installed)"
    fi
done

echo ""
echo "========================================="
echo "Uninstallation Summary"
echo "========================================="
echo "Removed: $removed"
echo "Skipped: $skipped"
echo ""
echo "✓ Uninstallation completed"
