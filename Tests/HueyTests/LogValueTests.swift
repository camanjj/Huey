import XCTest
@testable import Huey

final class LogValueTests: XCTestCase {

    func testStringLiteral() {
        let v: LogValue = "hello"
        XCTAssertEqual(v, .string("hello"))
    }

    func testIntegerLiteral() {
        let v: LogValue = 42
        XCTAssertEqual(v, .int(42))
    }

    func testFloatLiteral() {
        let v: LogValue = 3.14
        XCTAssertEqual(v, .double(3.14))
    }

    func testBooleanLiteral() {
        let v: LogValue = true
        XCTAssertEqual(v, .bool(true))
    }

    func testNilLiteral() {
        let v: LogValue = nil
        XCTAssertEqual(v, .null)
    }

    func testArrayLiteral() {
        let v: LogValue = [1, "two", true]
        XCTAssertEqual(v, .array([.int(1), .string("two"), .bool(true)]))
    }

    func testDictionaryLiteral() {
        let v: LogValue = ["a": 1, "b": "x"]
        XCTAssertEqual(v, .dictionary(["a": .int(1), "b": .string("x")]))
    }

    func testStringValueForPrimitives() {
        XCTAssertEqual(LogValue.string("abc").stringValue, "abc")
        XCTAssertEqual(LogValue.int(7).stringValue, "7")
        XCTAssertEqual(LogValue.double(1.5).stringValue, "1.5")
        XCTAssertEqual(LogValue.bool(true).stringValue, "true")
        XCTAssertEqual(LogValue.bool(false).stringValue, "false")
        XCTAssertEqual(LogValue.null.stringValue, "nil")
    }

    func testStringValueForArray() {
        let v: LogValue = [1, 2, "x"]
        XCTAssertEqual(v.stringValue, "[1, 2, x]")
    }

    func testStringValueForDictionary() {
        let v: LogValue = ["b": 2, "a": 1]
        XCTAssertEqual(v.stringValue, "[a: 1, b: 2]")
    }

    func testJsonObjectRoundTripsThroughJSONSerialization() throws {
        let v: LogValue = ["count": 7, "flag": true, "name": "abc", "nested": [1, 2]]
        let data = try JSONSerialization.data(withJSONObject: v.jsonObject, options: [.sortedKeys])
        let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(decoded["count"] as? Int, 7)
        XCTAssertEqual(decoded["flag"] as? Bool, true)
        XCTAssertEqual(decoded["name"] as? String, "abc")
        XCTAssertEqual(decoded["nested"] as? [Int], [1, 2])
    }
}
