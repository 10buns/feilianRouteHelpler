#!/bin/bash

set -u

CONFIG_FILE="${1:-}"

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
  echo "域名配置不存在：$CONFIG_FILE"
  exit 1
fi

echo "执行用户 UID：$(/usr/bin/id -u)"

FEILIAN_INFO=$(/sbin/ifconfig | /usr/bin/awk '
  /^utun[0-9]+:/ {
    iface=$1
    sub(":", "", iface)
  }

  /^[a-z0-9]+:/ && $1 !~ /^utun[0-9]+:/ {
    iface=""
  }

  /inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {
    if (iface !~ /^utun[0-9]+$/) {
      next
    }

    ip=$2
    split(ip, parts, ".")
    first=parts[1] + 0
    second=parts[2] + 0

    if (first == 198 && (second == 18 || second == 19)) {
      next
    }

    if (first == 172 && second >= 16 && second <= 31) {
      print iface " " ip
      exit
    }

    if (first == 100 && second >= 64 && second <= 127) {
      print iface " " ip
      exit
    }

    if (first == 10) {
      print iface " " ip
      exit
    }

    if (first == 192 && second == 168) {
      print iface " " ip
      exit
    }
  }
')

FEILIAN_IFACE=$(printf '%s\n' "$FEILIAN_INFO" | /usr/bin/awk '{print $1; exit}')
FEILIAN_IP=$(printf '%s\n' "$FEILIAN_INFO" | /usr/bin/awk '{print $2; exit}')

if [ -z "$FEILIAN_IFACE" ]; then
  echo "未找到飞连 VPN 接口。请先连接飞连。"
  exit 0
fi

echo "飞连接口：$FEILIAN_IFACE"
echo "飞连接口地址：$FEILIAN_IP"

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

    DELETE_OUTPUT=$(/sbin/route -n delete -host "$TARGET_IP" 2>&1)
    DELETE_STATUS=$?
    if [ "$DELETE_STATUS" -ne 0 ] && ! printf '%s' "$DELETE_OUTPUT" | /usr/bin/grep -qi 'not in table'; then
      echo "  删除旧路由提示：$DELETE_OUTPUT"
    fi

    ADD_OUTPUT=$(/sbin/route -n add -host "$TARGET_IP" -interface "$FEILIAN_IFACE" 2>&1)
    ADD_STATUS=$?
    if [ "$ADD_STATUS" -eq 0 ]; then
      echo "  绑定成功：$TARGET_IP -> $FEILIAN_IFACE"
    else
      echo "  绑定失败：$TARGET_IP -> $FEILIAN_IFACE"
      echo "  route add 输出：$ADD_OUTPUT"
    fi
  done <<EOF
$TARGET_IPS
EOF
done <<EOF
$HOSTS
EOF
