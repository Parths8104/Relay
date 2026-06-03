import Foundation
import Observation

/// Drives the conversation. `@MainActor` guarantees every UI mutation happens on
/// the main thread; `@Observable` (iOS 17+) gives SwiftUI fine-grained updates
/// without `@Published` boilerplate. The view model owns the transcript and
/// translates low-level `AgentEngine.Event`s into UI state.
@MainActor
@Observable
final class ChatViewModel {
    private(set) var messages: [ChatMessage] = []
    private(set) var isResponding = false
    var errorMessage: String?

    private let engine: AgentEngine
    private var streamTask: Task<Void, Never>?

    init(engine: AgentEngine) {
        self.engine = engine
    }

    /// Send a user message and stream the agent's response.
    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isResponding else { return }

        messages.append(ChatMessage(role: .user, text: trimmed))

        // Create the assistant placeholder we'll stream into.
        let assistantID = UUID()
        messages.append(ChatMessage(id: assistantID, role: .assistant, isStreaming: true))

        isResponding = true
        errorMessage = nil

        let history = buildProviderHistory()
        streamTask = Task {
            await consume(engine.run(history: history), into: assistantID)
        }
    }

    /// Stop an in-flight response.
    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        finishStreaming()
    }

    // MARK: - Streaming

    private func consume(
        _ stream: AsyncThrowingStream<AgentEngine.Event, Error>,
        into assistantID: UUID
    ) async {
        do {
            for try await event in stream {
                guard let idx = messages.firstIndex(where: { $0.id == assistantID })
                else { continue }
                switch event {
                case let .textDelta(chunk):
                    messages[idx].text += chunk
                case let .toolStarted(id, name, arguments):
                    messages[idx].toolCalls.append(
                        ToolCallRecord(id: UUID(uuidString: id) ?? UUID(),
                                       name: name, arguments: arguments)
                    )
                    // Map by name+args since tool-use IDs aren't always UUIDs.
                    if let tIdx = messages[idx].toolCalls.firstIndex(
                        where: { $0.name == name && $0.result == nil }) {
                        messages[idx].toolCalls[tIdx] = ToolCallRecord(
                            id: messages[idx].toolCalls[tIdx].id,
                            name: name, arguments: arguments, result: nil)
                    }
                    _ = id
                case let .toolFinished(_, result):
                    if let tIdx = messages[idx].toolCalls.lastIndex(
                        where: { $0.result == nil }) {
                        messages[idx].toolCalls[tIdx].result = result
                    }
                case .completed:
                    break
                }
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
        finishStreaming()
    }

    private func finishStreaming() {
        for i in messages.indices where messages[i].isStreaming {
            messages[i].isStreaming = false
        }
        // Drop an empty assistant bubble if the request failed before any text.
        if let last = messages.last, last.role == .assistant,
           last.text.isEmpty, last.toolCalls.isEmpty {
            messages.removeLast()
        }
        isResponding = false
    }

    /// Translate the UI transcript into provider-neutral history.
    private func buildProviderHistory() -> [ProviderMessage] {
        messages.compactMap { msg in
            guard !(msg.role == .assistant && msg.text.isEmpty && msg.toolCalls.isEmpty)
            else { return nil }
            return ProviderMessage(
                role: msg.role == .user ? .user : .assistant,
                blocks: [.text(msg.text)]
            )
        }
    }
}
