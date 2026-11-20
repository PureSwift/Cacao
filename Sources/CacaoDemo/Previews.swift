//
//  Previews.swift
//  CacaoDemo
//
//  Created by Alsey Coleman Miller on 11/20/26.
//

import CacaoRender
import Foundation
import CacaoSDL

// Previews of the catalog's screens. In a debug build they're drawn to the
// build folder when the demo launches. They need the CacaoMacros compiler
// plugin, so the CMake build leaves this file out unless it builds the plugin.

#Preview {
    ControlsScreen()
}

#Preview("Shapes") {
    ShapesScreen()
}
