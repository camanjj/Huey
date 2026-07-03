import Foundation

public enum LogValue: Sendable, Hashable {
    case string(String)
    case int(Int64)
    case double(Double)
    case bool(Bool)
    case null
    case array([LogValue])
    case dictionary([String: LogValue])
}

extension LogValue: ExpressibleByStringInterpolation {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension LogValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        self = .int(value)
    }
}

extension LogValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension LogValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension LogValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension LogValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: LogValue...) {
        self = .array(elements)
    }
}

extension LogValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, LogValue)...) {
        self = .dictionary(Dictionary(uniqueKeysWithValues: elements))
    }
}

public extension LogValue {
    var stringValue: String {
        switch self {
        case .string(let s): return s
        case .int(let n): return String(n)
        case .double(let d): return String(d)
        case .bool(let b): return b ? "true" : "false"
        case .null: return "nil"
        case .array(let values):
            return "[" + values.map(\.stringValue).joined(separator: ", ") + "]"
        case .dictionary(let dict):
            let body = dict
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value.stringValue)" }
                .joined(separator: ", ")
            return "[" + body + "]"
        }
    }

    var jsonObject: Any {
        switch self {
        case .string(let s): return s
        case .int(let n): return NSNumber(value: n)
        case .double(let d): return NSNumber(value: d)
        case .bool(let b): return NSNumber(value: b)
        case .null: return NSNull()
        case .array(let values): return values.map(\.jsonObject)
        case .dictionary(let dict): return dict.mapValues(\.jsonObject)
        }
    }
}
