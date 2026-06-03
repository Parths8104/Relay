import Foundation

/// The boundary between the app and whatever model powers it. The whole app is
/// written against this protocol, so the on-device Apple model and a cloud model
/// are interchangeable. This is the single most important architectural seam in
/// the codebase: it keeps vendor specifics out of the UI and the agent loop.
protocol AgentProvider: Sendable {
    /// Run exactly ONE model turn (one request). Streams text as it arrives and
    /// reports any tool calls the model wants to make. The higher-level
    /// `AgentEngine` decides whether to loop again after tools run.
    func streamTurn(
        history: [ProviderMessage],
        tools: [AgentTool]
    ) -> AsyncThrowingStream<TurnEvent, Error>
}

/// Provider-neutral conversation entry passed across the seam.
struct ProviderMessage {
    enum Role: String { case user, assistant }
    enum Block: Equatable {
        case text(String)
        case toolUse(id: String, name: String, inputJSON: String)
        case toolResult(toolUseID: String, content: String)
    }
    let role: Role
    let blocks: [Block]
}

/// Events emitted while a single turn streams.
enum TurnEvent {
    /// A chunk of assistant text.
    case textDelta(String)
    /// The model finished requesting a tool (arguments fully accumulated).
    case toolUse(id: String, name: String, inputJSON: String)
    /// The turn ended. `needsToolResults` is true when the model paused to wait
    /// for tool output and the engine must run the tools and start a new turn.
    case turnEnded(needsToolResults: Bool, assistantBlocks: [ProviderMessage.Block])
}

enum AgentError: LocalizedError {
    case missingAPIKey
    case http(status: Int, body: String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key set. Add one in Settings to start chatting."
        case let .http(status, body):
            return "Request failed (\(status)). \(body)"
        case let .decoding(detail):
            return "Couldn't read the model response: \(detail)"
        }
    }
}
