//  Created by Cameron Jackson on 4/13/19.
//  Copyright © 2021 Cameron Jackson. All rights reserved.
//

import Foundation

public enum Log {

    public static var enableLogging = true

    // Guarded by `destinationsLock`; replaced by `configureFile(directory:)`.
    private static var _defaultFileDestination: FileDestination = {
        let id = DestinationPreferences.identifier(for: FileDestination.self)
        return FileDestination(
            prettyPrint: DestinationPreferences.prettyPrint(for: id),
            escapeStrings: DestinationPreferences.escapeStrings(for: id)
        )
    }()

    static var defaultFileDestination: FileDestination {
        destinationsLock.lock()
        defer { destinationsLock.unlock() }
        return _defaultFileDestination
    }

    private static let destinationsLock = NSLock()
    private static var _destinations: [LogDestination] = {
        var list: [LogDestination] = [_defaultFileDestination]
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

    public static func verbose(_ message: String, meta: [String: LogValue]? = nil, line: Int = #line, function: String = #function, file: String = #file) {
        dispatch(level: .verbose, message: message, meta: meta, line: line, function: function, file: file)
    }

    public static func debug(_ message: String, meta: [String: LogValue]? = nil, line: Int = #line, function: String = #function, file: String = #file) {
        dispatch(level: .debug, message: message, meta: meta, line: line, function: function, file: file)
    }

    public static func info(_ message: String, meta: [String: LogValue]? = nil, line: Int = #line, function: String = #function, file: String = #file) {
        dispatch(level: .info, message: message, meta: meta, line: line, function: function, file: file)
    }

    public static func warning(_ message: String, meta: [String: LogValue]? = nil, line: Int = #line, function: String = #function, file: String = #file) {
        dispatch(level: .warning, message: message, meta: meta, line: line, function: function, file: file)
    }

    public static func error(_ message: String, error: Error? = nil, meta: [String: LogValue]? = nil, line: Int = #line, function: String = #function, file: String = #file) {
        var combined: [String: LogValue] = meta ?? [:]
        combined["error"] = error.map { .string("\($0)") } ?? .null
        dispatch(level: .error, message: message, meta: combined, line: line, function: function, file: file)
    }

    /// The directory the default log file is written to. Defaults to
    /// `FileDestination.defaultDirectory` (`Library/Caches/Huey`).
    public static var fileDirectory: URL {
        defaultFileDestination.directory
    }

    /// Moves the default log file to `directory`, for example Application Support,
    /// where iOS won't purge it. Can be called at any time: later events, `getLogFiles()`,
    /// `clearLogFiles()` and `LogsView` all use the new directory. Files already written
    /// to the previous directory are left in place.
    public static func configureFile(directory: URL) {
        destinationsLock.lock()
        defer { destinationsLock.unlock() }
        let old = _defaultFileDestination
        let new = FileDestination(
            directory: directory,
            fileName: old.fileName,
            maxFileSize: old.maxFileSize,
            maxFileCount: old.maxFileCount,
            minLevel: old.minLevel,
            prettyPrint: old.prettyPrint,
            escapeStrings: old.escapeStrings
        )
        // Swap in place, so the order is kept and a removed default stays removed.
        if let index = _destinations.firstIndex(where: { $0 === old }) {
            _destinations[index] = new
        }
        _defaultFileDestination = new
    }

    public static func getLogFiles() -> [URL] {
        defaultFileDestination.allFileURLs()
    }

    @discardableResult
    public static func clearLogFiles() -> Bool {
        defaultFileDestination.deleteAllFiles()
    }

    private static func dispatch(level: LogLevel, message: String, meta: [String: LogValue]?, line: Int, function: String, file: String) {
        guard shouldEmit(level: level) else { return }

        let event = LogEvent(
            level: level,
            message: message,
            timestamp: Date(),
            thread: currentThreadName(),
            file: (file as NSString).lastPathComponent,
            function: function,
            line: line,
            context: (meta?.isEmpty ?? true) ? nil : meta
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

}
