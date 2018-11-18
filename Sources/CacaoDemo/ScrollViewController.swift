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
        
        view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        view.backgroundColor = .white
        
        scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        scrollView.delegate = self
        view.addSubview(scrollView)
        
        #if os(iOS)
        if #available(iOS 11.0, *) {
            ((scrollView as NSObject) as? UIKit.UIScrollView)?.contentInsetAdjustmentBehavior = .never
        }
        #endif
        
        contentView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        contentView.backgroundColor = .blue
        contentView.isUserInteractionEnabled = false
        scrollView.addSubview(contentView)
        
        logoView = SwiftLogoView(frame: CGRect(x: 20, y: 20, width: 100, height: 100))
        logoView.pointSize = 100
        logoView.contentMode = .scaleAspectFill
        scrollView.addSubview(logoView)
    }
    
    override func viewWillLayoutSubviews() {
        
        let size = view.bounds.size
        var contentSize = size
        contentSize.width += 100
        contentSize.height += 100
        
        scrollView.frame.size = size
        scrollView.contentSize = contentSize
        contentView.frame.size = size
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.scrollView.setContentOffset(CGPoint(x: 50, y: 50), animated: true)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        print("Did scroll \(scrollView.contentOffset)")
        assert(scrollView.contentOffset == scrollView.bounds.origin)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        
        print("Will begin dragging")
    }
}

