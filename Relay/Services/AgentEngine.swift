import Foundation

/// The agentic core. Given a user message, it drives the model in a loop:
///
///   1. Stream a model turn.
///   2. If the model asked for tools, run them, append the results, and loop.
///   3. Otherwise the turn is final — stop.
///
/// This is the "multi-step reasoning" pattern: the model plans, acts via tools,
/// observes results, and continues until it can answer. The engine is provider-
/// agnostic and tool-agnostic; it only speaks the `AgentProvider` protocol and
/// the `ToolRegistry`.
struct AgentEngine: Sendable {
    let provider: AgentProvider
    let registry: ToolRegistry
    /// Safety cap so a misbehaving model can't loop forever.
    let maxSteps: Int

    init(provider: AgentProvider, registry: ToolRegistry, maxSteps: Int = 6) {
        self.provider = provider
        self.registry = registry
        self.maxSteps = maxSteps
    }

    /// High-level events the view model renders.
    enum Event {
        case textDelta(String)
        case toolStarted(id: String, name: String, arguments: String)
        case toolFinished(id: String, result: String)
        case completed
        case stepLimitReached(maxSteps: Int)
    }

    /// Run a full agent interaction. `history` is the conversation so far
    /// (already including the new user message).
    func run(history initialHistory: [ProviderMessage]) -> AsyncThrowingStream<Event, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var history = initialHistory
                do {
                    for _ in 0..<maxSteps {
                        var assistantBlocks: [ProviderMessage.Block] = []
                        var pendingToolCalls: [(id: String, name: String, json: String)] = []
                        var needsTools = false

                        // ---- Stream one model turn ----
                        let stream = provider.streamTurn(
                            history: history,
                            tools: registry.tools
                        )
                        for try await event in stream {
                            switch event {
                            case let .textDelta(chunk):
                                continuation.yield(.textDelta(chunk))
                            case let .toolUse(id, name, json):
                                pendingToolCalls.append((id, name, json))
                                continuation.yield(
                                    .toolStarted(id: id, name: name, arguments: json)
                                )
                            case let .turnEnded(needsToolResults, blocks):
                                needsTools = needsToolResults
                                assistantBlocks = blocks
                            }
                        }

                        // Record the assistant turn in history.
                        history.append(
                            ProviderMessage(role: .assistant, blocks: assistantBlocks)
                        )

                        // ---- If no tools were requested, we're done ----
                        guard needsTools, !pendingToolCalls.isEmpty else {
                            continuation.yield(.completed)
                            continuation.finish()
                            return
                        }

                        // ---- Run tools concurrently, then feed results back ----
                        var resultBlocks: [ProviderMessage.Block] = []
                        try await withThrowingTaskGroup(
                            of: (String, String).self
                        ) { group in
                            for call in pendingToolCalls {
                                group.addTask {
                                    let output = await registry.execute(
                                        name: call.name,
                                        inputJSON: call.json
                                    )
                                    return (call.id, output)
                                }
                            }
                            for try await (id, output) in group {
                                continuation.yield(.toolFinished(id: id, result: output))
                                resultBlocks.append(
                                    .toolResult(toolUseID: id, content: output)
                                )
                            }
                        }

                        history.append(
                            ProviderMessage(role: .user, blocks: resultBlocks)
                        )
                        // Loop: start a fresh turn with tool results in context.
                    }
                    // Hit the step cap.
                    // Hit the step cap without reaching a final answer.
                   // Hit the step cap without reaching a final answer.
                    continuation.yield(.stepLimitReached(maxSteps: maxSteps))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
