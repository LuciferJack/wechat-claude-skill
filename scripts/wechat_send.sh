#!/bin/bash
# wechat_send.sh — 通过 AppleScript 向微信联系人/群发送消息
# 用法: ./wechat_send.sh "联系人名" "消息内容"

set -e

TARGET="${1:?用法: $0 <联系人名> <消息内容>}"
MESSAGE="${2:?用法: $0 <联系人名> <消息内容>}"

# 防锁屏：唤醒显示器 + 阻止休眠
caffeinate -u -t 2 2>/dev/null
sleep 2
caffeinate -dims -w $$ &
CAFFEINATE_PID=$!
trap "kill $CAFFEINATE_PID 2>/dev/null" EXIT

osascript <<APPLESCRIPT
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

        set the clipboard to "${TARGET}"
        keystroke "v" using {command down}
        delay 1.5

        keystroke return
        delay 2.5

        keystroke return
        delay 2

        key code 125 using {option down}
        key code 126 using {option down}
        delay 0.5

        set the clipboard to "${MESSAGE}"
        keystroke "v" using {command down}
        delay 0.5

        keystroke return
    end tell
end tell
APPLESCRIPT

echo "✓ 已发送到「${TARGET}」"

# 验证
sleep 2
if command -v wechat-cli &>/dev/null; then
    echo "--- 最近消息 ---"
    wechat-cli history "${TARGET}" --limit 3 --format text 2>/dev/null || true
fi
