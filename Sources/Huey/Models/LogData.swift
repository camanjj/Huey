//
//  File.swift
//
//
//  Created by Cameron Jackson on 11/5/21.
//

import Foundation

struct LogData: Decodable {

    typealias Level = LogLevel

    let level: Level
    let timestamp: Double
    let file: String
    let line: Int
    let function: String
    let thread: String
    let message: String
}
