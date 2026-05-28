import XCTest
@testable import Huey

final class LogLevelTests: XCTestCase {

    private let suiteName = "com.huey.tests.LogLevelTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
        UserDefaults.standard.removeObject(forKey: "hueyLoglevel")
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        UserDefaults.standard.removeObject(forKey: "hueyLoglevel")
        super.tearDown()
    }

    func testRawValuesAreStable() {
        XCTAssertEqual(LogLevel.verbose.rawValue, 0)
        XCTAssertEqual(LogLevel.debug.rawValue, 1)
        XCTAssertEqual(LogLevel.info.rawValue, 2)
        XCTAssertEqual(LogLevel.warning.rawValue, 3)
        XCTAssertEqual(LogLevel.error.rawValue, 4)
    }

    func testEmojiAndString() {
        XCTAssertEqual(LogLevel.verbose.emoji, "💜")
        XCTAssertEqual(LogLevel.debug.emoji, "💚")
        XCTAssertEqual(LogLevel.info.emoji, "ℹ️")
        XCTAssertEqual(LogLevel.warning.emoji, "⚠️")
        XCTAssertEqual(LogLevel.error.emoji, "🛑")

        XCTAssertEqual(LogLevel.verbose.string, "verbose")
        XCTAssertEqual(LogLevel.debug.string, "debug")
        XCTAssertEqual(LogLevel.info.string, "info")
        XCTAssertEqual(LogLevel.warning.string, "warning")
        XCTAssertEqual(LogLevel.error.string, "error")
    }

    func testStoredLogLevelsDefaultsToAll() {
        XCTAssertEqual(LogLevel.storedLogLevels, Set(LogLevel.allCases))
    }

    func testStoreRoundTrip() {
        let chosen: Set<LogLevel> = [.warning, .error]
        LogLevel.store(chosen)
        XCTAssertEqual(LogLevel.storedLogLevels, chosen)
    }

    func testLogDataLevelTypealias() {
        XCTAssertTrue(LogData.Level.self == LogLevel.self)
    }
}
