# Architecture & design decisions

This doc explains *why* Relay is built the way it is — the kind of reasoning a
reviewer or interviewer will probe.

## The one seam that matters: `AgentProvider`

Everything above the model — the agent loop, the view model, the UI — talks to a
single protocol:

```swift
protocol AgentProvider {
    func streamTurn(history: [ProviderMessage],
                    tools: [AgentTool]) -> AsyncThrowingStream<TurnEvent, Error>
}
```

A provider runs exactly **one** model turn and streams events. It does *not*
decide whether to loop, run tools, or render anything. That isolation is what
lets the on-device Apple model and a cloud API swap freely, and it's what keeps
vendor JSON out of the UI. If Apple's on-device API changes, only one file moves.

## Who owns the loop: `AgentEngine`

The agent loop is deliberately *not* in the provider. The engine:

1. asks the provider to stream a turn,
2. collects any tool-use requests,
3. runs the tools (in parallel via a task group),
4. appends results to history and starts another turn,
5. stops when the model returns a final answer or a step cap is hit.

Keeping the loop separate from the provider means the looping/tool policy is
testable and reusable across providers. The step cap (`maxSteps`) is a
reliability guard — an agent that can't terminate is a production incident.

## Streaming: the hard part

Text and tool-call arguments both arrive incrementally over SSE. Text deltas can
be shown immediately, but **tool arguments arrive as fragments of JSON spread
across many events** and are useless until reassembled. `AnthropicProvider`
accumulates `partial_json` per content-block index and only emits a `toolUse`
event at `content_block_stop`, when the JSON is complete and parseable. Getting
this wrong is the most common bug in hand-rolled streaming agents.

## State: `@Observable` + `@MainActor`

`ChatViewModel` is `@MainActor`, so every UI mutation is main-thread-safe by
construction — no manual `DispatchQueue.main` hops. `@Observable` (iOS 17+) gives
SwiftUI property-level change tracking, so streaming a token into one message
doesn't invalidate the whole list.

## Transparency as a product choice

Tool calls render **inline** in the transcript as they happen. For a "human-AI
interaction" product this is intentional: the user sees the agent reach for the
calculator and what it got back, instead of trusting an opaque number. Trust in
AI features comes from showing the work.

## Trade-offs I'd revisit for production

- **History translation is lossy.** The view model currently flattens each
  message to a single text block when rebuilding provider history; a production
  version would preserve tool-use/tool-result blocks across turns so the model
  keeps full context on long multi-tool conversations.
- **No persistence.** Conversations live in memory. SwiftData would be the
  native choice for on-device history.
- **Single conversation.** The models support multiple (`Conversation` is the
  obvious next type); the UI is single-thread for focus.
- **Tool-use IDs vs. UI IDs.** The view model maps tool results to cards
  heuristically; threading the provider's `tool_use` id through to the UI record
  end-to-end would make this exact rather than best-effort.

These are listed on purpose — knowing where the bodies are buried is part of
owning the work.
