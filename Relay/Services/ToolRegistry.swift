import Foundation

/// Holds the available tools and dispatches calls to them by name. Decoding the
/// model's JSON arguments and turning thrown errors into readable strings (so
/// the model can recover on the next turn) both live here, in one place.
struct ToolRegistry: Sendable {
    let tools: [AgentTool]
    private let byName: [String: AgentTool]

    init(tools: [AgentTool]) {
        self.tools = tools
        self.byName = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
    }

    /// Execute a tool by name. Never throws: tool failures are returned as text
    /// so the agent can read the error and try a different approach — the same
    /// way a human engineer reads a stack trace and adjusts.
    func execute(name: String, inputJSON: String) async -> String {
        guard let tool = byName[name] else {
            return "Error: no tool named '\(name)'."
        }
        do {
            let args = try decodeArguments(inputJSON)
            return try await tool.run(arguments: args)
        } catch {
            return "Error running \(name): \(error.localizedDescription)"
        }
    }

    private func decodeArguments(_ json: String) throws -> [String: JSONValue] {
        guard let data = json.data(using: .utf8), !json.isEmpty else { return [:] }
        return try JSONDecoder().decode([String: JSONValue].self, from: data)
    }
}
