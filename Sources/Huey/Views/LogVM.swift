//
//  File.swift
//  
//
//  Created by Cameron Jackson on 11/5/21.
//

import Foundation
import Combine

// https://stackoverflow.com/a/47856467/1273152
extension UserDefaults {
    @objc var hueyLoglevel: [Int] {
        return array(forKey: "hueyLoglevel") as? [Int] ?? []
    }
}

final class LogsVM: ObservableObject {
    
    @Published var entries: [LogEntry] = []
    
    private var allEntries: [LogEntry]
    private var logLevels = LogData.Level.storedLogLevels
    private static let decoder = JSONDecoder()
    private var observer: NSKeyValueObservation?

    
    init() {
        do {
            let logData = try Log.getLogFile()
            let logString = String(data: logData, encoding: .utf8)
            let logLines = logString?.components(separatedBy: CharacterSet.newlines).reversed() ?? []
            allEntries = logLines.compactMap { line in
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
            allEntries = []
        }
        
        entries = allEntries.filter { logLevels.contains($0.data.level) }
        
        observer = UserDefaults.standard.observe(\.hueyLoglevel, options: [.new]) { [weak self] _, _ in
            guard let self = self else { return }
            self.logLevels = LogData.Level.storedLogLevels
            self.entries = self.allEntries.filter { self.logLevels.contains($0.data.level) }
        }
    }
    
    deinit {
        observer?.invalidate()
    }
}
