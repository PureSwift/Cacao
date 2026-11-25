# The layer tree, drawn with Silica and composited on the GPU.
#
# Silica's modules come from the Swift resource directory (or from search
# paths in CMAKE_Swift_FLAGS): its Cairo backend on Linux, its Quartz (Core Graphics)
# backend on macOS.

file(GLOB sources CONFIGURE_DEPENDS *.swift)

cacao_add_library(CacaoCompositor ${sources})

target_link_libraries(CacaoCompositor PUBLIC
  CacaoRender)

if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
  target_link_libraries(CacaoCompositor PRIVATE
    Silica
    SilicaQuartz)
else()
  target_link_libraries(CacaoCompositor PRIVATE
    Silica
    SilicaCairo)
endif()
