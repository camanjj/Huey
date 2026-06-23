//  Created by Cameron Jackson on 4/13/19.
//  Copyright © 2021 Cameron Jackson. All rights reserved.
//

import Foundation

public enum Log {

    public static var enableLogging = true

    private static let defaultFileDestination: FileDestination = {
        let id = DestinationPreferences.identifier(for: FileDestination.self)
        return FileDestination(
            prettyPrint: DestinationPreferences.prettyPrint(for: id),
            escapeStrings: DestinationPreferences.escapeStrings(for: id)
        )
    }()

    private static let destinationsLock = NSLock()
    private static var _destinations: [LogDestination] = {
        var list: [LogDestination] = [defaultFileDestination]
        #if DEBUG
        let id = DestinationPreferences.identifier(for: SystemLogDestination.self)
        list.append(SystemLogDestination(
            prettyPrint: DestinationPreferences.prettyPrint(for: id),
            escapeStrings: DestinationPreferences.escapeStrings(for: id)
        ))
        #endif
        return list
    }()

    public static func addDestination(_ destination: LogDestination) {
        destinationsLock.lock()
        defer { destinationsLock.unlock() }
        _destinations.append(destination)
    }

    public static func removeAllDestinations() {
        destinationsLock.lock()
        defer { destinationsLock.unlock() }
        _destinations.removeAll()
    }

    public static func destinationsSnapshot() -> [LogDestination] {
        destinationsLock.lock()
        defer { destinationsLock.unlock() }
        return _destinations
    }

    public static func verbose(_ message: String, meta: [String: Any]? = nil, line: Int = #line, function: String = #function, file: String = #file) {
        dispatch(level: .verbose, message: message, meta: meta, line: line, function: function, file: file)
    }

    public static func debug(_ message: String, meta: [String: Any]? = nil, line: Int = #line, function: String = #function, file: String = #file) {
        dispatch(level: .debug, message: message, meta: meta, line: line, function: function, file: file)
    }

    public static func info(_ message: String, meta: [String: Any]? = nil, line: Int = #line, function: String = #function, file: String = #file) {
        dispatch(level: .info, message: message, meta: meta, line: line, function: function, file: file)
    }

    public static func warning(_ message: String, meta: [String: Any]? = nil, line: Int = #line, function: String = #function, file: String = #file) {
        dispatch(level: .warning, message: message, meta: meta, line: line, function: function, file: file)
    }

    public static func error(_ message: String, error: Error? = nil, meta: [String: Any]? = nil, line: Int = #line, function: String = #function, file: String = #file) {
        var combined: [String: Any] = meta ?? [:]
        combined["error"] = String(describing: error)
        dispatch(level: .error, message: message, meta: combined, line: line, function: function, file: file)
    }

    public static func getLogFiles() -> [URL] {
        defaultFileDestination.allFileURLs()
    }

    @discardableResult
    public static func clearLogFiles() -> Bool {
        defaultFileDestination.deleteAllFiles()
    }

    private static func dispatch(level: LogLevel, message: String, meta: [String: Any]?, line: Int, function: String, file: String) {
        guard shouldEmit(level: level) else { return }

        let event = LogEvent(
            level: level,
            message: message,
            timestamp: Date(),
            thread: currentThreadName(),
            file: (file as NSString).lastPathComponent,
            function: function,
            line: line,
            context: flatten(meta)
        )

        for destination in destinationsSnapshot() {
            destination.send(event)
        }
    }

    private static func shouldEmit(level: LogLevel) -> Bool {
        if enableLogging { return true }
        #if DEBUG
        return level == .debug
        #else
        return false
        #endif
    }

    private static func currentThreadName() -> String {
        if Thread.isMainThread { return "main" }
        let name = Thread.current.name
        if let name = name, !name.isEmpty { return name }
        return "background"
    }

    private static func flatten(_ meta: [String: Any]?) -> [String: String]? {
        guard let meta = meta, !meta.isEmpty else { return nil }
        var out: [String: String] = [:]
        for (key, value) in meta {
            out[key] = String(describing: value)
        }
        return out
    }
}
