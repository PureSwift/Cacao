//
//  App.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 12/14/24.
//

import Cacao

@main
struct CacaoDemo: Cacao.App {
    
    @MainActor
    static let window: Window = {
        let window = Window(title: "Cacao")
        
        return window
    }()
}
