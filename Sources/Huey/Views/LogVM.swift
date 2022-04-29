//
//  File.swift
//  
//
//  Created by Cameron Jackson on 11/5/21.
//

import Foundation
import Combine

class LogsVM: ObservableObject {
    
    @Published var entries: [LogEntry]
    private static let decoder = JSONDecoder()
    
    init() {
        do {
            let logData = try Log.getLogFile()
            let logString = String(data: logData, encoding: .utf8)
            let logLines = logString?.components(separatedBy: CharacterSet.newlines).reversed() ?? []
            entries = logLines.compactMap { line in
                guard let lineData = line.data(using: .utf8) else {
                    return nil
                }
                guard let data = try? LogsVM.decoder.decode(LogData.self, from: lineData) else {
                    return nil
                }
                var context: [String: AnyObject]?
                if let json = try? JSONSerialization.jsonObject(with: lineData, options: []) as? [String: Any], let jsonContext = json["context"] as? [String: AnyObject] {
                    context = jsonContext
                }
                
                return LogEntry(data: data, context: context)
                
            }
            
        } catch {
            Log.error("Could not load log files", error: error, meta: nil)
            entries = []
        }
    }
}
