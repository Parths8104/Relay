import Foundation

/// An `AgentProvider` backed by the Anthropic Messages API with streaming and
/// tool use. This is the cloud path — it runs on any device and any iOS version.
///
/// The interesting work here is parsing Server-Sent Events: text arrives token
/// by token, and tool-call arguments arrive as fragments of JSON spread across
/// many events that must be reassembled before the tool can run.
struct AnthropicProvider: AgentProvider {
    let keyStore: KeychainStore
    var model: String = "claude-sonnet-4-20250514"
    var maxTokens: Int = 1024
    var systemPrompt: String = """
        You are Relay, a concise on-device-style assistant. Prefer calling a tool \
        over guessing when a tool can give an exact answer. Keep replies short.
        """

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func streamTurn(
        history: [ProviderMessage],
        tools: [AgentTool]
    ) -> AsyncThrowingStream<TurnEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let apiKey = keyStore.read(), !apiKey.isEmpty else {
                        throw AgentError.missingAPIKey
                    }

                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.httpBody = try encodeBody(history: history, tools: tools)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    if let http = response as? HTTPURLResponse,
                       !(200...299).contains(http.statusCode) {
                        throw AgentError.http(status: http.statusCode, body: "")
                    }

                    // Accumulators for the streamed tool_use block(s).
                    var blockTypes: [Int: String] = [:]          // index -> "text"|"tool_use"
                    var toolIDs: [Int: String] = [:]
                    var toolNames: [Int: String] = [:]
                    var toolJSON: [Int: String] = [:]            // index -> partial JSON
                    var textBlocks: [Int: String] = [:]
                    var stopReason: String?

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        guard let data = payload.data(using: .utf8),
                              let event = try? JSONDecoder().decode(SSEEvent.self, from: data)
                        else { continue }

                        switch event.type {
                        case "content_block_start":
                            if let idx = event.index, let block = event.content_block {
                                blockTypes[idx] = block.type
                                if block.type == "tool_use" {
                                    toolIDs[idx] = block.id ?? ""
                                    toolNames[idx] = block.name ?? ""
                                    toolJSON[idx] = ""
                                } else if block.type == "text" {
                                    textBlocks[idx] = ""
                                }
                            }
                        case "content_block_delta":
                            if let idx = event.index, let delta = event.delta {
                                if let t = delta.text {
                                    textBlocks[idx, default: ""] += t
                                    continuation.yield(.textDelta(t))
                                }
                                if let pj = delta.partial_json {
                                    toolJSON[idx, default: ""] += pj
                                }
                            }
                        case "content_block_stop":
                            if let idx = event.index, blockTypes[idx] == "tool_use" {
                                continuation.yield(.toolUse(
                                    id: toolIDs[idx] ?? "",
                                    name: toolNames[idx] ?? "",
                                    inputJSON: toolJSON[idx] ?? "{}"
                                ))
                            }
                        case "message_delta":
                            if let reason = event.delta?.stop_reason { stopReason = reason }
                        default:
                            break
                        }
                    }

                    // Reassemble the assistant turn's content blocks in order.
                    var assistantBlocks: [ProviderMessage.Block] = []
                    for idx in blockTypes.keys.sorted() {
                        switch blockTypes[idx] {
                        case "text":
                            assistantBlocks.append(.text(textBlocks[idx] ?? ""))
                        case "tool_use":
                            assistantBlocks.append(.toolUse(
                                id: toolIDs[idx] ?? "",
                                name: toolNames[idx] ?? "",
                                inputJSON: toolJSON[idx] ?? "{}"
                            ))
                        default:
                            break
                        }
                    }

                    continuation.yield(.turnEnded(
                        needsToolResults: stopReason == "tool_use",
                        assistantBlocks: assistantBlocks
                    ))
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

    // MARK: - Request encoding

    private func encodeBody(history: [ProviderMessage], tools: [AgentTool]) throws -> Data {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "stream": true,
            "messages": history.map(encodeMessage)
        ]
        if !tools.isEmpty {
            body["tools"] = try tools.map(encodeTool)
        }
        return try JSONSerialization.data(withJSONObject: body)
    }

    private func encodeMessage(_ message: ProviderMessage) -> [String: Any] {
        let content: [[String: Any]] = message.blocks.map { block in
            switch block {
            case let .text(text):
                return ["type": "text", "text": text]
            case let .toolUse(id, name, inputJSON):
                let input = (try? JSONSerialization.jsonObject(
                    with: Data(inputJSON.utf8))) ?? [:]
                return ["type": "tool_use", "id": id, "name": name, "input": input]
            case let .toolResult(toolUseID, content):
                return ["type": "tool_result", "tool_use_id": toolUseID, "content": content]
            }
        }
        return ["role": message.role.rawValue, "content": content]
    }

    private func encodeTool(_ tool: AgentTool) throws -> [String: Any] {
        let schemaData = try JSONEncoder().encode(tool.inputSchema)
        let schema = try JSONSerialization.jsonObject(with: schemaData)
        return [
            "name": tool.name,
            "description": tool.description,
            "input_schema": schema
        ]
    }
}

/// Decodable mirror of the streaming event shapes we care about. Unused fields
/// are simply omitted — `JSONDecoder` ignores extras.
private struct SSEEvent: Decodable {
    let type: String
    let index: Int?
    let content_block: ContentBlock?
    let delta: Delta?

    struct ContentBlock: Decodable {
        let type: String
        let id: String?
        let name: String?
    }
    struct Delta: Decodable {
        let type: String?
        let text: String?
        let partial_json: String?
        let stop_reason: String?
    }
}
