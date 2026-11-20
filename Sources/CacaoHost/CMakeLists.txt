# SDL3 windows, the main loop and frame clock, input and the SDL3 renderer
# backend, showing whatever implements `HostScene`. No SwiftUI.
#
# The `SDL3Swift` module and the `CSDL3` C module it wraps come from
# PureSwift/SDL, in the Swift resource directory (or from search paths in
# CMAKE_Swift_FLAGS). Importing `SDL3Swift` links its library.

find_package(SDL3 REQUIRED CONFIG)

file(GLOB sources CONFIGURE_DEPENDS *.swift)

cacao_add_library(CacaoHost ${sources})

target_link_libraries(CacaoHost
  PUBLIC
    CacaoRender
    CacaoCompositor
  PRIVATE
    SDL3::SDL3)

if(CMAKE_SYSTEM_NAME STREQUAL Linux)
  # Public, so modules that import CacaoHost find the C module too when
  # it's built without library evolution.
  target_link_libraries(CacaoHost PUBLIC
    CacaoWayland)
endif()
