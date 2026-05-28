import XCTest
@testable import Huey

final class FileDestinationTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HueyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    private func makeEvent(
        level: LogLevel = .info,
        message: String = "hello",
        line: Int = 42,
        context: [String: String]? = nil
    ) -> LogEvent {
        LogEvent(
            level: level,
            message: message,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            thread: "main",
            file: "Source.swift",
            function: "f()",
            line: line,
            context: context
        )
    }

    private func waitForWrites(_ destination: FileDestination) {
        // FileDestination dispatches writes onto its private serial queue; a sync barrier
        // on a public proxy is unavailable, so we drain via a separate sync send on a
        // helper queue using a known synchronous read.
        let expectation = XCTestExpectation(description: "drain")
        DispatchQueue.global().async {
            // The serial queue in FileDestination drains FIFO. We can't directly target it,
            // so sleep a small amount to let writes flush. Keep small to keep tests fast.
            Thread.sleep(forTimeInterval: 0.05)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testWritesJsonLinesThatRoundTripIntoLogData() throws {
        let destination = FileDestination(directory: tempDir)
        destination.send(makeEvent(level: .info, message: "one"))
        destination.send(makeEvent(level: .warning, message: "two"))
        destination.send(makeEvent(level: .error, message: "three"))
        waitForWrites(destination)

        let data = try Data(contentsOf: destination.activeFileURL)
        let lines = String(data: data, encoding: .utf8)!
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        XCTAssertEqual(lines.count, 3)

        let decoder = JSONDecoder()
        let decoded = try lines.map { line -> LogData in
            try decoder.decode(LogData.self, from: line.data(using: .utf8)!)
        }
        XCTAssertEqual(decoded.map(\.message), ["one", "two", "three"])
        XCTAssertEqual(decoded.map(\.level), [.info, .warning, .error])
        XCTAssertEqual(decoded.first?.file, "Source.swift")
        XCTAssertEqual(decoded.first?.line, 42)
        XCTAssertEqual(decoded.first?.function, "f()")
        XCTAssertEqual(decoded.first?.thread, "main")
    }

    func testContextSurvivesSerialization() throws {
        let destination = FileDestination(directory: tempDir)
        let context: [String: String] = ["userId": "abc", "request": "GET /foo"]
        destination.send(makeEvent(context: context))
        waitForWrites(destination)

        let data = try Data(contentsOf: destination.activeFileURL)
        let line = data.split(separator: 0x0A).first!
        let json = try JSONSerialization.jsonObject(with: line, options: []) as! [String: Any]
        XCTAssertEqual(json["context"] as? [String: String], context)
    }

    func testRotationTriggersAtMaxFileSize() throws {
        let destination = FileDestination(
            directory: tempDir,
            maxFileSize: 256,
            maxFileCount: 3
        )

        for i in 0..<20 {
            destination.send(makeEvent(message: "batch-\(i)-padding-padding-padding"))
        }
        waitForWrites(destination)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.activeFileURL.path))
        let rolled = destination.rolledFileURLs()
        XCTAssertFalse(rolled.isEmpty, "Expected at least one rolled file after rotation")
        XCTAssertLessThanOrEqual(destination.allFileURLs().count, 3)
    }

    func testOldestFileIsEvictedPastMaxFileCount() throws {
        let destination = FileDestination(
            directory: tempDir,
            maxFileSize: 200,
            maxFileCount: 3
        )

        // Each "batch" message is large enough to trigger rotation quickly.
        for batch in 0..<10 {
            for _ in 0..<5 {
                destination.send(makeEvent(message: "batch-\(batch)-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"))
            }
        }
        waitForWrites(destination)

        let beyondCap = tempDir.appendingPathComponent("huey.3.log")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: beyondCap.path),
            "huey.3.log must not exist when maxFileCount=3"
        )
        XCTAssertLessThanOrEqual(destination.allFileURLs().count, 3)
    }

    func testAllFileURLsOrdering() throws {
        let destination = FileDestination(
            directory: tempDir,
            maxFileSize: 150,
            maxFileCount: 4
        )

        for i in 0..<30 {
            destination.send(makeEvent(message: "ordering-\(i)-padding-padding"))
        }
        waitForWrites(destination)

        let urls = destination.allFileURLs()
        guard urls.count >= 2 else {
            return XCTFail("Expected rotation to produce at least one rolled file")
        }
        XCTAssertEqual(urls.first?.lastPathComponent, "huey.log")
        let rolledNames = urls.dropFirst().map(\.lastPathComponent)
        let expectedPrefixes = ["huey.1.log", "huey.2.log", "huey.3.log"]
        XCTAssertEqual(Array(rolledNames), Array(expectedPrefixes.prefix(rolledNames.count)))
    }

    func testDeleteAllFiles() throws {
        let destination = FileDestination(
            directory: tempDir,
            maxFileSize: 200,
            maxFileCount: 3
        )
        for i in 0..<30 {
            destination.send(makeEvent(message: "delete-\(i)-padding-padding-padding"))
        }
        waitForWrites(destination)
        XCTAssertFalse(destination.allFileURLs().isEmpty)

        XCTAssertTrue(destination.deleteAllFiles())
        XCTAssertTrue(destination.allFileURLs().isEmpty)
    }

    func testConcurrentWritesDoNotCorruptLines() throws {
        let destination = FileDestination(
            directory: tempDir,
            maxFileSize: 10 * 1024 * 1024, // avoid rotation for this test
            maxFileCount: 5
        )

        DispatchQueue.concurrentPerform(iterations: 500) { i in
            destination.send(makeEvent(message: "concurrent-\(i)"))
        }
        // Give the serial queue time to drain all 500 writes.
        Thread.sleep(forTimeInterval: 0.3)

        let data = try Data(contentsOf: destination.activeFileURL)
        let lines = data
            .split(separator: 0x0A)
            .map { Data($0) }
        XCTAssertEqual(lines.count, 500)

        let decoder = JSONDecoder()
        for line in lines {
            XCTAssertNoThrow(try decoder.decode(LogData.self, from: line))
        }
    }

    func testMinLevelFiltersBelowThreshold() throws {
        let destination = FileDestination(directory: tempDir)
        destination.minLevel = .warning
        destination.send(makeEvent(level: .debug, message: "filtered"))
        destination.send(makeEvent(level: .warning, message: "kept"))
        waitForWrites(destination)

        let data = try Data(contentsOf: destination.activeFileURL)
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(text.contains("filtered"))
        XCTAssertTrue(text.contains("kept"))
    }
}
