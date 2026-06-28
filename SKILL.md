---
name: wechat-mac
description: >-
  macOS 微信自动化技能。支持发送消息（AppleScript）和查看/搜索聊天记录（wechat-cli）。
  覆盖：发消息、查历史、搜索、联系人、未读、群成员、导出等全部操作。
version: 1.0.0
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

### 发送流程

向任意联系人或群聊发送文本消息，执行以下 AppleScript：

```bash
osascript <<'APPLESCRIPT'
tell application "WeChat" to activate
delay 3

tell application "System Events"
    tell process "WeChat"
        set frontmost to true
        delay 0.5
        
        -- 清除之前状态
        key code 53
        delay 0.5
        
        -- Cmd+F 打开搜索
        keystroke "f" using {command down}
        delay 1
        
        -- 粘贴联系人/群名
        set the clipboard to "TARGET_NAME"
        keystroke "v" using {command down}
        delay 1.5
        
        -- 第一次 Enter：提交搜索
        keystroke return
        delay 2.5
        
        -- 第二次 Enter：选中第一个搜索结果
        keystroke return
        delay 2
        
        -- Option+Down/Up：导航到输入框
        key code 125 using {option down}
        key code 126 using {option down}
        delay 0.5
        
        -- 粘贴消息内容
        set the clipboard to "MESSAGE_CONTENT"
        keystroke "v" using {command down}
        delay 0.5
        
        -- Enter 发送
        keystroke return
    end tell
end tell
APPLESCRIPT
```

### 关键参数

| 参数 | 说明 |
|------|------|
| `TARGET_NAME` | 联系人名或群聊名（精确匹配优先） |
| `MESSAGE_CONTENT` | 消息内容，支持中文、emoji、特殊字符 |

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
# 方法 2：长期保持屏幕常亮（适合批量发送场景）
caffeinate -dims &
# 操作完成后 kill 掉 caffeinate 进程
```

**注意**：`caffeinate` 只能阻止自动锁屏/休眠，如果用户已经手动锁屏（如合盖），需要先解锁才能操作。

```bash
# 方法 3：合盖不休眠（已验证可用，GUI 事件在合盖状态下仍有效）
/usr/bin/osascript -e 'do shell script "pmset -b disablesleep 1 && pmset -a displaysleep 0" with administrator privileges'
# 恢复默认：
# /usr/bin/osascript -e 'do shell script "pmset -b disablesleep 0 && pmset -a displaysleep 2" with administrator privileges'
```

### 注意事项

- **delay 3**（激活后）：必须足够长，确保微信完全前台化
- **两次 Enter**：第一次提交搜索词，第二次选中第一个匹配结果。缺一不可
- **Option+Down/Up**：从搜索结果区域导航到输入框，这是关键步骤
- **tell process "WeChat"**：直接向微信进程发事件，不受窗口遮挡影响
- 发送期间不要操作鼠标键盘
- 消息通过剪贴板粘贴，会临时覆盖剪贴板内容
- **发送前务必先运行 `caffeinate -u -t 2` 唤醒屏幕**

### 发送多条消息

多条消息之间需要间隔，每条消息独立执行完整的搜索→发送流程：

```bash
# 消息之间间隔 5 秒
for msg in "消息一" "消息二" "消息三"; do
    osascript -e "
    tell application \"WeChat\" to activate
    delay 3
    tell application \"System Events\"
        tell process \"WeChat\"
            set frontmost to true
            delay 0.5
            key code 53
            delay 0.5
            keystroke \"f\" using {command down}
            delay 1
            set the clipboard to \"TARGET_NAME\"
            keystroke \"v\" using {command down}
            delay 1.5
            keystroke return
            delay 2.5
            keystroke return
            delay 2
            key code 125 using {option down}
            key code 126 using {option down}
            delay 0.5
            set the clipboard to \"$msg\"
            keystroke \"v\" using {command down}
            delay 0.5
            keystroke return
        end tell
    end tell"
    sleep 5
done
```

### 发送验证

发送后用 wechat-cli 验证：

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
