#!/bin/bash

set -u

CONFIG_FILE="${1:-}"

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
  echo "域名配置不存在：$CONFIG_FILE"
  exit 1
fi

FEILIAN_IFACE=$(/sbin/ifconfig | /usr/bin/awk '
  /^utun[0-9]+:/ {
    iface=$1
    sub(":", "", iface)
  }

  /inet 172\.16\./ {
    print iface
    exit
  }
')

if [ -z "$FEILIAN_IFACE" ]; then
  echo "未找到飞连 VPN 接口。请先连接飞连。"
  exit 0
fi

echo "飞连接口：$FEILIAN_IFACE"

HOSTS=$(/usr/bin/awk '
  /^[[:space:]]*$/ { next }
  /^[[:space:]]*#/ { next }
  {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "")
    print
  }
' "$CONFIG_FILE" | /usr/bin/sort -u)

if [ -z "$HOSTS" ]; then
  echo "没有可绑定的域名。"
  exit 0
fi

while IFS= read -r TARGET_HOST; do
  [ -z "$TARGET_HOST" ] && continue
  echo "处理域名：$TARGET_HOST"

  TARGET_IPS=$(/usr/bin/dscacheutil -q host -a name "$TARGET_HOST" | /usr/bin/awk '/ip_address:/ {print $2}' | /usr/bin/sort -u)

  if [ -z "$TARGET_IPS" ]; then
    echo "  无法解析：$TARGET_HOST"
    continue
  fi

  while IFS= read -r TARGET_IP; do
    [ -z "$TARGET_IP" ] && continue

    case "$TARGET_IP" in
      198.18.*|198.19.*)
        echo "  跳过 Fake IP：$TARGET_IP"
        continue
        ;;
    esac

    CURRENT_IFACE=$(/sbin/route get "$TARGET_IP" 2>/dev/null | /usr/bin/awk '/interface:/ {print $2; exit}')

    if [ "$CURRENT_IFACE" = "$FEILIAN_IFACE" ]; then
      echo "  已绑定：$TARGET_IP -> $FEILIAN_IFACE"
      continue
    fi

    /sbin/route -n delete -host "$TARGET_IP" >/dev/null 2>&1

    if /sbin/route -n add -host "$TARGET_IP" -interface "$FEILIAN_IFACE" >/dev/null 2>&1; then
      echo "  绑定成功：$TARGET_IP -> $FEILIAN_IFACE"
    else
      echo "  绑定失败：$TARGET_IP -> $FEILIAN_IFACE"
    fi
  done <<EOF
$TARGET_IPS
EOF
done <<EOF
$HOSTS
EOF

