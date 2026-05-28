import Foundation

public struct LogEvent: Sendable {
    public let level: LogLevel
    public let message: String
    public let timestamp: Date
    public let thread: String
    public let file: String
    public let function: String
    public let line: Int
    public let context: [String: String]?

    public init(
        level: LogLevel,
        message: String,
        timestamp: Date,
        thread: String,
        file: String,
        function: String,
        line: Int,
        context: [String: String]?
    ) {
        self.level = level
        self.message = message
        self.timestamp = timestamp
        self.thread = thread
        self.file = file
        self.function = function
        self.line = line
        self.context = context
    }
}
