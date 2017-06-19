//
//  ScrollViewController.swift
//  CacaoDemo
//
//  Created by Alsey Coleman Miller on 6/18/17.
//

#if os(Linux)
    import Glibc
#elseif os(macOS)
    import Darwin.C
#endif

import Foundation
import Cacao
import Silica

final class ScrollViewController: UIViewController {
    
    // MARK: - Views
    
    private(set) var scrollView: UIScrollView!
    
    // MARK: - Loading
    
    override func loadView() {
        
        scrollView = UIScrollView(frame: CGRect())
        
        view = scrollView
        
        view.backgroundColor = UIColor.white
        
        let logoView = SwiftLogoView(frame: CGRect(origin: .zero, size: CGSize(width: 100, height: 100)))
        
        view.addSubview(logoView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollView.contentOffset = CGPoint(x: 30, y: 30)
    }
}

