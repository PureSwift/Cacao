//
//  HelloWorldViewController.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/22/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cacao
import Silica

final class HelloWorldViewController: UIViewController {
    
    // MARK: - Views
    
    var logoView: SwiftLogoView!
    
    //weak var button: UIButton!
    
    //weak var label: UILabel!
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        logoView = SwiftLogoView(frame: CGRect(x: 0, y: 0, width: 150, height: 150))
        
        logoView.backgroundColor = UIColor(cgColor: CGColor.clear)
        
        view.addSubview(logoView)
    }
}