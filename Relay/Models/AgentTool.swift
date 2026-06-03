import Foundation

/// A capability the agent can invoke. Each tool is a small, pure, independently
/// testable unit. Adding a new agent skill means conforming a new type to this
/// protocol and registering it — nothing else in the app changes.
protocol AgentTool: Sendable {
    /// Stable identifier the model uses to call the tool.
    var name: String { get }
    /// Natural-language description the model uses to decide *when* to call it.
    var description: String { get }
    /// JSON Schema describing the tool's arguments.
    var inputSchema: JSONSchema { get }
    /// Execute the tool. `arguments` is the model-supplied JSON, already decoded
    /// into a dictionary. Returns a string the model reads on the next turn.
    func run(arguments: [String: JSONValue]) async throws -> String
}

/// A minimal JSON Schema model — enough to describe tool arguments without
/// pulling in a dependency. Encodes directly to the shape providers expect.
struct JSONSchema: Encodable {
    var type: String = "object"
    var properties: [String: Property]
    var required: [String]

    struct Property: Encodable {
        var type: String
        var description: String
    }
}

/// A tiny JSON value type so tools can read heterogeneous arguments safely
/// without resorting to `Any`/force-casts.
enum JSONValue: Decodable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    var stringValue: String? {
        if case let .string(s) = self { return s }
        return nil
    }

    var doubleValue: Double? {
        switch self {
        case let .number(n): return n
        case let .string(s): return Double(s)
        default: return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { self = .string(s) }
        else if let b = try? container.decode(Bool.self) { self = .bool(b) }
        else if let n = try? container.decode(Double.self) { self = .number(n) }
        else { self = .null }
    }
}
