//
//  TableViewController.swift
//  CacaoDemo
//
//  Created by Alsey Coleman Miller on 11/18/17.
//

import Foundation
import Cacao
import Silica

final class TableViewController: UITableViewController {
    
    private let data = ["test1", "test2"]
    
    private let cellReuseIdentifier = "Cell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
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
    
    private func configure(cell: UITableViewCell, at indexPath: IndexPath) {
        
        let item = self[indexPath]
        
        cell.textLabel?.text = item
    }
    
    private subscript (indexPath: IndexPath) -> String {
        
        return data[indexPath.row]
    }
}
