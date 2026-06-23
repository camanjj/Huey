import Foundation

public protocol LogDestination: AnyObject {
    var minLevel: LogLevel { get set }
    func send(_ event: LogEvent)
}

public extension LogDestination {
    func shouldSend(_ event: LogEvent) -> Bool {
        event.level.rawValue >= minLevel.rawValue
    }
}

public protocol JSONFormattedLogDestination: LogDestination {
    var prettyPrint: Bool { get set }
    var escapeStrings: Bool { get set }
}

public enum DestinationPreferences {
    public static func identifier(for type: Any.Type) -> String {
        String(describing: type)
    }

    public static func identifier(for destination: LogDestination) -> String {
        identifier(for: Swift.type(of: destination))
    }

    private static func prettyPrintKey(_ id: String) -> String { "huey.dest.\(id).prettyPrint" }
    private static func escapeStringsKey(_ id: String) -> String { "huey.dest.\(id).escapeStrings" }

    public static func prettyPrint(for id: String) -> Bool {
        UserDefaults.standard.bool(forKey: prettyPrintKey(id))
    }

    public static func escapeStrings(for id: String) -> Bool {
        if UserDefaults.standard.object(forKey: escapeStringsKey(id)) == nil { return true }
        return UserDefaults.standard.bool(forKey: escapeStringsKey(id))
    }

    public static func setPrettyPrint(_ value: Bool, for id: String) {
        UserDefaults.standard.set(value, forKey: prettyPrintKey(id))
    }

    public static func setEscapeStrings(_ value: Bool, for id: String) {
        UserDefaults.standard.set(value, forKey: escapeStringsKey(id))
    }
}

enum JSONFormatting {
    static func writingOptions(prettyPrint: Bool) -> JSONSerialization.WritingOptions {
        var opts: JSONSerialization.WritingOptions = [.sortedKeys]
        if prettyPrint { opts.insert(.prettyPrinted) }
        return opts
    }

    // JSONSerialization escapes `/` as `\/` and emits non-ASCII as UTF-8 bytes.
    // Slash unescaping is the only meaningful knob; flip it when escapeStrings == false.
    static func postProcess(_ data: Data, escapeStrings: Bool) -> Data {
        guard !escapeStrings,
              let s = String(data: data, encoding: .utf8) else { return data }
        return Data(s.replacingOccurrences(of: "\\/", with: "/").utf8)
    }
}
