# Touchpad pinch rotations from Wayland compositors, which SDL doesn't
# report, and layer-shell surfaces for panels and docks. Linux only.

find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)

add_library(CacaoWayland
  gestures.c
  layer_shell.c)

target_include_directories(CacaoWayland
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR})

target_link_libraries(CacaoWayland PRIVATE
  PkgConfig::WAYLAND_CLIENT)

install(TARGETS CacaoWayland
  ARCHIVE DESTINATION ${CACAO_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CACAO_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

# The C module, for the Swift modules that import it.
install(FILES
    include/CacaoWayland.h
    include/module.modulemap
  DESTINATION ${CACAO_INSTALL_CMODULEDIR}/CacaoWayland)
