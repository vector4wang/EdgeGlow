#!/bin/bash
set -e

# ============================================================
# EdgeGlow 构建脚本
# 用法: ./build.sh [-s] [-n] [-d]
#   -s  代码签名
#   -n  公证
#   -d  打包 DMG
# ============================================================

APP_NAME="EdgeGlow"
BUNDLE_ID="com.edgeglow.app"
VERSION="1.3.1"
BUILD_DIR="Build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
RELEASE_DIR="Release"

# 开发者签名信息 (签名/公证时需要配置)
DEV_ID="${DEV_ID:-}"           # "Developer ID Application: Your Name (TEAM_ID)"
APPLE_ID="${APPLE_ID:-}"       # Apple ID 邮箱
TEAM_ID="${TEAM_ID:-}"         # Team ID
APP_PASSWORD="${APP_PASSWORD:-}"  # App-specific password

# ============================================================
# 参数解析
# ============================================================
DO_SIGN=false
DO_NOTARIZE=false
DO_DMG=false
while getopts "snd" opt; do
    case $opt in
        s) DO_SIGN=true ;;
        n) DO_NOTARIZE=true ;;
        d) DO_DMG=true ;;
        *) echo "用法: $0 [-s] [-n] [-d]" && exit 1 ;;
    esac
done
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ============================================================
# Step 1: 编译
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✦ EdgeGlow Build v${VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

info "编译 Swift 源文件 (Universal Binary)..."

mkdir -p "${BUILD_DIR}"

SOURCE_FILES=$(find Sources -name "*.swift" -type f)
CURRENT_ARCH=$(uname -m)

# 根据当前架构，只编译另一架构
if [ "$CURRENT_ARCH" = "arm64" ]; then
    swiftc -o "${BUILD_DIR}/${APP_NAME}" \
        ${SOURCE_FILES} \
        -framework Cocoa \
        -framework Network \
        -framework SwiftUI \
        -framework ServiceManagement \
        -framework UserNotifications \
        -O \
        -target arm64-apple-macos13

    swiftc -o "${BUILD_DIR}/${APP_NAME}_x86_64" \
        ${SOURCE_FILES} \
        -framework Cocoa \
        -framework Network \
        -framework SwiftUI \
        -framework ServiceManagement \
        -framework UserNotifications \
        -O \
        -target x86_64-apple-macos13

    lipo -create -output "${BUILD_DIR}/${APP_NAME}_universal" \
        "${BUILD_DIR}/${APP_NAME}" \
        "${BUILD_DIR}/${APP_NAME}_x86_64"
    mv "${BUILD_DIR}/${APP_NAME}_universal" "${BUILD_DIR}/${APP_NAME}"
    rm -f "${BUILD_DIR}/${APP_NAME}_x86_64"
else
    swiftc -o "${BUILD_DIR}/${APP_NAME}" \
        ${SOURCE_FILES} \
        -framework Cocoa \
        -framework Network \
        -framework SwiftUI \
        -framework ServiceManagement \
        -framework UserNotifications \
        -O \
        -target x86_64-apple-macos13

    swiftc -o "${BUILD_DIR}/${APP_NAME}_arm64" \
        ${SOURCE_FILES} \
        -framework Cocoa \
        -framework Network \
        -framework SwiftUI \
        -framework ServiceManagement \
        -framework UserNotifications \
        -O \
        -target arm64-apple-macos13

    lipo -create -output "${BUILD_DIR}/${APP_NAME}_universal" \
        "${BUILD_DIR}/${APP_NAME}" \
        "${BUILD_DIR}/${APP_NAME}_arm64"
    mv "${BUILD_DIR}/${APP_NAME}_universal" "${BUILD_DIR}/${APP_NAME}"
    rm -f "${BUILD_DIR}/${APP_NAME}_arm64"
fi

info "编译完成"

# ============================================================
# Step 2: 组装 .app bundle
# ============================================================
info "组装 ${APP_NAME}.app..."

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
cp Resources/Info.plist "${APP_BUNDLE}/Contents/"

# 如果有图标
if [ -f "Resources/EdgeGlow.icns" ]; then
    cp Resources/EdgeGlow.icns "${APP_BUNDLE}/Contents/Resources/"
fi

chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

info "App Bundle 组装完成 → ${APP_BUNDLE}"

# ============================================================
# Step 3: 代码签名 (可选)
# ============================================================
if $DO_SIGN || $DO_NOTARIZE; then
    if [ -z "$DEV_ID" ]; then
        warn "未设置 DEV_ID，使用 ad-hoc 签名"
        codesign --force --deep --sign - "${APP_BUNDLE}"
    else
        info "使用 Developer ID 签名..."
        codesign --force --deep --sign "${DEV_ID}" \
            --options runtime \
            --timestamp \
            "${APP_BUNDLE}"
    fi
    info "签名完成"
fi

# ============================================================
# Step 4: 公证 (可选)
# ============================================================
if $DO_NOTARIZE; then
    if [ -z "$APPLE_ID" ] || [ -z "$TEAM_ID" ] || [ -z "$APP_PASSWORD" ]; then
        error "公证需要设置 APPLE_ID, TEAM_ID, APP_PASSWORD 环境变量"
    fi

    info "提交公证..."

    # 先打包 zip
    ditto -c -k --keepParent "${APP_BUNDLE}" "${BUILD_DIR}/${APP_NAME}.zip"

    xcrun notarytool submit "${BUILD_DIR}/${APP_NAME}.zip" \
        --apple-id "${APPLE_ID}" \
        --team-id "${TEAM_ID}" \
        --password "${APP_PASSWORD}" \
        --wait

    info "公证通过，stapling..."
    xcrun stapler staple "${APP_BUNDLE}"

    info "公证完成"
fi

# ============================================================
# Step 5: 打包 DMG (可选)
# ============================================================
if $DO_DMG; then
    info "打包 DMG..."

    mkdir -p "${RELEASE_DIR}"
    DMG_PATH="${RELEASE_DIR}/${APP_NAME}-v${VERSION}.dmg"

    # 删除旧 DMG
    rm -f "${DMG_PATH}"

    # 创建临时 DMG 目录
    DMG_DIR="${BUILD_DIR}/dmg_staging"
    rm -rf "${DMG_DIR}"
    mkdir -p "${DMG_DIR}"
    cp -R "${APP_BUNDLE}" "${DMG_DIR}/"
    ln -s /Applications "${DMG_DIR}/Applications"

    # 创建 DMG
    hdiutil create \
        -volname "${APP_NAME}" \
        -srcfolder "${DMG_DIR}" \
        -ov \
        -format UDZO \
        "${DMG_PATH}"

    rm -rf "${DMG_DIR}"

    info "DMG 打包完成 → ${DMG_PATH}"
fi

# ============================================================
# 完成
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "构建成功！"
echo ""
echo "  App:    ${APP_BUNDLE}"
if $DO_DMG; then
echo "  DMG:    ${DMG_PATH}"
fi
echo ""
echo "  运行:   open ${APP_BUNDLE}"
if ! $DO_DMG; then
echo ""
echo "  打包:   ./build.sh -d"
echo "  签名:   ./build.sh -s"
echo "  公证:   ./build.sh -s -n -d"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
