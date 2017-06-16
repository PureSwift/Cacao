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
import Cacao
import Silica

final class SwitchViewController: UIViewController {
    
    // MARK: - Views
    
    private(set) var switchView: UISwitch!
    
    // MARK: - Loading
    
    override func loadView() {
        
        switchView = UISwitch(frame: CGRect())
        
        self.view = UIView(frame: CGRect())
        
        view.backgroundColor = UIColor.white
        
        view.addSubview(switchView)
    }
}
