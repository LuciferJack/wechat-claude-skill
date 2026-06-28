#!/bin/bash
# wechat_batch_send.sh — 向同一联系人/群发送多条消息
# 用法: ./wechat_batch_send.sh "联系人名" "消息1" "消息2" "消息3" ...

set -e

TARGET="${1:?用法: $0 <联系人名> <消息1> [消息2] ...}"
shift

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for msg in "$@"; do
    echo ">>> 发送: ${msg:0:30}..."
    "$SCRIPT_DIR/wechat_send.sh" "$TARGET" "$msg"
    echo "    等待 5 秒..."
    sleep 5
done

echo "✓ 全部 $# 条消息已发送到「${TARGET}」"
