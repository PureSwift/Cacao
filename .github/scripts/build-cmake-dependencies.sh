#!/bin/sh
#
# Builds what Cacao's CMake build takes from the Swift resource directory
# on a system image, into one directory for it to find with
# `-I <dir> -L <dir>`: Silica (with its own CMake build), the Swift modules
# Silica's Cairo backend imports, PureSwift/SDL's `SDL3Swift` module
# with the `CSDL3` C module it wraps, and on Linux PureSwift/DBus with the
# PureSwift/Socket and apple/swift-system libraries it links.
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
  -DSILICA_BUILD_COREGRAPHICS=OFF \
  -DSILICA_INSTALL_LIBDIR=. \
  -DSILICA_INSTALL_SWIFTMODULEDIR=.
cmake --build "$work/silica-build"
cmake --install "$work/silica-build"

# PureSwift/SDL has no CMake build of its own, so this compiles its SDL3
# module's sources directly, next to the C module they wrap.
[ -d "$work/SDL" ] || git -c advice.detachedHead=false clone --depth 1 --branch 3.3.0 https://github.com/PureSwift/SDL.git "$work/SDL"
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

# MARK: D-Bus

# On Linux, PureSwift/DBus, which `CacaoDBus` imports. It and the libraries
# it links have no installable CMake build of their own, so their sources
# are compiled directly, at the versions SwiftPM resolves.
if [ "$(uname -s)" = Darwin ]; then
  exit 0
fi

mkdir -p "$work/objects"

# Compiles a C module's sources into objects and copies its headers and
# module map to <out>/<module>, where `-I <out>` finds them.
c_module() { # c_module <module> <source directory>
  mkdir -p "$out/$1"
  cp -R "$2/include/." "$out/$1/"
  for source in "$2"/*.c; do
    clang -c -fPIC -O2 -I "$2/include" -o "$work/objects/$1-$(basename "$source" .c).o" "$source"
  done
}

# Compiles a Swift module into a shared library and its module.
swift_library() { # swift_library <module> <source directory> [<swiftc argument>...]
  module=$1
  sources=$2
  shift 2
  # shellcheck disable=SC2046
  swiftc -emit-library -emit-module -parse-as-library -O \
    -module-name "$module" -module-link-name "$module" \
    -emit-module-path "$out/$module.swiftmodule" \
    -o "$out/lib$module.$suffix" \
    -I "$out" -L "$out" \
    "$@" \
    $(find "$sources" -name '*.swift' | sort)
}

[ -d "$work/DBus" ] || git -c advice.detachedHead=false clone --depth 1 --branch 0.3.1 https://github.com/PureSwift/DBus.git "$work/DBus"

# A caller can provide the core DBus module, for example when the shell's
# build has already compiled it. The generated clients still need modules.
if [ ! -e "$out/DBus.swiftmodule" ]; then
  [ -d "$work/swift-system" ] || git -c advice.detachedHead=false clone --depth 1 --branch 1.9.0 https://github.com/apple/swift-system.git "$work/swift-system"
  system="$work/swift-system"
  c_module CSystem "$system/Sources/CSystem"
  mkdir -p "$out/CSystemStatFS"
  cp "$system/Sources/CSystemStatFS/"* "$out/CSystemStatFS/"
  rm -f "$out/CSystemStatFS/CMakeLists.txt"

  # The availability macros swift-system's Package.swift defines, with the
  # versions its CMake build lists. Each has spaces, so they're collected as
  # positional arguments.
  set --
  for version in 0.0.1 0.0.2 0.0.3 1.1.0 1.1.1 1.2.0 1.2.1 1.3.0 1.3.1 1.3.2 1.4.0 1.7.0 1.9.0 199; do
    set -- "$@" -enable-experimental-feature \
      "AvailabilityMacro=System $version:macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, visionOS 1.0"
  done
  swift_library SystemPackage "$system/Sources/System" \
    -swift-version 6 -package-name swift-system \
    -D SYSTEM_PACKAGE \
    -enable-experimental-feature Lifetimes \
    -enable-upcoming-feature MemberImportVisibility \
    "$@" \
    "$work"/objects/CSystem-*.o

  [ -d "$work/Socket" ] || git -c advice.detachedHead=false clone --depth 1 --branch 0.7.0 https://github.com/PureSwift/Socket.git "$work/Socket"
  c_module CSocket "$work/Socket/Sources/CSocket"
  swift_library Socket "$work/Socket/Sources/Socket" \
    -swift-version 6 \
    -lSystemPackage \
    "$work"/objects/CSocket-*.o

  swift_library DBus "$work/DBus/Sources/DBus" \
    -swift-version 6 \
    -lSocket -lSystemPackage
fi

for module in FreedesktopPortal StatusNotifier; do
  if [ ! -e "$out/$module.swiftmodule" ]; then
    swift_library "$module" "$work/DBus/Sources/$module" -swift-version 6 -lDBus
  fi
done
