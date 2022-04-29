//
//  File.swift
//  
//
//  Created by Cameron Jackson on 11/5/21.
//

import Foundation

struct LogData: Decodable {
    
    // This maps to SwiftyBeaver.Level
    enum Level: Int, Decodable, CaseIterable {
        case verbose = 0
        case debug = 1
        case info = 2
        case warning = 3
        case error = 4
        
        var emoji: String {
            switch self {
            case .verbose:
                return "💜"
            case .debug:
                return "💚"
            case .info:
                return "ℹ️"
            case .warning:
                return "⚠️"
            case .error:
                return "🛑"
            }
        }
    }
    
    let level: Level
    let timestamp: Double
    let file: String
    let line: Int
    let function: String
    let thread: String
    let message: String
}
