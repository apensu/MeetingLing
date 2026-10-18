#!/bin/bash
# 一键构建「会议铃铛.app」（原生 Swift/AppKit，无第三方依赖）
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_APP="$HERE/../会议铃铛.app"

# 让 swiftc 的临时文件与模块缓存都落在工作区内，避免沙箱/权限问题
export TMPDIR="$HERE/.tmp"
CACHE="$HERE/.swiftmodulecache"
mkdir -p "$TMPDIR" "$CACHE"

echo "==> 编译 Swift 源码（通用：arm64 + x86_64）…"
swiftc -O -module-cache-path "$CACHE/arm64"   -target arm64-apple-macosx11.0   -o "$HERE/MeetingLing_arm64"   "$HERE/main.swift"
swiftc -O -module-cache-path "$CACHE/x86_64" -target x86_64-apple-macosx11.0 -o "$HERE/MeetingLing_x86_64" "$HERE/main.swift"
lipo -create "$HERE/MeetingLing_arm64" "$HERE/MeetingLing_x86_64" -output "$HERE/MeetingLing"
rm -f "$HERE/MeetingLing_arm64" "$HERE/MeetingLing_x86_64"

echo "==> 组装 .app 包…"
rm -rf "$OUT_APP"
mkdir -p "$OUT_APP/Contents/MacOS" "$OUT_APP/Contents/Resources"
cp "$HERE/MeetingLing" "$OUT_APP/Contents/MacOS/MeetingLing"
cp "$HERE/Info.plist" "$OUT_APP/Contents/Info.plist"
cp "$HERE/AppIcon.icns" "$OUT_APP/Contents/Resources/AppIcon.icns"

echo "==> ad-hoc 签名…"
codesign --force --sign - "$OUT_APP"

echo "==> 完成：$OUT_APP"
du -sh "$OUT_APP"
