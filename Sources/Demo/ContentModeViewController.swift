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
    
    lazy var labelContainer: ContentView = ContentView(frame: self.labelContainerFrame(for: self.defaultFrame), content: self.label, mode: .center)
    
    lazy var logoView: SwiftLogoView = SwiftLogoView()
    
    lazy var button: Button = Button(frame: self.buttonFrame(for: self.defaultFrame), content: self.logoView, mode: .center)
    
    // MARK: - Properties
    
    let defaultFrame = Rect(size: Size(width: 320, height: 320))
    
    let modes: [ContentMode] = [.scaleToFill, .aspectFit, .aspectFill, .center]
    
    // MARK: - Loading
    
    private func loadView() -> UIView {
        
        let defaultFrame = Rect(size: Size(width: 320, height: 320))
        
        let backgroundView = UIView(frame: defaultFrame)
        
        label.backgroundColor = UIColor(cgColor: Color.blue)
        
        backgroundView.addSubview(button)
        
        backgroundView.addSubview(labelContainer)
        
        return backgroundView
    }
    
    // MARK: - Layout
    
    func layoutView() {
        
        // from Paint Code
        
        labelContainer.frame = labelContainerFrame(for: view.frame)
        
        button.frame = buttonFrame(for: view.frame)
    }
    
    private func labelContainerFrame(for frame: Rect) -> Rect {
        
        return Rect(x: frame.minX + floor(frame.width * 0.00000 + 0.5), y: frame.minY + floor(frame.height * 0.82812 + 0.5), width: floor(frame.width * 1.00000 + 0.5) - floor(frame.width * 0.00000 + 0.5), height: floor(frame.height * 1.00000 + 0.5) - floor(frame.height * 0.82812 + 0.5))
    }
    
    private func buttonFrame(for frame: Rect) -> Rect {
    
        return Rect(x: frame.minX + floor(frame.width * 0.00000 + 0.5), y: frame.minY + floor(frame.height * 0.00000 + 0.5), width: floor(frame.width * 1.00000 + 0.5) - floor(frame.width * 0.00000 + 0.5), height: floor(frame.height * 0.82812 + 0.5) - floor(frame.height * 0.00000 + 0.5))
    }
}