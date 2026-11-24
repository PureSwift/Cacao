# The colors, gradients, radii, fonts and metrics of the desktop's look,
# resolved for an appearance. No SwiftUI, no SDL and no D-Bus, so Cacao's
# styles and other UI frameworks (Perry's AppKit) read the same values.

file(GLOB sources CONFIGURE_DEPENDS *.swift)

cacao_add_library(CacaoTokens ${sources})

target_link_libraries(CacaoTokens PUBLIC
  CacaoRender)
