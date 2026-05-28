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
