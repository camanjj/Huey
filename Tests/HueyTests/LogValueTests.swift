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

    // MARK: - String interpolation

    func testInterpolatingNilRendersNilNotOptional() {
        let missing: String? = nil
        let v: LogValue = "\(missing)"
        XCTAssertEqual(v, .string("nil"))
    }

    func testInterpolatingSomeRendersUnwrappedValue() {
        let name: String? = "Bob"
        let count: Int? = 7
        XCTAssertEqual(LogValue("user \(name)"), .string("user Bob"))
        XCTAssertEqual(LogValue("count \(count)"), .string("count 7"))
    }

    func testInterpolatingNonOptionalIsUnchanged() {
        let v: LogValue = "id \(42) ok \(true)"
        XCTAssertEqual(v, .string("id 42 ok true"))
    }

    // MARK: - Decoding

    func testDecodesNestedJSONIntoTypedValues() throws {
        let json = Data(#"""
        {"count":7,"ratio":2.5,"flag":true,"name":"abc","missing":null,
         "nested":{"list":[1,"x",false]}}
        """#.utf8)
        let decoded = try JSONDecoder().decode([String: LogValue].self, from: json)
        XCTAssertEqual(decoded["count"], .int(7))
        XCTAssertEqual(decoded["ratio"], .double(2.5))
        XCTAssertEqual(decoded["flag"], .bool(true))
        XCTAssertEqual(decoded["name"], .string("abc"))
        XCTAssertEqual(decoded["missing"], .null)
        XCTAssertEqual(decoded["nested"], .dictionary(["list": .array([.int(1), .string("x"), .bool(false)])]))
    }

    func testDecodingRoundTripsJsonObject() throws {
        let original: LogValue = ["count": 7, "ratio": 2.5, "flag": false, "nested": ["a", nil]]
        let data = try JSONSerialization.data(withJSONObject: original.jsonObject, options: [])
        XCTAssertEqual(try JSONDecoder().decode(LogValue.self, from: data), original)
    }

    // MARK: - Presentation helpers

    func testChildrenAreOrderedByKeyAndIndex() {
        let dict: LogValue = ["b": 2, "a": 1]
        XCTAssertEqual(dict.children?.map(\.label), ["a", "b"])
        let array: LogValue = ["x", "y"]
        XCTAssertEqual(array.children?.map(\.label), ["0", "1"])
        XCTAssertNil(LogValue.int(1).children)
    }

    func testSummaryLabel() {
        XCTAssertEqual(LogValue.dictionary(["a": 1]).summaryLabel, "{1 key}")
        XCTAssertEqual(LogValue.dictionary(["a": 1, "b": 2]).summaryLabel, "{2 keys}")
        XCTAssertEqual(LogValue.array([1]).summaryLabel, "[1 item]")
        XCTAssertEqual(LogValue.array([1, 2]).summaryLabel, "[2 items]")
        XCTAssertEqual(LogValue.null.summaryLabel, "nil")
        XCTAssertEqual(LogValue.string("abc").summaryLabel, "abc")
    }

    func testIsLargeAndPreviewText() {
        XCTAssertFalse(LogValue.string("short").isLarge)
        XCTAssertTrue(LogValue.string("two\nlines").isLarge)
        XCTAssertTrue(LogValue.string(String(repeating: "x", count: 201)).isLarge)

        XCTAssertEqual(LogValue.string("two\nlines").previewText, "two lines")
        let long = LogValue.string(String(repeating: "x", count: 100)).previewText
        XCTAssertEqual(long, String(repeating: "x", count: 80) + "…")
    }

    func testCopyTextIsPrettyJSONForContainersAndRawForScalars() throws {
        XCTAssertEqual(LogValue.string("plain").copyText, "plain")
        XCTAssertEqual(LogValue.null.copyText, "nil")

        let container: LogValue = ["b": 2, "a": 1]
        let copied = container.copyText
        XCTAssertTrue(copied.contains("\n"), "Containers should copy as pretty JSON")
        let reparsed = try JSONDecoder().decode(LogValue.self, from: Data(copied.utf8))
        XCTAssertEqual(reparsed, container)
    }
}
