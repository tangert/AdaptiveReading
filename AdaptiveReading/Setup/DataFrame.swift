//
//  DataFrame.swift
//  AdaptiveReading
//
//  Created by Tyler Angert on 12/2/18.
//  Copyright © 2018 Tyler Angert. All rights reserved.
//
import Foundation

class DataFrame {
    
    var name: String!
    var header: [String]!
    var rows: [[String:Any]]!
    
    init(){
        self.header =  []
        self.rows  = [[String:Any]]()
        self.name = ""
    }
    
    init(header: [String]) {
        self.header = header
    }
    
    func addRow(row: [String: Any]) {
        self.rows.append(row)
    }
    
    func parseHeader(header: [String]) -> String {
        var headerString = ""
        for (i, col) in header.enumerated() {
            headerString += "\(col)"
            // Add a comma to the end of the element except for the last element
            if i != header.count-1 {
                headerString += ","
            }
        }
        // Finally append a new line
        headerString += "\n"
        return headerString
    }
    
    func parseRow(header: [String], row: [String: Any]) -> String {
        var rowString = ""
        for (i, col) in header.enumerated() {
            if let rowVal = row[col] {
                rowString += "\(rowVal)"
            } else {
                rowString += "_"
            }
            if i != header.count-1 {
                rowString += ","
            }
        }
        rowString += "\n"
        return rowString
    }
    
    func toCSV() {
        
        var csvText = ""
        let headerText = parseHeader(header: self.header)
        var rowText = ""
        
        // Add all the rows
        for row in rows {
            let parsed = parseRow(header: header, row: row)
            rowText += parsed
        }
        
        // Compile into one text
        csvText += headerText + rowText
        let fileName = "\(self.name!).csv"
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(fileName)
            do {
                try csvText.write(to: fileURL, atomically: false, encoding: .utf8)
            }
            catch {
                print("Error exporting your csv")
            }
        }
    }
    
    
    
}
