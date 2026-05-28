import Foundation

public enum LogLevel: Int, Codable, CaseIterable, Identifiable, RawRepresentable, Sendable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4

    public var id: Self { self }

    public var emoji: String {
        switch self {
        case .verbose: return "💜"
        case .debug:   return "💚"
        case .info:    return "ℹ️"
        case .warning: return "⚠️"
        case .error:   return "🛑"
        }
    }

    public var string: String {
        switch self {
        case .verbose: return "verbose"
        case .debug:   return "debug"
        case .info:    return "info"
        case .warning: return "warning"
        case .error:   return "error"
        }
    }

    public static var storedLogLevels: Set<LogLevel> {
        let array = UserDefaults.standard.array(forKey: "hueyLoglevel") as? [Int]
        return Set(array?.compactMap { LogLevel(rawValue: $0) } ?? LogLevel.allCases)
    }

    public static func store(_ levels: Set<LogLevel>) {
        UserDefaults.standard.set(levels.map { $0.rawValue }, forKey: "hueyLoglevel")
    }
}
