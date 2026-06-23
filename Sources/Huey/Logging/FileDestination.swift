import Foundation

public final class FileDestination: JSONFormattedLogDestination {

    public var minLevel: LogLevel
    public let directory: URL
    public let fileName: String
    public let maxFileSize: Int
    public let maxFileCount: Int
    public var prettyPrint: Bool
    public var escapeStrings: Bool

    private let queue = DispatchQueue(label: "com.huey.file-destination")
    private let fileManager = FileManager.default

    public static var defaultDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("Huey", isDirectory: true)
    }

    public init(
        directory: URL = FileDestination.defaultDirectory,
        fileName: String = "huey.log",
        maxFileSize: Int = 5 * 1024 * 1024,
        maxFileCount: Int = 5,
        minLevel: LogLevel = .verbose,
        prettyPrint: Bool = false,
        escapeStrings: Bool = true
    ) {
        self.directory = directory
        self.fileName = fileName
        self.maxFileSize = max(1, maxFileSize)
        self.maxFileCount = max(1, maxFileCount)
        self.minLevel = minLevel
        self.prettyPrint = prettyPrint
        self.escapeStrings = escapeStrings
    }

    public var activeFileURL: URL {
        directory.appendingPathComponent(fileName)
    }

    public func rolledFileURLs() -> [URL] {
        (1..<maxFileCount)
            .map { rolledURL(index: $0) }
            .filter { fileManager.fileExists(atPath: $0.path) }
    }

    public func allFileURLs() -> [URL] {
        var urls: [URL] = []
        if fileManager.fileExists(atPath: activeFileURL.path) {
            urls.append(activeFileURL)
        }
        urls.append(contentsOf: rolledFileURLs())
        return urls
    }

    @discardableResult
    public func deleteAllFiles() -> Bool {
        queue.sync {
            var success = true
            let candidates = [activeFileURL] + (1..<maxFileCount).map { rolledURL(index: $0) }
            for url in candidates where fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                } catch {
                    success = false
                }
            }
            return success
        }
    }

    public func send(_ event: LogEvent) {
        guard shouldSend(event) else { return }
        guard let line = encode(event) else { return }
        queue.async { [weak self] in
            self?.write(line)
        }
    }

    private func write(_ data: Data) {
        do {
            try ensureDirectoryExists()
            if currentFileSize() + data.count > maxFileSize, currentFileSize() > 0 {
                try rotate()
            }
            try append(data, to: activeFileURL)
        } catch {
            // Logging must never crash the host; swallow IO failures.
        }
    }

    private func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func currentFileSize() -> Int {
        let attrs = try? fileManager.attributesOfItem(atPath: activeFileURL.path)
        return (attrs?[.size] as? Int) ?? 0
    }

    private func rotate() throws {
        let oldest = rolledURL(index: maxFileCount - 1)
        if fileManager.fileExists(atPath: oldest.path) {
            try fileManager.removeItem(at: oldest)
        }
        if maxFileCount >= 3 {
            for i in stride(from: maxFileCount - 2, through: 1, by: -1) {
                let src = rolledURL(index: i)
                let dst = rolledURL(index: i + 1)
                if fileManager.fileExists(atPath: src.path) {
                    try fileManager.moveItem(at: src, to: dst)
                }
            }
        }
        if fileManager.fileExists(atPath: activeFileURL.path) {
            try fileManager.moveItem(at: activeFileURL, to: rolledURL(index: 1))
        }
    }

    private func append(_ data: Data, to url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: url)
        }
    }

    private func rolledURL(index: Int) -> URL {
        let (base, ext) = splitFileName()
        let rolled = ext.isEmpty ? "\(base).\(index)" : "\(base).\(index).\(ext)"
        return directory.appendingPathComponent(rolled)
    }

    private func splitFileName() -> (base: String, ext: String) {
        let ns = fileName as NSString
        let ext = ns.pathExtension
        let base = ns.deletingPathExtension
        return (base, ext)
    }

    func encode(_ event: LogEvent) -> Data? {
        var payload: [String: Any] = [
            "timestamp": event.timestamp.timeIntervalSince1970,
            "level": event.level.rawValue,
            "file": event.file,
            "line": event.line,
            "function": event.function,
            "thread": event.thread,
            "message": event.message
        ]
        if let context = event.context, !context.isEmpty {
            payload["context"] = context
        }
        guard JSONSerialization.isValidJSONObject(payload),
              let raw = try? JSONSerialization.data(
                withJSONObject: payload,
                options: JSONFormatting.writingOptions(prettyPrint: prettyPrint)
              ) else {
            return nil
        }
        var data = JSONFormatting.postProcess(raw, escapeStrings: escapeStrings)
        data.append(0x0A) // newline
        return data
    }
}
