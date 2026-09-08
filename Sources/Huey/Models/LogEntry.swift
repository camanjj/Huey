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

    var context: [String: LogValue]? { data.context }
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
                    message: randomString(length: 13),
                    context: [
                        "user": ["id": 7, "name": "Bob", "admin": true],
                        "items": [1, 2, 3],
                        "coupon": nil,
                        "json": "what's up"
                    ]
                )
            )
        }
    }
}

fileprivate func randomString(length: Int) -> String {
  let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  return String((0..<length).map{ _ in letters.randomElement()! })
}
