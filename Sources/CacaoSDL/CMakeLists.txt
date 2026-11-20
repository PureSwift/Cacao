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
