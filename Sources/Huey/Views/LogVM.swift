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

@MainActor
final class LogsVM: ObservableObject {

    @Published private(set) var entries: [LogEntry] = []
    @Published private(set) var isLoading = false

    private var allEntries: [LogEntry] = []
    private var logLevels = LogData.Level.storedLogLevels
    private var observer: NSKeyValueObservation?

    init() {
        observer = UserDefaults.standard.observe(\.hueyLoglevel, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.logLevels = LogData.Level.storedLogLevels
                self.entries = self.allEntries.filter { self.logLevels.contains($0.data.level) }
            }
        }
    }

    deinit {
        observer?.invalidate()
    }

    func load() async {
        guard !isLoading, allEntries.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        let urls = Log.getLogFiles()
        let parsed = await Task.detached(priority: .userInitiated) {
            LogsVM.parse(urls: urls)
        }.value

        allEntries = parsed
        entries = parsed.filter { logLevels.contains($0.data.level) }
    }

    nonisolated private static func parse(urls: [URL]) -> [LogEntry] {
        let decoder = JSONDecoder()
        var entries: [LogEntry] = []
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let string = String(data: data, encoding: .utf8) else {
                continue
            }
            let lines = string.components(separatedBy: CharacterSet.newlines).reversed()
            for line in lines {
                guard let lineData = line.data(using: .utf8),
                      !lineData.isEmpty,
                      let logData = try? decoder.decode(LogData.self, from: lineData) else {
                    continue
                }
                var context: [String: AnyObject]?
                if let json = try? JSONSerialization.jsonObject(with: lineData, options: []) as? [String: Any],
                   let jsonContext = json["context"] as? [String: AnyObject] {
                    context = jsonContext
                }
                entries.append(LogEntry(data: logData, context: context))
            }
        }
        return entries
    }
}
