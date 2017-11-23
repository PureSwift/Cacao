//
//  TimerViewController.swift
//  CacaoDemo
//
//  Created by Alsey Coleman Miller on 11/20/17.
//

import Foundation

#if os(iOS)
    import UIKit
#else
    import Cacao
    import Silica
#endif

final class TimerViewController: UIViewController {
    
    // MARK: - Views
    
    private(set) weak var label: UILabel!
    
    // MARK: - Properties
    
    private var timer: Timer!
    
    private lazy var dateFormatter: DateFormatter = {
       
        let dateFormatter = DateFormatter()
        
        dateFormatter.dateStyle = .long
        
        dateFormatter.timeStyle = .long
        
        return dateFormatter
    }()
    
    // MARK: - Loading
    
    override func loadView() {
        
        view = UIView()
        
        let label = UILabel()
        label.textAlignment = .center
        self.label = label
        
        view.backgroundColor = UIColor.white
        
        view.addSubview(label)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateUI()
        
        #if os(macOS)
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(timerDidFire), userInfo: nil, repeats: true)
        #else
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.updateUI() }
        #endif
    }
    
    override func viewWillLayoutSubviews() {
        
        label.frame = view.bounds
    }
    
    // MARK: - Methods
    
    #if os(macOS)
    @objc private func timerDidFire(_ sender: AnyObject? = nil) { updateUI() }
    #endif
    
    private func updateUI() {
        
        label.text = dateFormatter.string(from: Date())
    }
}
