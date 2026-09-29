#!/bin/zsh
# Прогон тестов логики: решения о замене, опечатки, транслитерация, переводы.
set -e
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -swift-version 5 Core.swift SettingsUI.swift Localization.swift tests/main.swift \
  -o build/LayoutFixerTests -framework Cocoa -framework Carbon 2>&1 | grep -v "warning:" || true
build/LayoutFixerTests
