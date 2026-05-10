#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="飞连路由助手"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ROOT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$ROOT_DIR/resources/bind-feilian-routes.sh" "$APP_DIR/Contents/Resources/bind-feilian-routes.sh"
chmod +x "$APP_DIR/Contents/Resources/bind-feilian-routes.sh"

clang "$ROOT_DIR/src/FeilianRouteHelper.m" \
  -fobjc-arc \
  -framework Cocoa \
  -framework Security \
  -o "$APP_DIR/Contents/MacOS/FeilianRouteHelper"

chmod +x "$APP_DIR/Contents/MacOS/FeilianRouteHelper"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR"
fi

echo "Built: $APP_DIR"

