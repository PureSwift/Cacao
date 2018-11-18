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

#if os(iOS) || os(tvOS)
    import UIKit
    import CoreGraphics
#else
    import Cacao
    import Silica
#endif

final class ScrollViewController: UIViewController, UIScrollViewDelegate {
    
    // MARK: - Views
    
    private(set) var scrollView: UIScrollView!
    
    private(set) var logoView: SwiftLogoView!
    
    private(set) var contentView: UIView!
    
    // MARK: - Loading
    
    override func loadView() {
        
        view = UIView(frame: CGRect(x: 0, y: 0, width: 360, height: 560))
        view.backgroundColor = .white
        
        scrollView = UIScrollView(frame: view.frame)
        scrollView.delegate = self
        view.addSubview(scrollView)
        
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        contentView = UIView(frame: scrollView.bounds)
        contentView.backgroundColor = .blue
        contentView.isUserInteractionEnabled = false
        scrollView.addSubview(contentView)
        
        logoView = SwiftLogoView(frame: CGRect(x: 20, y: 20, width: 100, height: 100))
        logoView.pointSize = 100
        logoView.contentMode = .scaleAspectFill
        scrollView.addSubview(logoView)
    }
    
    override func viewWillLayoutSubviews() {
        
        scrollView.frame = view.bounds
        var contentSize = view.bounds.size
        contentSize.width += 100
        contentSize.height += 100
        scrollView.contentSize = contentSize
        contentView.frame = scrollView.bounds
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //scrollView.contentOffset = CGPoint(x: 30, y: 30)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        print("Did scroll")
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        
        print("Will begin dragging")
    }
}

