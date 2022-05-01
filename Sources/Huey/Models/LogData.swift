//
//  File.swift
//  
//
//  Created by Cameron Jackson on 11/5/21.
//

import Foundation

struct LogData: Decodable {
    
    // This maps to SwiftyBeaver.Level
    enum Level: Int, Decodable, CaseIterable, Identifiable, RawRepresentable {
        case verbose = 0
        case debug = 1
        case info = 2
        case warning = 3
        case error = 4
        
        var id: Self {
            self
        }
        
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
        
        var string: String {
            switch self {
            case .verbose:
                return "verbose"
            case .debug:
                return "debug"
            case .info:
                return "info"
            case .warning:
                return "warning"
            case .error:
                return "error"
            }
        }
        
        static var storedLogLevels: Set<Level> {
            let array = UserDefaults.standard.array(forKey: "hueyLoglevel") as? [Int]
            return Set(array?.compactMap { Level(rawValue: $0) } ?? Level.allCases)
        }
        
        static func store(_ levels: Set<Level>) {
            UserDefaults.standard.set(levels.map { $0.rawValue }, forKey: "hueyLoglevel")
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
