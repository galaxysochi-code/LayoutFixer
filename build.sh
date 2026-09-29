#!/bin/zsh
# Сборка LayoutFixer.app из исходника. Ничего не скачивает.
set -e
cd "$(dirname "$0")"
APP=build/LayoutFixer.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 Core.swift SettingsUI.swift Localization.swift main.swift -o "$APP/Contents/MacOS/LayoutFixer" -framework Cocoa -framework Carbon
mkdir -p "$APP/Contents/Resources" build/tmp
swiftc -swift-version 5 make_icon.swift -o build/tmp/make_icon
build/tmp/make_icon build/tmp/AppIcon.iconset
iconutil -c icns build/tmp/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.layoutfixer</string>
  <key>CFBundleName</key><string>LayoutFixer</string>
  <key>CFBundleExecutable</key><string>LayoutFixer</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHumanReadableCopyright</key><string>© 2026 Vladislav Tolmachev</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Готово: $PWD/$APP"
