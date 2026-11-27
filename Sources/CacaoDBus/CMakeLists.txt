# The desktop's services over D-Bus: the settings portal's appearance. No
# SwiftUI and no SDL. Linux only.
#
# PureSwift/DBus's module and library come from the Swift resource
# directory (or from search paths in CMAKE_Swift_FLAGS), with the Socket
# and SystemPackage libraries it links.

file(GLOB sources CONFIGURE_DEPENDS *.swift)

cacao_add_library(CacaoDBus ${sources})

target_link_libraries(CacaoDBus
  PUBLIC
    CacaoTokens
  PRIVATE
    DBus
    FreedesktopPortal)
