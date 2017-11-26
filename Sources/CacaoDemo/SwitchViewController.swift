//
//  SwitchViewController.swift
//  CacaoDemo
//
//  Created by Alsey Coleman Miller on 6/15/17.
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

final class SwitchViewController: UIViewController {
    
    // MARK: - Views
    
    private(set) weak var switchView: UISwitch!
    
    // MARK: - Loading
    
    override func loadView() {
        
        view = UIView()
        
        let switchView = UISwitch()
        self.switchView = switchView
        
        view.backgroundColor = UIColor.white
        
        view.addSubview(switchView)
    }
    
    override func viewWillLayoutSubviews() {
        
        switchView.center = view.center
    }
}
