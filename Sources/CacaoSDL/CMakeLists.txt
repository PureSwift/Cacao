# SwiftUI on the host: a view graph as each window's scene.

find_package(SDL3 REQUIRED CONFIG)

file(GLOB sources CONFIGURE_DEPENDS *.swift)

cacao_add_library(CacaoSDL ${sources})

target_link_libraries(CacaoSDL
  PUBLIC
    Cacao
    CacaoHost
  PRIVATE
    CacaoRender
    CacaoCompositor
    CacaoScrollPhysics
    SDL3::SDL3)

if(CMAKE_SYSTEM_NAME STREQUAL Linux)
  # The app's menus, served to the desktop's menu bar over D-Bus.
  target_link_libraries(CacaoSDL PRIVATE
    CacaoDBusMenu)
endif()
