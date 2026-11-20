# The SwiftUI API, evaluation and layout. No SDL and no GPU.
#
# The `@Entry` macro is declared here and implemented by the CacaoMacros
# compiler plugin, which apps that use it load with `-load-plugin-library`
# or `-plugin-path`.

file(GLOB_RECURSE sources CONFIGURE_DEPENDS *.swift)

cacao_add_library(Cacao ${sources})

target_link_libraries(Cacao PUBLIC
  CacaoRender)
