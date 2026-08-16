import Foundation

/// A lossless, Codable representation of ANY JSON value.
///
/// This is the source of truth for the save file. By storing the entire
/// desktop save as a `JSONValue` tree, the phone never drops unknown fields it
/// doesn't understand — it round-trips them byte-faithfully on re-serialize,
/// so a save edited on the phone stays compatible with the desktop app.
///
/// Numbers are stored as `Double` but re-serialized as integers when they have
/// no fractional part, matching `JSON.stringify` behaviour on the desktop.
public indirect enum JSONValue: Codable, Equatable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    // MARK: - Decoding

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value")
        }
    }

    // MARK: - Encoding

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let b):
            try container.encode(b)
        case .number(let n):
            // Preserve integer-ness so output matches JSON.stringify.
            if n.rounded() == n && abs(n) < 9.007199254740992e15 {
                try container.encode(Int64(n))
            } else {
                try container.encode(n)
            }
        case .string(let s):
            try container.encode(s)
        case .array(let a):
            try container.encode(a)
        case .object(let o):
            try container.encode(o)
        }
    }

    // MARK: - Typed getters

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var doubleValue: Double? {
        switch self {
        case .number(let n): return n
        case .bool(let b): return b ? 1 : 0
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    public var intValue: Int? {
        if let d = doubleValue { return Int(d) }
        return nil
    }

    public var boolValue: Bool? {
        switch self {
        case .bool(let b): return b
        case .number(let n): return n != 0
        default: return nil
        }
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    // MARK: - Subscripting

    /// Read/write access by object key. Reading a non-object or missing key
    /// returns `nil`. Writing to a non-object promotes it to an object.
    public subscript(key: String) -> JSONValue? {
        get {
            if case .object(let o) = self { return o[key] }
            return nil
        }
        set {
            var o = objectValue ?? [:]
            o[key] = newValue
            self = .object(o)
        }
    }

    /// Read/write access by array index. Out-of-range reads return `nil`.
    public subscript(index: Int) -> JSONValue? {
        get {
            if case .array(let a) = self, a.indices.contains(index) { return a[index] }
            return nil
        }
        set {
            guard case .array(var a) = self, a.indices.contains(index) else { return }
            a[index] = newValue ?? .null
            self = .array(a)
        }
    }

    // MARK: - Convenience mutation

    /// Sets a value at a nested key path, creating intermediate objects.
    /// Example: `root.set(["player", "level"], to: .number(5))`.
    public mutating func set(_ path: [String], to value: JSONValue) {
        guard let first = path.first else {
            self = value
            return
        }
        if path.count == 1 {
            self[first] = value
            return
        }
        var child = self[first] ?? .object([:])
        child.set(Array(path.dropFirst()), to: value)
        self[first] = child
    }

    /// Reads a value at a nested key path, or `nil` if any segment is missing.
    public func value(at path: [String]) -> JSONValue? {
        var current: JSONValue? = self
        for key in path {
            current = current?[key]
            if current == nil { return nil }
        }
        return current
    }

    // MARK: - Literal-ish constructors

    public static func int(_ i: Int) -> JSONValue { .number(Double(i)) }
}

// MARK: - Serialization helpers

public extension JSONValue {
    /// Parses a JSON string into a `JSONValue`, or throws.
    static func parse(_ jsonString: String) throws -> JSONValue {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "JSONValue", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "String is not valid UTF-8"])
        }
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    /// Compact JSON string (matches `JSON.stringify(state)` on desktop).
    func compactString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
        // sortedKeys keeps output deterministic; desktop parses regardless of order.
        if let data = try? encoder.encode(self),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "{}"
    }

    /// Pretty-printed JSON string (matches `JSON.stringify(state, null, 2)`).
    func prettyString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        if let data = try? encoder.encode(self),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "{}"
    }
}
