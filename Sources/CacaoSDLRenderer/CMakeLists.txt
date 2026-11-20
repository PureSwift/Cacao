# The compositor's SDL3 renderer backend, and `HostRenderer`, which draws
# display lists with a renderer that belongs to someone else. No windows,
# loop or input: a UI framework with its own uses this without CacaoHost.
#
# The `SDL3Swift` module and the `CSDL3` C module it wraps come from
# PureSwift/SDL, in the Swift resource directory (or from search paths in
# CMAKE_Swift_FLAGS). Importing `SDL3Swift` links its library.

find_package(SDL3 REQUIRED CONFIG)

file(GLOB sources CONFIGURE_DEPENDS *.swift)

cacao_add_library(CacaoSDLRenderer ${sources})

target_link_libraries(CacaoSDLRenderer
  PUBLIC
    CacaoRender
    CacaoCompositor
  PRIVATE
    SDL3::SDL3)
