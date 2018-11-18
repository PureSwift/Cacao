//
//  TableViewController.swift
//  CacaoDemo
//
//  Created by Alsey Coleman Miller on 11/18/17.
//

import Foundation

#if os(iOS) || os(tvOS)
import UIKit
import CoreGraphics
#else
import Cacao
import Silica
#endif

final class TableViewController: UITableViewController {
    
    // MARK: - Properties
    
    private var data = Array((1...5)) {
        
        didSet { tableView.reloadData() }
    }
    
    private let cellReuseIdentifier = "Cell"
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        #if os(iOS)
        if #available(iOS 11.0, *) {
            ((tableView as NSObject) as? UIKit.UIScrollView)?.contentInsetAdjustmentBehavior = .never
        }
        #endif
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        
        //tableView.estimatedRowHeight = 44
        //tableView.rowHeight = UITableViewAutomaticDimension
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.data = Array((1...100))
        }
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return data.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
        
        configure(cell: cell, at: indexPath)
        
        return cell
    }
    
    // MARK: - Methods
    
    private func configure(cell: UITableViewCell, at indexPath: IndexPath) {
        
        let item = self[indexPath]
        
        cell.textLabel?.text = item
    }
    
    private subscript (indexPath: IndexPath) -> String {
        
        let number = data[indexPath.row]
        
        return "test \(number)"
    }
}
