# wechat-claude-skill

macOS 微信自动化 Claude Code Skill。支持发送消息和查看/搜索聊天记录。

## 功能

- **发送消息**：通过 AppleScript 向任意联系人或群聊发送文本（支持中文、emoji）
- **查看消息**：通过 wechat-cli 查看聊天记录、搜索、联系人、未读、群成员、导出等
- **批量发送**：支持向同一对象发送多条消息

## 系统要求

- macOS 10.15+
- Node.js 18+
- WeChat Desktop（已登录）
- 终端需要 **辅助功能权限** + **完全磁盘访问权限**
- macOS 需 **关闭 SIP**（wechat-cli 初始化需要）

## 依赖

| 依赖 | 用途 | 安装方式 |
|------|------|----------|
| [wechat-cli](https://www.npmjs.com/package/@canghe_ai/wechat-cli) | 读取微信本地数据库（聊天记录、联系人等） | `npm install -g @canghe_ai/wechat-cli` |
| osascript | 执行 AppleScript 发送消息 | macOS 自带 |

## 快速安装

```bash
# 一键安装（检查环境 + 安装依赖 + 可选安装 skill）
git clone https://github.com/LuciferJack/wechat-claude-skill.git
cd wechat-claude-skill
chmod +x scripts/*.sh
./scripts/install.sh
```

或手动安装：

```bash
# 1. 安装 wechat-cli
npm install -g @canghe_ai/wechat-cli

# 2. 初始化（需关闭 SIP，首次使用）
sudo wechat-cli init

# 3. 验证
wechat-cli sessions --limit 5
```

## 安装到 Claude Code

将 `SKILL.md` 放到你的 Claude Code 项目的 `.claude/skills/wechat-mac/` 目录下：

```bash
mkdir -p .claude/skills/wechat-mac
cp SKILL.md .claude/skills/wechat-mac/
```

或全局安装：

```bash
mkdir -p ~/.claude/skills/wechat-mac
cp SKILL.md ~/.claude/skills/wechat-mac/
```

## 独立使用

```bash
# 发送单条消息
./scripts/wechat_send.sh "联系人名" "你好！"

# 批量发送
./scripts/wechat_batch_send.sh "群名" "消息一" "消息二" "消息三"
```

## 工作原理

### 发送

使用 `osascript` 执行 AppleScript，通过 `tell process "WeChat"` 直接向微信进程发送键盘事件：

1. 激活微信 → Escape 清除状态
2. Cmd+F 打开搜索 → 粘贴联系人名
3. 两次 Enter（提交搜索 + 选中结果）
4. Option+Down/Up 导航到输入框
5. 粘贴消息 → Enter 发送

### 查看

通过 `wechat-cli` 读取微信本地 SQLite 数据库，纯本地操作，数据不出机器。

## 隐私

- 所有操作纯本地，不联网
- 不存储任何消息内容
- 剪贴板会被临时使用

## License

MIT
