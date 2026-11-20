#!/bin/sh
#
# Builds what Cacao's CMake build takes from the Swift resource directory
# on a system image, into one directory for it to find with
# `-I <dir> -L <dir>`: Silica (with its own CMake build), the Swift modules
# Silica's Cairo backend imports, and PureSwift/SDL's `SDL3Swift` module
# with the `CSDL3` C module it wraps.
#
#   build-cmake-dependencies.sh <output directory> [<work directory>]
#
# SILICA_DIR uses a checkout of Silica instead of cloning it.

set -eu

out=$1
work=${2:-${TMPDIR:-/tmp}/cacao-cmake-dependencies}
mkdir -p "$out" "$work"

# pkg-config's compiler flags, for the C headers the modules wrap.
xcc() {
  for flag in $(pkg-config --cflags "$@"); do
    printf -- '-Xcc %s ' "$flag"
  done
}

silica=${SILICA_DIR:-$work/Silica}
if [ ! -d "$silica" ]; then
  git clone --depth 1 https://github.com/PureSwift/Silica.git "$silica"
fi

flags="-I $out -L $out"
if [ "$(uname -s)" != Darwin ]; then
  "$silica/.github/scripts/build-cairo-modules.sh" "$out" "$work/cairo"
  flags="$flags $(xcc cairo fontconfig freetype2)"
fi

cmake -S "$silica" -B "$work/silica-build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_Swift_FLAGS="$flags" \
  -DCMAKE_INSTALL_PREFIX="$out" \
  -DSILICA_INSTALL_LIBDIR=. \
  -DSILICA_INSTALL_SWIFTMODULEDIR=.
cmake --build "$work/silica-build"
cmake --install "$work/silica-build"

# PureSwift/SDL has no CMake build of its own, so this compiles its SDL3
# module's sources directly, next to the C module they wrap.
[ -d "$work/SDL" ] || git clone --depth 1 https://github.com/PureSwift/SDL.git "$work/SDL"
mkdir -p "$out/CSDL3"
cp "$work/SDL/Sources/CSDL3/module.modulemap" "$work/SDL/Sources/CSDL3/shim.h" "$out/CSDL3/"

case "$(uname -s)" in
  Darwin) suffix=dylib ;;
  *) suffix=so ;;
esac

# shellcheck disable=SC2046
swiftc -emit-library -emit-module -parse-as-library -swift-version 6 -O \
  -module-name SDL3Swift -module-link-name SDL3Swift \
  -emit-module-path "$out/SDL3Swift.swiftmodule" \
  -o "$out/libSDL3Swift.$suffix" \
  -I "$out" \
  $(xcc sdl3) $(pkg-config --libs-only-L sdl3) \
  "$work/SDL/Sources/SDL3"/*.swift
