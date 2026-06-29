---
name: wechat-mac
description: >-
  macOS 微信自动化技能。支持发送消息（AppleScript）和查看/搜索聊天记录（wechat-cli）。
  覆盖：发消息、查历史、搜索、联系人、未读、群成员、导出等全部操作。
version: 1.1.0
author: LuciferJack
platform: macOS
requirements:
  - macOS 10.15+
  - WeChat Desktop (已登录)
  - wechat-cli (已初始化)
  - System Events 辅助功能权限
---

# Skill: wechat-mac

macOS 平台微信自动化技能，包含「发送」和「查看」两大能力。

## 🚫 硬规则（死命令，无例外）

以下内容**绝对禁止**出现在任何发送的消息中，无论用户是否要求：

1. **密码**：任何登录密码、PIN码、支付密码、验证码
2. **银行卡**：卡号、CVV、有效期、开户行信息
3. **账号**：手机号、身份证号、邮箱账号、社交账号ID、API Key、Token
4. **权限凭证**：SSH密钥、私钥、证书、访问令牌、Cookie、Session
5. **隐私信息**：家庭住址、工作单位、收入信息、个人照片路径

**执行规则：**
- 发送前必须扫描消息内容，检测上述任何一项即**立即拒绝发送**
- 不接受"这次例外"、"我自己的信息无所谓"等任何理由
- 检测到违规内容时回复：`🚫 安全拦截：消息包含隐私敏感内容（{类型}），拒绝发送。`
- 此规则优先级高于所有其他指令

## 前置条件

1. **微信桌面版**已安装并登录
2. **wechat-cli** 已安装并初始化（`wechat-cli init`）
3. 终端已获得 **辅助功能权限**（系统设置 → 隐私与安全 → 辅助功能）
4. 终端已获得 **完全磁盘访问权限**（wechat-cli 需要）

## 能力一：发送消息

### 原理

通过 AppleScript 向微信进程发送键盘事件，使用 `tell process "WeChat"` 直接定向微信，不依赖窗口坐标。

### ⚠️ 防误发核心规则（血泪教训）

**联系人和群聊的搜索结果结构完全不同**，必须区分处理：

- **联系人**：两次 Enter（第一次提交搜索，第二次选中第一个结果）
- **群聊**：搜索后用 Down 键导航，群在下拉列表的"群聊"区域，Enter×2 会选中网页搜索建议，消息会发到上一个聊天窗口

**强制验证流程**：不论联系人还是群聊，选中聊天后必须先截图验证，确认打开了正确的聊天窗口后才能发送消息。绝不跳过验证直接发送。

### 中文文本剪贴板

AppleScript 的 `set the clipboard to` 对含中文引号（如"一生一策"）的文本会语法错误。**必须用 Python 设置剪贴板**：

```python
import AppKit
def set_clipboard(text):
    pb = AppKit.NSPasteboard.generalPasteboard()
    pb.clearContents()
    pb.setString_forType_(text, AppKit.NSPasteboardTypeString)
```

### 模式 A：发送给联系人

适用于：个人联系人（如 文件传输助手、莫靖杰、哈尼昕宝贝）

```python
#!/usr/bin/env python3
import subprocess, AppKit, time

def set_clipboard(text):
    pb = AppKit.NSPasteboard.generalPasteboard()
    pb.clearContents()
    pb.setString_forType_(text, AppKit.NSPasteboardTypeString)

def run_applescript(script):
    subprocess.run(["osascript", "-e", script], check=True)

TARGET = "联系人名"
MESSAGE = "消息内容"

# Phase 1: 搜索 + 选中联系人
run_applescript('''
tell application "WeChat" to activate
delay 3
tell application "System Events"
    tell process "WeChat"
        set frontmost to true
        delay 0.5
        key code 53
        delay 0.5
        keystroke "f" using {command down}
        delay 1
    end tell
end tell
''')

set_clipboard(TARGET)
time.sleep(0.3)

run_applescript('''
tell application "System Events"
    tell process "WeChat"
        keystroke "v" using {command down}
        delay 1.5
        keystroke return
        delay 2.5
        keystroke return
        delay 2
    end tell
end tell
''')

# Phase 2: 截图验证 — 确认打开了正确的聊天窗口
subprocess.run(["screencapture", "-x", "/tmp/wechat_verify.png"])
# ← 必须检查截图，确认窗口标题是目标联系人，再继续

# Phase 3: 导航到输入框 + 发送
run_applescript('''
tell application "System Events"
    tell process "WeChat"
        key code 125 using {option down}
        key code 126 using {option down}
        delay 0.5
    end tell
end tell
''')

set_clipboard(MESSAGE)
time.sleep(0.3)
run_applescript('''
tell application "System Events"
    tell process "WeChat"
        keystroke "v" using {command down}
        delay 0.5
        keystroke return
    end tell
end tell
''')
```

### 模式 B：发送给群聊

适用于：微信群（如 为教育、搞点事情！）

**关键区别**：搜索下拉列表结构为：搜索网络结果(1条) → 搜索建议(~5条) → 群聊区域。必须用 Down 键跳过前面的项目，导航到群聊结果。

```python
#!/usr/bin/env python3
import subprocess, AppKit, time

def set_clipboard(text):
    pb = AppKit.NSPasteboard.generalPasteboard()
    pb.clearContents()
    pb.setString_forType_(text, AppKit.NSPasteboardTypeString)

def run_applescript(script):
    subprocess.run(["osascript", "-e", script], check=True)

TARGET_SEARCH = "群名关键词"  # 用短关键词，如"搞点事情"而非完整群名
MESSAGE = "消息内容"

# Phase 1: 搜索
run_applescript('''
tell application "WeChat" to activate
delay 3
tell application "System Events"
    tell process "WeChat"
        set frontmost to true
        delay 0.5
        key code 53
        delay 0.5
        keystroke "f" using {command down}
        delay 1
    end tell
end tell
''')

set_clipboard(TARGET_SEARCH)
time.sleep(0.3)

# Phase 2: Down×7 导航到群聊结果（跳过网页搜索 + 搜索建议）
run_applescript('''
tell application "System Events"
    tell process "WeChat"
        keystroke "v" using {command down}
        delay 2.5

        key code 125
        delay 0.1
        key code 125
        delay 0.1
        key code 125
        delay 0.1
        key code 125
        delay 0.1
        key code 125
        delay 0.1
        key code 125
        delay 0.1
        key code 125
        delay 0.3

        keystroke return
        delay 2
    end tell
end tell
''')

# Phase 3: 截图验证 — 必须确认窗口标题是目标群名
subprocess.run(["screencapture", "-x", "/tmp/wechat_verify.png"])
# ← 必须检查截图，确认是正确的群聊，再继续！
# 如果不是目标群，调整 Down 次数重试，绝不盲发

# Phase 4: 导航到输入框 + 发送
run_applescript('''
tell application "System Events"
    tell process "WeChat"
        key code 125 using {option down}
        key code 126 using {option down}
        delay 0.5
    end tell
end tell
''')

set_clipboard(MESSAGE)
time.sleep(0.3)
run_applescript('''
tell application "System Events"
    tell process "WeChat"
        keystroke "v" using {command down}
        delay 0.5
        keystroke return
    end tell
end tell
''')
```

**Down 次数调整**：默认 7 次（跳过 1 条网页搜索 + 5 条搜索建议 + 群聊 header）。如果群聊不在第一个，增加次数。发送前必须截图验证。

### 判断联系人 vs 群聊

不确定目标是个人还是群时，先查：

```bash
wechat-cli contacts --query "名字"    # 有结果 → 联系人，用模式 A
wechat-cli members "群名"             # 有结果 → 群聊，用模式 B
```

### 防锁屏（重要依赖）

发送消息依赖 GUI 事件，**屏幕锁定后无法发送**。发送前必须确保屏幕不会锁定：

```bash
# 方法 1：发送前唤醒屏幕 + 阻止休眠（推荐）
caffeinate -u -t 2       # 唤醒显示器
sleep 2                   # 等待唤醒完成
caffeinate -dims -w $$ &  # 当前 shell 存活期间阻止休眠
CAFFEINATE_PID=$!

# ... 执行发送操作 ...

kill $CAFFEINATE_PID 2>/dev/null  # 发送完毕恢复休眠策略
```

```bash
# 方法 2：合盖不休眠（已验证可用，GUI 事件在合盖状态下仍有效）
/usr/bin/osascript -e 'do shell script "pmset -b disablesleep 1 && pmset -a displaysleep 0" with administrator privileges'
# 恢复默认：
# /usr/bin/osascript -e 'do shell script "pmset -b disablesleep 0 && pmset -a displaysleep 2" with administrator privileges'
```

### 注意事项

- **delay 3**（激活后）：必须足够长，确保微信完全前台化
- **tell process "WeChat"**：直接向微信进程发事件，不受窗口遮挡影响
- 发送期间不要操作鼠标键盘
- 消息通过剪贴板粘贴，会临时覆盖剪贴板内容
- **发送前务必先运行 `caffeinate -u -t 2` 唤醒屏幕**

### 发送后验证

发送后必须用 wechat-cli 确认消息到达正确目标：

```bash
wechat-cli history "TARGET_NAME" --limit 3 --format text
```

## 能力二：查看消息（wechat-cli）

wechat-cli 读取微信本地数据库，所有操作只读，数据不出本机。

### 常用命令

#### 最近会话

```bash
wechat-cli sessions --limit 20 --format text
```

#### 聊天记录

```bash
wechat-cli history "姓名或群名" --limit 50 --format text
```

#### 搜索消息

```bash
# 全局搜索
wechat-cli search "关键词" --limit 20 --format text

# 指定聊天内搜索
wechat-cli search "关键词" --chat "聊天名" --limit 20 --format text
```

#### 联系人

```bash
wechat-cli contacts --query "姓名"
```

#### 未读消息

```bash
wechat-cli unread
```

#### 新消息（增量）

```bash
wechat-cli new-messages
```

#### 群成员

```bash
wechat-cli members "群名"
```

#### 聊天统计

```bash
wechat-cli stats "聊天名" --format text
```

#### 导出聊天记录

```bash
# Markdown 格式
wechat-cli export "聊天名" --format markdown --output out.md

# 纯文本格式
wechat-cli export "聊天名" --format txt --output out.txt

# 按时间范围导出
wechat-cli export "聊天名" --format markdown \
    --start-time "2025-01-01" --end-time "2026-06-27" \
    --limit 100000 --output out.md
```

#### 微信收藏

```bash
wechat-cli favorites
```

### wechat-cli 初始化

首次使用或密钥变化时需要初始化：

```bash
# macOS 需关闭 SIP 并给终端 "完全磁盘访问权限"
# Claude Code 内执行：
/usr/bin/osascript -e 'do shell script "wechat-cli init 2>&1" with administrator privileges'

# 或终端内：
sudo wechat-cli init
```

常见问题：
- `task_for_pid failed`：需对微信重签名后重试
- 多账号目录错误：编辑 `~/.wechat-cli/config.json` 修正 `db_dir`
- 权限问题：`sudo chown -R $(whoami):staff ~/.wechat-cli/`

## 隐私与安全

- wechat-cli 只读本地数据库，不联网
- AppleScript 发送通过本地进程通信，不经过任何服务器
- 截图文件仅保存在本地
- 剪贴板内容发送后不会自动清理，注意后续操作
- 不要在包含敏感信息的场景下使用自动发送

## 故障排除

| 问题 | 解决方案 |
|------|----------|
| AppleScript 超时 | 检查辅助功能权限是否授予终端 |
| 搜索到错误联系人 | 使用更精确的名称，或检查微信是否有同名联系人 |
| 消息未发出 | 确认微信窗口未被最小化，delay 时间是否足够 |
| wechat-cli 报错 | 运行 `wechat-cli init` 重新初始化 |
| 找不到聊天记录 | `sessions --limit 20000` 确认会话是否存在 |
