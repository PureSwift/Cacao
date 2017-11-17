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
    
    private(set) var logoView: SwiftLogoView!
    
    private(set) var contentView: UIView!
    
    // MARK: - Loading
    
    override func loadView() {
        
        view = UIView(frame: .zero)
        view.backgroundColor = UIColor.white
        
        scrollView = UIScrollView(frame: .zero)
        view.addSubview(scrollView)
        
        contentView = UIView(frame: .zero)
        contentView.backgroundColor = .blue
        contentView.isUserInteractionEnabled = false
        scrollView.addSubview(contentView)
        
        logoView = SwiftLogoView(frame: CGRect(origin: .zero, size: CGSize(width: 100, height: 100)))
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
        contentView.bounds.size = contentSize
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //scrollView.contentOffset = CGPoint(x: 30, y: 30)
    }
}

