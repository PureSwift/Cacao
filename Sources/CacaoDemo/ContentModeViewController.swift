//
//  ContentModeViewController.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/29/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if os(Linux)
    import Glibc
#elseif os(macOS)
    import Darwin.C
#endif

import Foundation
import Cacao
import Silica

final class ContentModeViewController: UIViewController {
    
    // MARK: - Views
    
    private(set) var label: UILabel!
    
    private(set) var logoView: SwiftLogoView!
    
    private(set) var button: UIButton!
    
    // MARK: - Properties
    
    let modes: [UIViewContentMode] = [.center, .redraw, .scaleToFill, .scaleAspectFit, .scaleAspectFill, .top, .bottom, .left, .right, .topLeft, .topRight, .bottomLeft, .bottomRight]
    
    // MARK: - Loading
    
    override func loadView() {
        
        logoView = SwiftLogoView(frame: CGRect()) // since we dont use autoresizing, initial size doesnt matter
        
        self.view = logoView
        
        logoView.contentMode = modes[0]
        
        logoView.pointSize = 150
        
        label = UILabel(frame: CGRect()) // layoutSubviews will set size
        
        label.text = "\(modes[0])"
        
        label.textColor = UIColor.white
        
        button = UIButton(frame: CGRect())
        
        let selector = Selector(name: "changeMode", action: { (_, sender, _) in self.changeMode(sender: sender as! UIButton) })
        
        button.addTarget(self, action: selector, for: .touchUpInside)
        
        label.textAlignment = .center
        
        view.addSubview(button)
        
        view.addSubview(label)
        
        view.backgroundColor = UIColor.blue
    }
    
    override func viewWillLayoutSubviews() {
        
        let frame = view.frame
        
        // from Paint Code
        
        label.frame = CGRect(x: frame.minX + floor(frame.width * 0.00000 + 0.5),
                             y: frame.minY + floor(frame.height * 0.82812 + 0.5),
                             width: floor(frame.width * 1.00000 + 0.5) - floor(frame.width * 0.00000 + 0.5),
                             height: floor(frame.height * 1.00000 + 0.5) - floor(frame.height * 0.82812 + 0.5))
        
        button.frame = CGRect(x: frame.minX + floor(frame.width * 0.00000 + 0.5),
                              y: frame.minY + floor(frame.height * 0.00000 + 0.5),
                              width: floor(frame.width * 1.00000 + 0.5) - floor(frame.width * 0.00000 + 0.5),
                              height: floor(frame.height * 0.82812 + 0.5) - floor(frame.height * 0.00000 + 0.5))
        
        logoView.frame = button.frame
    }
    
    // MARK: - Actions
    
    func changeMode(sender: UIButton) {
        
        let currentMode = logoView.contentMode
        
        let currentIndex = modes.index(of: currentMode)!
        
        var nextIndex = currentIndex + 1
        
        if currentIndex == modes.count - 1 {
            
            nextIndex = 0
        }
        
        let newMode = modes[nextIndex]
        
        logoView.contentMode = newMode
        
        label.text = "\(newMode)"
        
        print("Changing to \(newMode)")
    }
}
