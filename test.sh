#!/bin/bash
#
# test.sh -- 快速编译并覆盖安装 LifeClock 屏保到系统
#
# 用法：
#   ./test.sh              # 编译 Release 版本并安装
#   ./test.sh debug        # 编译 Debug 版本并安装
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/WebViewScreenSaver"
BUILD_DIR="/tmp/LifeClock_build"
SAVER_NAME="LifeClock.saver"
# 系统屏保安装路径（需要 sudo）
INSTALL_DIR="/Library/Screen Savers"

echo "[1/4] 编译..."
mkdir -p "$BUILD_DIR"
SDK=$(xcrun --show-sdk-path)
clang -fobjc-arc \
      -isysroot "$SDK" \
      -I"$SRC_DIR" \
      -F"$SDK/System/Library/Frameworks" \
      -framework WebKit \
      -framework ScreenSaver \
      -framework Foundation \
      -framework AppKit \
      -bundle \
      -arch arm64 \
      -o "$BUILD_DIR/LifeClock" \
      "$SRC_DIR/WebViewScreenSaverView.m" \
      "$SRC_DIR/WVSSConfigController.m" \
      "$SRC_DIR/WVSSConfig.m" \
      "$SRC_DIR/WVSSAddress.m" \
      "$SRC_DIR/WVSSAddressListFetcher.m" \
      "$SRC_DIR/WKWebViewPrivate.m"

echo "编译完成: $BUILD_DIR/LifeClock"

echo "[2/4] 覆盖可执行文件、index.html 和 Info.plist..."
cp "$BUILD_DIR/LifeClock" "$INSTALL_DIR/$SAVER_NAME/Contents/MacOS/LifeClock"
cp "$SRC_DIR/Resources/index.html" "$INSTALL_DIR/$SAVER_NAME/Contents/Resources/index.html"
cp "$SRC_DIR/Info.plist" "$INSTALL_DIR/$SAVER_NAME/Contents/Info.plist"
touch "$INSTALL_DIR/$SAVER_NAME"
echo "文件已更新"

echo "[3/4] 重新签名..."
codesign --sign - --force "$INSTALL_DIR/$SAVER_NAME"
echo "签名完成"

echo "[4/4] 清理进程..."
if pgrep -x "ScreenSaverEngine" >/dev/null 2>&1; then
    killall "ScreenSaverEngine" 2>/dev/null || true
    echo "已停止 ScreenSaverEngine"
else
    echo "ScreenSaverEngine 未在运行"
fi
if pgrep -x "System Preferences" >/dev/null 2>&1; then
    killall "System Preferences" 2>/dev/null || true
fi
if pgrep -x "System Settings" >/dev/null 2>&1; then
    killall "System Settings" 2>/dev/null || true
fi

rm -rf "$BUILD_DIR"

echo ""
echo "安装完成! 打开 系统设置 -> 锁定屏幕 -> 屏幕保护程序 选择 LifeClock 即可测试"
