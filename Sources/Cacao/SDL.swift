//
//  SDL.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/7/17.
//

import SDL

internal extension Bool {
    
    @inline(__always)
    func sdlAssert(function: String = #function, file: StaticString = #file, line: UInt = #line) {
        
        guard self else { sdlFatalError(function: function, file: file, line: line) }
    }
}

internal extension Optional {
    
    @inline(__always)
    func sdlAssert(function: String = #function, file: StaticString = #file, line: UInt = #line) -> Wrapped {
        
        guard let value = self
            else { sdlFatalError(function: function, file: file, line: line) }
        
        return value
    }
}

@_silgen_name("_cacao_sdl_fatal_error")
internal func sdlFatalError(function: String = #function, file: StaticString = #file, line: UInt = #line) -> Never {
    
    if let error = SDL.errorDescription {
        
        fatalError("SDL error: \(error)", file: file, line: line)
        
    } else {
        
        fatalError("An SDL error occurred", file: file, line: line)
    }
}
