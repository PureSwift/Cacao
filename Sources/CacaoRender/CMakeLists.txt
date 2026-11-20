# The display list and the values it's made of. No SwiftUI.

file(GLOB sources CONFIGURE_DEPENDS *.swift)

cacao_add_library(CacaoRender ${sources})
