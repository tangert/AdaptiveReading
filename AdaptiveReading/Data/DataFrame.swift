//
//  DataFrame.swift
//  AdaptiveReading
//
//  Created by Tyler Angert on 12/2/18.
//  Copyright © 2018 Tyler Angert. All rights reserved.
//

import Foundation
import SwiftCSVExport

class DataFrame {
    
    var name: String!
    var header: [String]!
    var rows: [[Any]]!
    
    init(){
        self.header =  []
        self.rows  = [[]]
    }
    
    init(header: [String]) {
        self.header = header
    }
    
    func addRow(row: [Any]) {
        self.rows.append(row)
    }
    
    func toCSV() {
        let csv = CSV()
        // How to save file locally?
        
    }
    
}
