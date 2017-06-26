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
        
        view = UIView(frame: CGRect())
        
        view.backgroundColor = UIColor.white
        
        scrollView = UIScrollView(frame: CGRect())
        
        view.addSubview(scrollView)
        
        let logoView = SwiftLogoView(frame: CGRect(origin: .zero, size: CGSize(width: 100, height: 100)))
        logoView.pointSize = 100
        logoView.contentMode = .scaleAspectFill
        
        scrollView.addSubview(logoView)
    }
    
    override func viewWillLayoutSubviews() {
        
        scrollView.frame = view.bounds
        
        var contentSize = scrollView.bounds.size
        contentSize.width += 100
        contentSize.height += 100
        scrollView.contentSize = contentSize
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollView.contentOffset = CGPoint(x: 30, y: 30)
    }
}

