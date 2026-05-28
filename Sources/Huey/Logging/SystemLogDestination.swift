import Foundation
import os

public final class SystemLogDestination: LogDestination {

    public var minLevel: LogLevel
    private let logger: Logger

    public init(
        subsystem: String = Bundle.main.bundleIdentifier ?? "Huey",
        category: String = "Huey",
        minLevel: LogLevel = .verbose
    ) {
        self.logger = Logger(subsystem: subsystem, category: category)
        self.minLevel = minLevel
    }

    public func send(_ event: LogEvent) {
        guard shouldSend(event) else { return }
        let formatted = SystemLogDestination.format(event)
        switch event.level {
        case .verbose, .debug:
            logger.debug("\(formatted, privacy: .public)")
        case .info:
            logger.info("\(formatted, privacy: .public)")
        case .warning:
            logger.warning("\(formatted, privacy: .public)")
        case .error:
            logger.error("\(formatted, privacy: .public)")
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func format(_ event: LogEvent) -> String {
        let label: String
        switch event.level {
        case .verbose: label = "💜 VERBOSE"
        case .debug:   label = "💚 DEBUG"
        case .info:    label = "ℹ️ INFO"
        case .warning: label = "⚠️ WARNING"
        case .error:   label = "🛑 ERROR"
        }

        let timestamp = dateFormatter.string(from: event.timestamp)
        var line = "\(label): \(timestamp) [\(event.file).\(event.function):\(event.line)] \(event.message)"
        if let context = event.context, !context.isEmpty,
           let data = try? JSONSerialization.data(withJSONObject: context, options: [.sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            line += " \(json)"
        }
        return line
    }
}
