import XCTest
@testable import Huey

// Tests in this file mutate the static state on `Log` (destinations, enableLogging).
// XCTest runs methods within a single class serially, which is required here.

final class LogDispatchTests: XCTestCase {

    private var recorder: RecordingDestination!
    private var originalEnableLogging = true

    override func setUp() {
        super.setUp()
        originalEnableLogging = Log.enableLogging
        Log.enableLogging = true
        Log.removeAllDestinations()
        recorder = RecordingDestination()
        Log.addDestination(recorder)
    }

    override func tearDown() {
        Log.removeAllDestinations()
        Log.enableLogging = originalEnableLogging
        recorder = nil
        super.tearDown()
    }

    func testMinLevelFiltersBelowThreshold() {
        recorder.minLevel = .warning
        Log.debug("d")
        Log.info("i")
        Log.warning("w")
        Log.error("e")
        XCTAssertEqual(recorder.events.map(\.level), [.warning, .error])
        XCTAssertEqual(recorder.events.map(\.message), ["w", "e"])
    }

    func testErrorFoldsErrorIntoContext() {
        struct Boom: Error {}
        let err: Error? = Boom()
        Log.error("kaboom", error: err)
        let event = recorder.events.last
        // Matches today's String(describing: Optional) behavior — preserved from the
        // SwiftyBeaver wrapper. Asserting on `contains` keeps the test stable across
        // Swift versions while still confirming the error description was captured.
        XCTAssertNotNil(event?.context?["error"])
        XCTAssertTrue(event?.context?["error"]?.contains("Boom") == true)
    }

    func testErrorWithNilStillRecordsKey() {
        Log.error("kaboom", error: nil)
        XCTAssertEqual(recorder.events.last?.context?["error"], "nil")
    }

    func testEnableLoggingFalseSuppressesNonDebug() {
        Log.enableLogging = false
        Log.info("i")
        Log.warning("w")
        Log.error("e")
        XCTAssertTrue(recorder.events.filter { $0.level != .debug }.isEmpty)

        Log.debug("d")
        #if DEBUG
        XCTAssertEqual(recorder.events.map(\.level), [.debug])
        #else
        XCTAssertTrue(recorder.events.isEmpty)
        #endif
    }

    func testAddAndRemoveDestinations() {
        Log.info("first")
        XCTAssertEqual(recorder.events.count, 1)

        Log.removeAllDestinations()
        Log.info("second")
        XCTAssertEqual(recorder.events.count, 1, "Removed destination should receive no further events")

        Log.addDestination(recorder)
        Log.info("third")
        XCTAssertEqual(recorder.events.count, 2)
    }

    func testFileFieldIsReducedToLastPathComponent() {
        Log.info("hi")
        XCTAssertEqual(recorder.events.first?.file, "LogDispatchTests.swift")
    }

    func testVerboseEmitsVerboseLevel() {
        Log.verbose("v")
        XCTAssertEqual(recorder.events.first?.level, .verbose)
        XCTAssertEqual(recorder.events.first?.level.rawValue, 0)
    }

    func testContextFlattensMetaToStrings() {
        Log.info("hi", meta: ["count": 7, "name": "abc"])
        let ctx = recorder.events.first?.context ?? [:]
        XCTAssertEqual(ctx["count"], "7")
        XCTAssertEqual(ctx["name"], "abc")
    }

    func testThreadNameIsMain() {
        Log.info("hi")
        XCTAssertEqual(recorder.events.first?.thread, "main")
    }
}

final class RecordingDestination: LogDestination {
    var minLevel: LogLevel = .verbose

    private let lock = NSLock()
    private var _events: [LogEvent] = []

    var events: [LogEvent] {
        lock.lock(); defer { lock.unlock() }
        return _events
    }

    func send(_ event: LogEvent) {
        guard shouldSend(event) else { return }
        lock.lock(); defer { lock.unlock() }
        _events.append(event)
    }
}
