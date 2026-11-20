#!/bin/sh
#
# Builds what Cacao's CMake build takes from the Swift resource directory
# on a system image, into one directory for it to find with
# `-I <dir> -L <dir>`: Silica (with its own CMake build), the Swift modules
# Silica's Cairo backend imports, and the `CSDL3` C module.
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

# The C module for SDL3, from PureSwift/SDL.
[ -d "$work/SDL" ] || git clone --depth 1 https://github.com/PureSwift/SDL.git "$work/SDL"
mkdir -p "$out/CSDL3"
cp "$work/SDL/Sources/CSDL3/module.modulemap" "$work/SDL/Sources/CSDL3/shim.h" "$out/CSDL3/"
