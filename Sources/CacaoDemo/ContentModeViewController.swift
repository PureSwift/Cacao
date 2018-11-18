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

#if os(iOS) || os(tvOS)
    import UIKit
    import CoreGraphics
#else
    import Cacao
    import Silica
#endif

final class ContentModeViewController: UIViewController {
    
    // MARK: - Views
    
    private(set) weak var label: UILabel!
    
    private(set) weak var logoView: SwiftLogoView!
    
    private(set) weak var button: UIButton!
    
    // MARK: - Properties
    
    let modes: [UIViewContentMode] = [.center, .redraw, .scaleToFill, .scaleAspectFit, .scaleAspectFill, .top, .bottom, .left, .right, .topLeft, .topRight, .bottomLeft, .bottomRight]
    
    // MARK: - Loading
    
    override func loadView() {
        
        let logoView = SwiftLogoView(frame: .zero) // since we dont use autoresizing, initial size doesnt matter
        
        self.view = logoView
        
        logoView.contentMode = modes[0]
        
        logoView.pointSize = 150
        
        let label = UILabel() // layoutSubviews will set size
        
        label.text = "\(modes[0])"
        
        label.textColor = .white
        
        let button = UIButton()
        
        #if os(iOS) || os(tvOS)
        button.addTarget(self, action: #selector(_changeMode), for: .touchUpInside)
        #else
        let selector = Selector(name: "changeMode", action: { (_, sender, _) in self.changeMode(sender as! UIButton)
        })
        button.addTarget(self, action: selector, for: .touchUpInside)
        #endif
        
        label.textAlignment = .center
        
        view.addSubview(button)
        
        view.addSubview(label)
        
        view.backgroundColor = UIColor.blue
        
        self.button = button
        self.label = label
        self.logoView = logoView
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
    
    #if os(iOS) || os(tvOS)
    @IBAction func _changeMode(_ sender: UIButton) { changeMode(sender) }
    #endif
    
    func changeMode(_ sender: UIButton) {
        
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
