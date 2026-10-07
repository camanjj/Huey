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
        XCTAssertNotNil(event?.context?["error"])
        XCTAssertTrue(event?.context?["error"]?.stringValue.contains("Boom") == true)
    }

    func testErrorWithNilRecordsNullValue() {
        Log.error("kaboom", error: nil)
        XCTAssertEqual(recorder.events.last?.context?["error"], .null)
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

    func testContextPreservesTypedMetaValues() {
        Log.info("hi", meta: ["count": 7, "name": "abc", "flag": true])
        let ctx = recorder.events.first?.context ?? [:]
        XCTAssertEqual(ctx["count"], .int(7))
        XCTAssertEqual(ctx["name"], .string("abc"))
        XCTAssertEqual(ctx["flag"], .bool(true))
    }

    func testThreadNameIsMain() {
        Log.info("hi")
        XCTAssertEqual(recorder.events.first?.thread, "main")
    }

    // MARK: - configureFile(directory:)

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HueyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    private func restoreFileDirectory() {
        let original = Log.fileDirectory
        addTeardownBlock { Log.configureFile(directory: original) }
    }

    private func waitForFile(_ url: URL) {
        let deadline = Date().addingTimeInterval(1.0)
        while !FileManager.default.fileExists(atPath: url.path), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
    }

    func testConfigureFileMovesWritesAndFileAccessors() throws {
        restoreFileDirectory()
        let first = try makeTempDir()
        let second = try makeTempDir()

        Log.configureFile(directory: first)
        Log.addDestination(Log.defaultFileDestination)
        Log.info("before")
        let firstFile = Log.defaultFileDestination.activeFileURL
        waitForFile(firstFile)

        Log.configureFile(directory: second)
        XCTAssertEqual(Log.fileDirectory, second)
        Log.info("after")
        let secondFile = Log.defaultFileDestination.activeFileURL
        waitForFile(secondFile)

        XCTAssertEqual(Log.getLogFiles(), [secondFile])
        XCTAssertTrue(Log.clearLogFiles())
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstFile.path), "Old files are left in place")
    }

    func testConfigureFileSwapsDefaultInPlace() throws {
        restoreFileDirectory()
        let dir = try makeTempDir()
        let trailing = RecordingDestination()
        let old = Log.defaultFileDestination
        Log.addDestination(old)
        Log.addDestination(trailing)

        Log.configureFile(directory: dir)

        let snapshot = Log.destinationsSnapshot()
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertTrue(snapshot[0] === recorder)
        XCTAssertTrue(snapshot[1] === Log.defaultFileDestination)
        XCTAssertFalse(snapshot[1] === old)
        XCTAssertTrue(snapshot[2] === trailing)
    }

    func testConfigureFileSwapsEveryCopyOfDefault() throws {
        restoreFileDirectory()
        let old = Log.defaultFileDestination
        Log.addDestination(old)
        Log.addDestination(old)

        Log.configureFile(directory: try makeTempDir())

        let snapshot = Log.destinationsSnapshot()
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertTrue(snapshot[0] === recorder)
        XCTAssertTrue(snapshot[1] === Log.defaultFileDestination)
        XCTAssertTrue(snapshot[2] === Log.defaultFileDestination)
    }

    func testConfigureFileDoesNotReAddRemovedDefault() throws {
        restoreFileDirectory()
        Log.configureFile(directory: try makeTempDir())
        XCTAssertEqual(Log.destinationsSnapshot().count, 1)
        XCTAssertTrue(Log.destinationsSnapshot()[0] === recorder)
    }

    func testConfigureFileKeepsSettings() throws {
        let old = Log.defaultFileDestination
        let original = (old.minLevel, old.prettyPrint, old.escapeStrings)
        // Teardown blocks run last-in first-out, so this runs after the directory
        // is restored and resets whichever default is current by then.
        addTeardownBlock {
            let current = Log.defaultFileDestination
            (current.minLevel, current.prettyPrint, current.escapeStrings) = original
        }
        restoreFileDirectory()
        old.minLevel = .warning
        old.prettyPrint = !original.1
        old.escapeStrings = !original.2

        Log.configureFile(directory: try makeTempDir())

        let new = Log.defaultFileDestination
        XCTAssertEqual(new.minLevel, .warning)
        XCTAssertEqual(new.prettyPrint, !original.1)
        XCTAssertEqual(new.escapeStrings, !original.2)
        XCTAssertEqual(new.fileName, old.fileName)
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
