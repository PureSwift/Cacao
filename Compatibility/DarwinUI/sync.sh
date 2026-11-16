#!/bin/bash
# Copies DarwinUI's sources and tests from DarwinAppRuntime: on Linux
# unmodified, through Cacao's SwiftUI and Combine modules; on macOS, where
# those are Apple's, with Cacao in their place. RenderingTests hosts views in
# an NSHostingView, so this package has its own, hosting them in Cacao.
#
# DarwinAppRuntime comes from DARWIN_APP_RUNTIME_PATH, or a checkout beside
# Cacao's.
set -e
cd "$(dirname "$0")"
D=${DARWIN_APP_RUNTIME_PATH:-../../../DarwinAppRuntime}
mkdir -p Sources/DarwinUI Tests/DarwinUITests
rm -f Sources/DarwinUI/*.swift
if [ "$(uname)" = Linux ]; then
  # DarwinUI's macOS-only code is for any platform but iOS.
  for f in $D/Sources/DarwinUI/*.swift; do
    sed -e 's/^#if os(macOS)$/#if !os(iOS)/' "$f" > Sources/DarwinUI/$(basename $f)
  done
  for f in $D/Tests/DarwinUITests/*.swift; do
    case $(basename $f) in RenderingTests.swift) continue;; esac
    cp "$f" Tests/DarwinUITests/
  done
else
  for f in $D/Sources/DarwinUI/*.swift; do
    sed -e 's/^import SwiftUI$/import Cacao/' -e 's/^import Combine$//' "$f" > Sources/DarwinUI/$(basename $f)
  done
  for f in $D/Tests/DarwinUITests/*.swift; do
    case $(basename $f) in RenderingTests.swift) continue;; esac
    sed -e 's/^import SwiftUI$/import Cacao/' -e 's/^import Combine$/import Cacao/' "$f" > Tests/DarwinUITests/$(basename $f)
  done
fi
