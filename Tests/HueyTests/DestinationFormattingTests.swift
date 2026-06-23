import XCTest
@testable import Huey

final class DestinationFormattingTests: XCTestCase {

    private func makeEvent(context: [String: String]? = nil) -> LogEvent {
        LogEvent(
            level: .info,
            message: "hello",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            thread: "main",
            file: "Source.swift",
            function: "f()",
            line: 1,
            context: context
        )
    }

    // MARK: FileDestination

    func testFileDestinationDefaultsToCompactEscapedJSON() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let destination = FileDestination(directory: dir)
        let data = try XCTUnwrap(destination.encode(makeEvent(context: ["path": "/Users/x"])))
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(text.contains("\n  "), "Compact JSON should not be indented")
        XCTAssertTrue(text.contains("\\/Users\\/x"), "Default should escape forward slashes")
    }

    func testFileDestinationPrettyPrintsWhenEnabled() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let destination = FileDestination(directory: dir, prettyPrint: true)
        let data = try XCTUnwrap(destination.encode(makeEvent()))
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("\n  "), "Pretty-printed JSON should contain indented lines")
        XCTAssertTrue(text.hasSuffix("\n"), "JSON line must still terminate with a trailing newline")
    }

    func testFileDestinationUnescapesSlashesWhenEscapeStringsDisabled() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let destination = FileDestination(directory: dir, escapeStrings: false)
        let data = try XCTUnwrap(destination.encode(makeEvent(context: ["path": "/Users/x/log.txt"])))
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("/Users/x/log.txt"))
        XCTAssertFalse(text.contains("\\/"))
    }

    // MARK: SystemLogDestination

    func testSystemLogDestinationDefaultsToCompactEscapedContext() {
        let destination = SystemLogDestination()
        let line = destination.format(makeEvent(context: ["path": "/var/log"]))
        XCTAssertTrue(line.contains("\\/var\\/log"))
        XCTAssertFalse(line.contains("\n"))
    }

    func testSystemLogDestinationPrettyPrintsContextWhenEnabled() {
        let destination = SystemLogDestination(prettyPrint: true)
        let line = destination.format(makeEvent(context: ["a": "1", "b": "2"]))
        XCTAssertTrue(line.contains("\n"), "Pretty-printed context should introduce newlines")
    }

    func testSystemLogDestinationUnescapesSlashesWhenEscapeStringsDisabled() {
        let destination = SystemLogDestination(escapeStrings: false)
        let line = destination.format(makeEvent(context: ["path": "/var/log"]))
        XCTAssertTrue(line.contains("/var/log"))
        XCTAssertFalse(line.contains("\\/"))
    }

    // MARK: DestinationPreferences

    func testDestinationPreferencesEscapeStringsDefaultsTrueWhenUnset() {
        let id = "huey.test.unset-\(UUID().uuidString)"
        XCTAssertTrue(DestinationPreferences.escapeStrings(for: id))
        XCTAssertFalse(DestinationPreferences.prettyPrint(for: id))
    }

    func testDestinationPreferencesRoundTrip() {
        let id = "huey.test.roundtrip-\(UUID().uuidString)"
        defer {
            UserDefaults.standard.removeObject(forKey: "huey.dest.\(id).prettyPrint")
            UserDefaults.standard.removeObject(forKey: "huey.dest.\(id).escapeStrings")
        }
        DestinationPreferences.setPrettyPrint(true, for: id)
        DestinationPreferences.setEscapeStrings(false, for: id)
        XCTAssertTrue(DestinationPreferences.prettyPrint(for: id))
        XCTAssertFalse(DestinationPreferences.escapeStrings(for: id))
    }
}
