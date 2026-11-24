# SDL3 windows, the main loop and frame clock and input, showing whatever
# implements `HostScene` with the SDL3 renderer. No SwiftUI.
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
    CacaoSDLRenderer
  PRIVATE
    SDL3::SDL3)

if(CMAKE_SYSTEM_NAME STREQUAL Linux)
  # Wayland's gestures and layer shell, and the settings portal's
  # appearance over D-Bus. Public, so modules that import CacaoHost find
  # these modules too when it's built without library evolution.
  target_link_libraries(CacaoHost PUBLIC
    CacaoWayland
    CacaoDBus)
endif()
