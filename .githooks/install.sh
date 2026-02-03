#!/bin/bash
# Git Hooks 安装脚本
# 配置 Git 使用项目的 .githooks 目录

set -e

HOOKS_DIR=".githooks"
GIT_DIR=".git"

# 检查是否在 Git 仓库中
if [ ! -d "$GIT_DIR" ]; then
    echo "❌ 错误：当前目录不是 Git 仓库"
    echo "请在项目根目录运行此脚本"
    exit 1
fi

# 检查 hooks 目录是否存在
if [ ! -d "$HOOKS_DIR" ]; then
    echo "❌ 错误：找不到 $HOOKS_DIR 目录"
    exit 1
fi

echo "🔧 配置 Git Hooks..."
echo ""

# 配置 Git 使用项目的 hooks 目录
git config core.hooksPath "$HOOKS_DIR"

echo "✅ Git Hooks 安装成功！"
echo ""
echo "已启用的 hooks："
echo "  • commit-msg: 验证提交信息符合 Conventional Commits 规范"
echo ""
echo "现在你的每次提交都会自动验证格式。"
echo ""
echo "💡 提示："
echo "  • 推荐安装 commitizen 工具辅助创建规范提交"
echo "    $ pipx install commitizen"
echo "    $ cz commit"
echo ""
echo "  • 手动创建提交时，请遵循以下格式："
echo "    <type>(<scope>): <subject>"
echo ""
echo "  • 示例："
echo "    feat(ui): 添加深色模式支持"
echo "    fix(clipboard): 修复内存泄漏"
echo ""
