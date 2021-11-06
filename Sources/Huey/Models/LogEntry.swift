//
//  File.swift
//  
//
//  Created by Cameron Jackson on 11/5/21.
//

import Foundation

struct LogEntry: Identifiable {
    let id = UUID()
    let data: LogData
    let context: [String: AnyObject]?
}
