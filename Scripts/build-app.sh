#!/bin/bash
set -e

APP_NAME="PassVault"
BUNDLE_ID="com.spboucher.passvault"
VERSION="1.0.0"
IDENTITY="Developer ID Application: Simon-Pierre Boucher (3YM54G49SN)"
KEYCHAIN_PROFILE="MacLustr-Notarize"
ENTITLEMENTS="Entitlements/PassVault.entitlements"
APP_DIR=".build/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$PROJECT_DIR"

case "${1:-build}" in
    build)
        echo "Building (debug)..."
        swift build 2>&1
        echo ""
        echo "Build complete."
        ;;

    release)
        echo "Building (release)..."
        swift build -c release 2>&1
        echo ""
        echo "Release binary: .build/release/${APP_NAME}"
        ;;

    app)
        echo "=== Building .app bundle ==="
        swift build -c release 2>&1

        rm -rf "${APP_DIR}"
        mkdir -p "${APP_DIR}/Contents/MacOS"
        mkdir -p "${APP_DIR}/Contents/Resources"

        cp .build/release/${APP_NAME} "${APP_DIR}/Contents/MacOS/"

        RESOURCE_BUNDLE=".build/arm64-apple-macosx/release/PassVault_PassVault.bundle"
        if [ -d "${RESOURCE_BUNDLE}" ]; then
            cp -R "${RESOURCE_BUNDLE}" "${APP_DIR}/Contents/Resources/"
        fi

        if [ -f "Sources/Resources/AppIcon.icns" ]; then
            cp Sources/Resources/AppIcon.icns "${APP_DIR}/Contents/Resources/AppIcon.icns"
        fi

        echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

        cat > "${APP_DIR}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
PLIST

        codesign --force --sign - --deep "${APP_DIR}" 2>&1

        echo "App bundle created: ${APP_DIR}"
        ;;

    sign)
        echo "=== Signing ==="
        if [ ! -d "${APP_DIR}" ]; then
            echo "No .app bundle found. Run '$0 app' first."
            exit 1
        fi

        echo "Signing ${APP_DIR} with: ${IDENTITY}"
        codesign --force --deep --options runtime \
            --entitlements "${ENTITLEMENTS}" \
            --sign "${IDENTITY}" \
            --timestamp \
            "${APP_DIR}" 2>&1

        echo ""
        echo "Verifying signature..."
        codesign --verify --deep --strict --verbose=2 "${APP_DIR}" 2>&1
        echo ""
        echo "Signature valid."
        ;;

    dmg)
        echo "=== Creating DMG ==="
        if [ ! -d "${APP_DIR}" ]; then
            echo "No .app bundle found. Run '$0 app' first."
            exit 1
        fi

        rm -f "${DMG_NAME}"

        DMG_TEMP="dmg_temp"
        rm -rf "${DMG_TEMP}"
        mkdir -p "${DMG_TEMP}"
        cp -R "${APP_DIR}" "${DMG_TEMP}/"
        ln -s /Applications "${DMG_TEMP}/Applications"

        hdiutil create -volname "${APP_NAME}" \
            -srcfolder "${DMG_TEMP}" \
            -ov -format UDZO \
            "${DMG_NAME}" 2>&1

        rm -rf "${DMG_TEMP}"

        echo "Signing DMG..."
        codesign --force --sign "${IDENTITY}" --timestamp "${DMG_NAME}" 2>&1

        echo ""
        echo "DMG created: ${DMG_NAME}"
        ;;

    notarize)
        echo "=== Notarizing ==="
        if [ ! -f "${DMG_NAME}" ]; then
            echo "No DMG found. Run '$0 dmg' first."
            exit 1
        fi

        echo "Submitting ${DMG_NAME} to Apple..."
        xcrun notarytool submit "${DMG_NAME}" \
            --keychain-profile "${KEYCHAIN_PROFILE}" \
            --wait 2>&1

        echo ""
        echo "Stapling notarization ticket..."
        xcrun stapler staple "${DMG_NAME}" 2>&1

        echo "Stapling .app..."
        xcrun stapler staple "${APP_DIR}" 2>&1

        echo ""
        echo "Verifying..."
        spctl --assess --type open --context context:primary-signature -v "${DMG_NAME}" 2>&1 || true
        spctl --assess --verbose=2 "${APP_DIR}" 2>&1 || true

        echo ""
        echo "Notarization complete."
        ;;

    status)
        echo "=== Notarization History ==="
        xcrun notarytool history --keychain-profile "${KEYCHAIN_PROFILE}" 2>&1
        ;;

    log)
        if [ -z "$2" ]; then
            echo "Usage: $0 log <submission-id>"
            exit 1
        fi
        echo "=== Notarization Log ==="
        xcrun notarytool log "$2" --keychain-profile "${KEYCHAIN_PROFILE}" 2>&1
        ;;

    dist)
        echo "=== Full Distribution Pipeline ==="
        echo ""
        echo "Step 1/5: Build .app"
        bash "$0" app
        echo ""
        echo "Step 2/5: Sign"
        bash "$0" sign
        echo ""
        echo "Step 3/5: Create DMG"
        bash "$0" dmg
        echo ""
        echo "Step 4/5: Notarize"
        bash "$0" notarize
        echo ""
        echo "Step 5/5: Done"
        echo ""
        echo "============================================"
        echo "  ${DMG_NAME} is ready for distribution"
        echo "============================================"
        ;;

    verify)
        echo "=== Verification ==="
        echo ""
        echo "Code signature:"
        codesign --verify --deep --strict --verbose=2 "${APP_DIR}" 2>&1
        echo ""
        echo "Gatekeeper assessment:"
        spctl --assess --verbose=2 "${APP_DIR}" 2>&1 || true
        echo ""
        echo "Staple check (app):"
        xcrun stapler validate "${APP_DIR}" 2>&1 || true
        echo ""
        if [ -f "${DMG_NAME}" ]; then
            echo "Staple check (dmg):"
            xcrun stapler validate "${DMG_NAME}" 2>&1 || true
        fi
        ;;

    *)
        echo "Usage: $0 {build|release|app|sign|dmg|notarize|status|log|dist|verify}"
        echo ""
        echo "  build      - Debug build"
        echo "  release    - Release build"
        echo "  app        - Create .app bundle (release)"
        echo "  sign       - Code sign the .app"
        echo "  dmg        - Create and sign DMG"
        echo "  notarize   - Submit to Apple, wait, staple"
        echo "  status     - Notarization history"
        echo "  log <id>   - Notarization log for submission"
        echo "  dist       - Full pipeline: app -> sign -> dmg -> notarize"
        echo "  verify     - Check signature + Gatekeeper + staple"
        ;;
esac
