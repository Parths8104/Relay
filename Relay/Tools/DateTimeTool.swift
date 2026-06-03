import Foundation

/// Returns the current date and time. Models have no clock, so this is a classic
/// example of grounding the agent in real, current state.
struct DateTimeTool: AgentTool {
    let name = "current_datetime"
    let description = "Get the current local date and time. Use for 'today', 'now', etc."
    var inputSchema: JSONSchema {
        JSONSchema(properties: [:], required: [])
    }

    func run(arguments: [String: JSONValue]) async throws -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}
