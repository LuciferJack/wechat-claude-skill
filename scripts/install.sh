#!/bin/bash
# install.sh — 一键安装 wechat-claude-skill 及其依赖
set -e

echo "=== wechat-claude-skill 安装 ==="
echo ""

# 1. 检查 macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ 仅支持 macOS"
    exit 1
fi
echo "✓ macOS $(sw_vers -productVersion)"

# 2. 检查 Node.js
if ! command -v node &>/dev/null; then
    echo "❌ 未安装 Node.js，请先安装："
    echo "  brew install node"
    exit 1
fi
echo "✓ Node.js $(node --version)"

# 3. 安装 wechat-cli
if command -v wechat-cli &>/dev/null; then
    echo "✓ wechat-cli $(wechat-cli --version) 已安装"
else
    echo "→ 安装 wechat-cli..."
    npm install -g @canghe_ai/wechat-cli
    echo "✓ wechat-cli 安装完成"
fi

# 4. 检查微信
if ! ls /Applications/WeChat.app &>/dev/null 2>&1; then
    echo "⚠ 未检测到微信桌面版，请从 App Store 安装"
fi

# 5. 安装 skill 到 Claude Code（可选）
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
read -p "是否安装 skill 到当前项目的 .claude/skills/? (y/N) " install_skill
if [[ "$install_skill" == "y" || "$install_skill" == "Y" ]]; then
    mkdir -p .claude/skills/wechat-mac
    cp "$SCRIPT_DIR/SKILL.md" .claude/skills/wechat-mac/
    echo "✓ Skill 已安装到 .claude/skills/wechat-mac/"
fi

echo ""
echo "=== 安装完成 ==="
echo ""
echo "后续步骤："
echo "  1. 确保微信桌面版已登录"
echo "  2. 系统设置 → 隐私与安全 → 辅助功能 → 勾选你的终端"
echo "  3. 系统设置 → 隐私与安全 → 完全磁盘访问权限 → 勾选你的终端"
echo "  4. 关闭 SIP 后运行: sudo wechat-cli init"
echo "  5. 测试: wechat-cli sessions --limit 5"
echo "  6. 测试发送: ./scripts/wechat_send.sh '文件传输助手' '测试消息'"
