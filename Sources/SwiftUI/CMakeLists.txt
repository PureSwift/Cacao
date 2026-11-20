# `import SwiftUI` for unmodified sources: re-exports Cacao and its host.

cacao_add_library(SwiftUI
  SwiftUI.swift)

target_link_libraries(SwiftUI PUBLIC
  Cacao
  CacaoSDL)
