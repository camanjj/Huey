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

extension LogEntry {
    static func generate(_ x: Int) -> [LogEntry] {
        (0..<x).map { _ -> LogEntry in
            LogEntry(
                data: LogData(
                    level: .allCases[Int.random(in: 0..<5)],
                    timestamp: Date().timeIntervalSince1970,
                    file: "F.swift",
                    line: Int.random(in: 0...300),
                    function: "f()",
                    thread: "main",
                    message: randomString(length: 13)
                ),
                context: ["json": ["what's up"]] as? [String: AnyObject]
            )
        }
    }
}

fileprivate func randomString(length: Int) -> String {
  let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  return String((0..<length).map{ _ in letters.randomElement()! })
}
