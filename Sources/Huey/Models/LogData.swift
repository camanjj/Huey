//
//  File.swift
//  
//
//  Created by Cameron Jackson on 11/5/21.
//

import Foundation

struct LogData: Decodable {
    
    enum Level: Int, Decodable, CaseIterable {
        case verbose = 1
        case debug
        case info
        case warning
        case error
        
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
