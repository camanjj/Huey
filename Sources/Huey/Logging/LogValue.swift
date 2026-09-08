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

    public init(stringInterpolation: StringInterpolation) {
        self = .string(stringInterpolation.text)
    }

    /// Interpolation that renders an optional as its unwrapped description, or `nil`, rather
    /// than `Optional(…)`. Non-optional values promote into the same overload.
    public struct StringInterpolation: StringInterpolationProtocol {
        var text: String

        public init(literalCapacity: Int, interpolationCount: Int) {
            text = ""
            text.reserveCapacity(literalCapacity + interpolationCount * 8)
        }

        public mutating func appendLiteral(_ literal: String) {
            text += literal
        }

        public mutating func appendInterpolation<T>(_ value: T?) {
            text += value.map { String(describing: $0) } ?? "nil"
        }
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

extension LogValue: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int64.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([LogValue].self) {
            self = .array(array)
        } else if let dictionary = try? container.decode([String: LogValue].self) {
            self = .dictionary(dictionary)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported log value"
            )
        }
    }
}

// MARK: - Presentation

extension LogValue {
    var isContainer: Bool {
        switch self {
        case .array, .dictionary: return true
        default: return false
        }
    }

    /// Child rows for a container, labelled by key or index. `nil` for scalars.
    var children: [(label: String, value: LogValue)]? {
        switch self {
        case .array(let values):
            return values.enumerated().map { (String($0.offset), $0.element) }
        case .dictionary(let dict):
            return dict.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
        default:
            return nil
        }
    }

    /// One-line stand-in shown when a node is collapsed.
    var summaryLabel: String {
        switch self {
        case .array(let values):
            return "[\(values.count) \(values.count == 1 ? "item" : "items")]"
        case .dictionary(let dict):
            return "{\(dict.count) \(dict.count == 1 ? "key" : "keys")}"
        default:
            return previewText
        }
    }

    /// Values this big start collapsed.
    var isLarge: Bool {
        let rendered = stringValue
        return rendered.count > 200 || rendered.contains("\n")
    }

    var previewText: String {
        let collapsed = stringValue.replacingOccurrences(of: "\n", with: " ")
        if collapsed.count <= 80 { return collapsed }
        return String(collapsed.prefix(80)) + "…"
    }

    /// What "Copy Value" puts on the pasteboard: pretty JSON for containers, raw text otherwise.
    var copyText: String {
        guard isContainer,
              JSONSerialization.isValidJSONObject(jsonObject),
              let data = try? JSONSerialization.data(
                withJSONObject: jsonObject,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let string = String(data: data, encoding: .utf8) else {
            return stringValue
        }
        return string
    }
}
