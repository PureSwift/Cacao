//
//  ContentModeViewController.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/29/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cacao
import Silica

final class ContentModeViewController: ViewController {
    
    // MARK: - Views
    
    lazy var view: View = self.loadView()
    
    lazy var label: UIView = UIView(frame: Rect(x: 0, y: 0, width: 50, height: 20))
    
    lazy var labelContainer: ContentView = ContentView(content: self.label, mode: .center)
    
    lazy var logoView: SwiftLogoView = SwiftLogoView()
    
    lazy var button: Button = Button(content: self.logoView, mode: self.modes[0])
    
    // MARK: - Properties
    
    let modes: [ContentMode] = [.center, .scaleToFill, .aspectFit, .aspectFill]
    
    // MARK: - Loading
    
    private func loadView() -> UIView {
        
        let backgroundView = UIView()
        
        label.backgroundColor = UIColor(cgColor: Color.blue)
        
        button.action = changeMode
        
        backgroundView.addSubview(button)
        
        backgroundView.addSubview(labelContainer)
        
        return backgroundView
    }
    
    func layoutView() {
        
        let frame = view.frame
        
        // from Paint Code
        
        labelContainer.frame = Rect(x: frame.minX + floor(frame.width * 0.00000 + 0.5), y: frame.minY + floor(frame.height * 0.82812 + 0.5), width: floor(frame.width * 1.00000 + 0.5) - floor(frame.width * 0.00000 + 0.5), height: floor(frame.height * 1.00000 + 0.5) - floor(frame.height * 0.82812 + 0.5))
        
        button.frame = Rect(x: frame.minX + floor(frame.width * 0.00000 + 0.5), y: frame.minY + floor(frame.height * 0.00000 + 0.5), width: floor(frame.width * 1.00000 + 0.5) - floor(frame.width * 0.00000 + 0.5), height: floor(frame.height * 0.82812 + 0.5) - floor(frame.height * 0.00000 + 0.5))
    }
    
    // MARK: - Methods
    
    func changeMode(sender: Button) {
        
        let currentMode = button.contentView.mode
        
        let currentIndex = modes.index(of: currentMode)!
        
        var nextIndex = currentIndex + 1
        
        if currentIndex == modes.count - 1 {
            
            nextIndex = 0
        }
        
        let newMode = modes[nextIndex]
        
        button.contentView.mode = newMode
        
        print("Changing to \(newMode)")
    }
}