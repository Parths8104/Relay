import Foundation

/// A single message as the UI understands it. Deliberately decoupled from any
/// provider's wire format — the agent layer translates between this and the
/// API DTOs so the UI never depends on a vendor schema.
struct ChatMessage: Identifiable, Equatable {
    enum Role: String {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    /// Streamed text. Mutated in place while tokens arrive.
    var text: String
    /// Tool invocations surfaced inline so the user can see the agent's work.
    var toolCalls: [ToolCallRecord]
    /// True while tokens are still streaming into this message.
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        role: Role,
        text: String = "",
        toolCalls: [ToolCallRecord] = [],
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.toolCalls = toolCalls
        self.isStreaming = isStreaming
    }
}

/// A record of one tool call, shown inline in the transcript. Lets the user
/// watch the agent reason in multiple steps rather than seeing a black box.
struct ToolCallRecord: Identifiable, Equatable {
    let id: UUID
    let name: String
    let arguments: String
    var result: String?

    init(id: UUID = UUID(), name: String, arguments: String, result: String? = nil) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.result = result
    }
}
