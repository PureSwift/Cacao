# Builds Cacao's libraries as shared Swift libraries for a system image
# (Buildroot and the like), where Swift modules live in the compiler's
# resource directory and apps link them like the OS's own frameworks.
#
# SwiftPM (Package.swift) stays the way to develop and test Cacao.

cmake_minimum_required(VERSION 3.26)

if(POLICY CMP0157)
  # Swift's new build model: modules are emitted on their own, in parallel.
  cmake_policy(SET CMP0157 NEW)
endif()

project(Cacao
  LANGUAGES C Swift)

list(APPEND CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake/modules)

option(BUILD_SHARED_LIBS "Build shared libraries" ON)
option(CACAO_ENABLE_LIBRARY_EVOLUTION "Build with library evolution and emit module interfaces, so apps keep working when Cacao is updated" ON)
option(CACAO_BUILD_HOST "Build CacaoHost and CacaoSDL, which need SDL3" ON)
option(CACAO_BUILD_DEMO "Build the CacaoDemo catalog app" OFF)
option(CACAO_BUILD_MACROS "Build the CacaoMacros compiler plugin with this toolchain (for native builds; build Sources/CacaoMacros on its own for the host when cross compiling)" OFF)
if(CMAKE_SYSTEM_NAME STREQUAL Linux)
  option(CACAO_BUILD_SWIFTUI "Build the SwiftUI and Combine modules that re-export Cacao" ON)
else()
  # They would clash with Apple's.
  set(CACAO_BUILD_SWIFTUI OFF)
endif()

set(CMAKE_Swift_LANGUAGE_VERSION 6)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)

include(CacaoSupport)

add_subdirectory(Sources)

# Cacao's license, and those of the work it includes, such as the Phosphor
# Icons its system symbols are drawn from.
install(FILES
    LICENSE
    ThirdPartyLicenses.md
  DESTINATION ${CMAKE_INSTALL_DATADIR}/doc/Cacao)
