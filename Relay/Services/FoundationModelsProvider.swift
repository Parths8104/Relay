import Foundation

// MARK: - On-device provider (Apple Intelligence / Foundation Models)
//
// Apple's FoundationModels framework exposes the on-device LLM that powers
// Apple Intelligence. For an "AI Experiences" team this is the more interesting
// path: it runs locally, needs no API key, and keeps data on the device.
//
// It's gated behind `#if canImport(FoundationModels)` so the project still
// builds and runs (via AnthropicProvider) on machines or SDKs where the
// framework isn't present. To use it: build with the iOS SDK that ships
// FoundationModels, run on an Apple Intelligence-capable device, and swap the
// provider line in RelayApp.swift to `FoundationModelsProvider()`.
//
// NOTE: The framework's API surface is evolving — verify the exact session and
// streaming signatures against the SDK installed on your machine before relying
// on this in an interview demo. The structure below reflects the documented
// `LanguageModelSession` shape (session → respond/streamResponse).

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
struct FoundationModelsProvider: AgentProvider {
    func streamTurn(
        history: [ProviderMessage],
        tools: [AgentTool]
    ) -> AsyncThrowingStream<TurnEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // Flatten provider history into a single prompt. (Tool use
                    // here would be wired through FoundationModels' own Tool
                    // protocol; kept text-only for a clear, compiling baseline.)
                    let prompt = history
                        .flatMap { msg in
                            msg.blocks.compactMap { block -> String? in
                                if case let .text(t) = block { return t }
                                return nil
                            }
                        }
                        .joined(separator: "\n")

                    let session = LanguageModelSession()
                    let response = session.streamResponse(to: prompt)
                    for try await partial in response {
                        continuation.yield(.textDelta(partial))
                    }
                    continuation.yield(.turnEnded(
                        needsToolResults: false,
                        assistantBlocks: []
                    ))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
#endif
