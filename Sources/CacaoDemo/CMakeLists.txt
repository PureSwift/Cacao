# A catalog app exercising Cacao's components.

add_executable(CacaoDemo
  CacaoDemoApp.swift)

target_compile_options(CacaoDemo PRIVATE
  -parse-as-library
  "SHELL:-package-name Cacao")

target_link_libraries(CacaoDemo PRIVATE
  Cacao
  CacaoSDL)

install(TARGETS CacaoDemo
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
