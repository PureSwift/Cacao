# Menus over com.canonical.dbusmenu: a model of menu items, an exporter
# that serves one, and a reader that reads one, for Cacao apps, Perry's
# AppKit and the shell's menu bar. No SwiftUI and no SDL. Linux only.
#
# PureSwift/DBus's module and library come from the Swift resource
# directory (or from search paths in CMAKE_Swift_FLAGS), with the Socket
# and SystemPackage libraries it links.

file(GLOB sources CONFIGURE_DEPENDS *.swift)

cacao_add_library(CacaoDBusMenu ${sources})

# Public: the exporter and reader take and give D-Bus connections and names.
target_link_libraries(CacaoDBusMenu
  PUBLIC
    DBus)
