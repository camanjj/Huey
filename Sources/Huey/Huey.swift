//  Created by Cameron Jackson on 4/13/19.
//  Copyright © 2021 Cameron Jackson. All rights reserved.
//

import Foundation
import SwiftyBeaver

public enum Log {
    
    public static var enableLogging = true
    
    private static var BeaverLog: SwiftyBeaver.Type  = {
        let log = SwiftyBeaver.self
        
        let fileLogProperties = { (destination: BaseDestination) in
            destination.format = "$J"
        }
        
        let file = FileDestination()
        fileLogProperties(file)
        log.addDestination(file)
        
#if DEBUG
        let console = ConsoleDestination()  // log to Xcode Console
        let consoleLogProperties = { (destination: BaseDestination) in
            destination.format = "$L: $Dyyyy-MM-dd HH:mm:ss.SSS$d [$N.$F:$l] $M $X"
            destination.levelString.verbose = "💜 VERBOSE"
            destination.levelString.debug = "💚 DEBUG"
            destination.levelString.info = "ℹ️ INFO"
            destination.levelString.warning = "⚠️ WARNING"
            destination.levelString.error = "🛑 ERROR"
        }
        consoleLogProperties(console)
        log.addDestination(console)
#endif
        
        return log
    }()
    
    private enum LogLevel {
        case debug
        case info
        case warning
        case error
    }
    
    private struct Context {
        let line: Int
        let function: String
        let file: String
        
        var filename: String {
            return (file as NSString).lastPathComponent
        }
        
        func toDictionary() -> [String: Any] {
            return ["line": line, "function": function, "filename": filename]
        }
    }
    
    private struct Info {
        let level: LogLevel
        let message: String
        let error: Error?
        let meta: [String: Any]?
    }
    
    static func debug(_ message: String, meta: [String: Any]? = nil, line: Int = #line, function: String = #function, file: String = #file) {
        let context = Context(line: line, function: function, file: file)
        let info = Info(level: .debug, message: message, error: nil, meta: meta)
        handleLog(info: info, context: context)
    }
    
    static func info(_ message: String, meta: [String: Any]? = nil, line: Int = #line, function: String = #function, file: String = #file) {
        let context = Context(line: line, function: function, file: file)
        let info = Info(level: .info, message: message, error: nil, meta: meta)
        handleLog(info: info, context: context)
    }
    
    static func warning(_ message: String, meta: [String: Any]? = nil, line: Int = #line, function: String = #function, file: String = #file) {
        let context = Context(line: line, function: function, file: file)
        let info = Info(level: .warning, message: message, error: nil, meta: meta)
        handleLog(info: info, context: context)
    }
    
    static func error(_ message: String, error: Error? = nil, meta: [String: Any]? = nil, line: Int = #line, function: String = #function, file: String = #file) {
        let context = Context(line: line, function: function, file: file)
        var metaWithError: [String: Any] = meta ?? [String: Any]()
        metaWithError["error"] = error
        let info = Info(level: .error, message: message, error: error, meta: metaWithError)
        handleLog(info: info, context: context)
    }
    
    static func getLogFile() throws -> Data {
        guard let fileDestination = BeaverLog.destinations.first(where: { $0 is FileDestination }) as? FileDestination else {
            throw HueyError.noFileDestination
        }
        
        guard let fileURL = fileDestination.logFileURL, let fileData = try? Data(contentsOf: fileURL) else {
            throw HueyError.noLogFile
        }
        
        return fileData
    }
    
    @discardableResult
    public static func clearLogFile() -> Bool {
        guard let fileDestination = BeaverLog.destinations.first(where: { $0 is FileDestination }) as? FileDestination else {
            return false
        }
        
        return fileDestination.deleteLogFile()
    }
    
    private static func handleLog(info: Info, context: Context) {
        
        if enableLogging || Build.currentBuild == .debug {
            // Local logging
            switch info.level {
            case .debug where Build.currentBuild == .debug:
                BeaverLog.debug(info.message, context.filename, context.function, line: context.line, context: info.meta)
            case .debug:
                break
            case .info:
                BeaverLog.info(info.message, context.filename, context.function, line: context.line, context: info.meta)
            case .warning:
                BeaverLog.warning(info.message, context.filename, context.function, line: context.line, context: info.meta)
            case .error:
                BeaverLog.error(info.message, context.filename, context.function, line: context.line, context: info.meta)
            }
        }
    }
    
    private static func generateException(info: Info, context: Context) -> NSException {
        return NSException(name: NSExceptionName(info.message), reason: nil, userInfo: nil)
    }
}
