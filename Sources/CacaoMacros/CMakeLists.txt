# The compiler plugin that implements `@Entry`.
#
# A plugin runs in the compiler, so it's built for the machine that
# compiles, not the one Cacao runs on. When cross compiling, configure this
# directory on its own with the host's toolchain; for a native build, the
# top level adds it with CACAO_BUILD_MACROS.

cmake_minimum_required(VERSION 3.26)

if(POLICY CMP0157)
  cmake_policy(SET CMP0157 NEW)
endif()

project(CacaoMacros
  LANGUAGES Swift)

if(NOT SWIFT_SYSTEM_NAME)
  if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
    set(SWIFT_SYSTEM_NAME macosx)
  else()
    string(TOLOWER "${CMAKE_SYSTEM_NAME}" SWIFT_SYSTEM_NAME)
  endif()
endif()

find_package(SwiftSyntax QUIET)
if(NOT SwiftSyntax_FOUND)
  message(STATUS "SwiftSyntax_DIR not provided, checking out a copy of swift-syntax")
  include(FetchContent)
  FetchContent_Declare(SwiftSyntax
    GIT_REPOSITORY https://github.com/swiftlang/swift-syntax.git
    GIT_TAG 604.0.0)
  FetchContent_MakeAvailable(SwiftSyntax)
endif()

add_library(CacaoMacros SHARED
  EntryMacro.swift
  PreviewMacro.swift)

target_compile_options(CacaoMacros PRIVATE
  -parse-as-library)

# No entry point: the compiler loads the library and finds the macros.
target_compile_definitions(CacaoMacros PRIVATE
  CACAO_MACROS_LIBRARY)

target_link_libraries(CacaoMacros PUBLIC
  SwiftSyntax::SwiftSyntax
  SwiftSyntax::SwiftSyntaxMacros
  SwiftSyntax::SwiftDiagnostics)

set_target_properties(CacaoMacros PROPERTIES
  # Installed into lib/swift/host/plugins, and loads swift-syntax from
  # lib/swift/host and the runtime from lib/swift/<system>.
  INSTALL_RPATH "$ORIGIN/../../../swift/${SWIFT_SYSTEM_NAME}:$ORIGIN/.."
  INSTALL_REMOVE_ENVIRONMENT_RPATH ON)

install(TARGETS CacaoMacros
  LIBRARY DESTINATION lib/swift/host/plugins
  RUNTIME DESTINATION bin)
