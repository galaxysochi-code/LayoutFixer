#!/bin/zsh
# Собирает установщик LayoutFixer.dmg из build/LayoutFixer.app
set -e
cd "$(dirname "$0")"
[ -d build/LayoutFixer.app ] || ./build.sh
rm -rf build/dmg build/LayoutFixer.dmg
mkdir -p build/dmg
cp -R build/LayoutFixer.app build/dmg/
ln -s /Applications "build/dmg/Программы"
hdiutil create -volname "LayoutFixer" -srcfolder build/dmg -ov -format UDZO build/LayoutFixer.dmg >/dev/null
rm -rf build/dmg
echo "Установщик: $PWD/build/LayoutFixer.dmg"
