# A catalog app exercising Cacao's components.

add_executable(CacaoDemo
  CacaoDemoApp.swift)

target_compile_options(CacaoDemo PRIVATE
  -parse-as-library
  "SHELL:-package-name Cacao")

target_link_libraries(CacaoDemo PRIVATE
  Cacao
  CacaoSDL)

# Previews expand through the CacaoMacros compiler plugin, so they're only
# built when the plugin is.
if(CACAO_BUILD_MACROS)
  target_sources(CacaoDemo PRIVATE
    Previews.swift)
  add_dependencies(CacaoDemo CacaoMacros)
  target_compile_options(CacaoDemo PRIVATE
    "SHELL:-load-plugin-library $<TARGET_FILE:CacaoMacros>")
endif()

install(TARGETS CacaoDemo
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
