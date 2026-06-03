# Relay — a native iOS AI agent

A small, native SwiftUI app that turns natural language into multi-step actions.
You type a request; Relay streams a response token-by-token, and when a question
needs an exact answer it **calls a tool** (calculator, clock, …), shows that work
inline, then continues reasoning until it can reply.

Built to demonstrate the intersection that the Apple *AI Experiences* team works
in: **on-device-first AI, expressed through a polished native interface, with
production-grade engineering underneath.**

---

## What it shows

- **Agentic, multi-step reasoning** — a real tool-calling loop (plan → act →
  observe → continue), not a single prompt/response.
- **Streaming UX** — Server-Sent Events parsed live; text appears as it's
  generated, tool calls render inline as they happen.
- **Swift concurrency** — `async/await`, `AsyncThrowingStream`, and a
  `withThrowingTaskGroup` that runs multiple tools in parallel.
- **Clean architecture** — the entire app is written against an `AgentProvider`
  protocol, so the **on-device Apple Intelligence model** and a **cloud model**
  are interchangeable (one line in `RelayApp.swift`).
- **Apple-platform fundamentals** — `@Observable` + `@MainActor` state, Keychain
  credential storage, native SwiftUI throughout, unit tests on the core logic.

---

## Run it

1. Open Xcode 16+ and create a new **iOS App** named `Relay` (SwiftUI, Swift).
2. Delete the generated `ContentView.swift`, then drag every file from the
   `Relay/` folder here into the project, preserving the group structure
   (Models, Services, Tools, ViewModels, Views).
3. Add the `RelayTests/` file to the test target.
4. Build and run on the simulator or a device.
5. Tap the gear icon and paste an Anthropic API key (stored in the Keychain).
6. Try: **"What's 18% of 240, and what's today's date?"** — watch it call the
   calculator and clock tools, then answer.

> **On-device mode:** the project includes a `FoundationModelsProvider` gated
> behind `#if canImport(FoundationModels)`. Build with the SDK that ships Apple's
> on-device model, run on an Apple Intelligence-capable device, and switch the
> provider line in `RelayApp.swift` — no API key needed. (Verify the
> FoundationModels session API against your installed SDK; it's a young
> framework.)

---

## Project layout

```
Relay/
├── RelayApp.swift            App entry; wires provider + tools + engine
├── Models/
│   ├── ChatMessage.swift     UI-facing transcript model
│   └── AgentTool.swift       Tool protocol + JSON schema/value types
├── Services/
│   ├── AgentProvider.swift   The vendor-neutral seam (protocol + events)
│   ├── AgentEngine.swift     The agent loop (plan → act → observe → repeat)
│   ├── AnthropicProvider.swift   Cloud path: streaming SSE + tool use
│   ├── FoundationModelsProvider.swift  On-device path (Apple Intelligence)
│   ├── ToolRegistry.swift    Dispatch + argument decoding + error handling
│   └── KeychainStore.swift   Secure API-key storage
├── Tools/
│   ├── CalculatorTool.swift
│   └── DateTimeTool.swift
├── ViewModels/
│   └── ChatViewModel.swift   @Observable @MainActor state, stream consumer
└── Views/
    ├── ChatView.swift        Transcript + auto-scroll
    ├── MessageBubbleView.swift   Bubbles + inline tool-call cards
    ├── ComposerView.swift    Input bar with send/stop
    └── SettingsView.swift    API key entry
```

See `ARCHITECTURE.md` for the design decisions and trade-offs.

---

## Adding a new capability

The whole point of the design: a new agent skill is one new file.

```swift
struct WeatherTool: AgentTool {
    let name = "get_weather"
    let description = "Get the current weather for a city."
    var inputSchema: JSONSchema {
        JSONSchema(properties: ["city": .init(type: "string",
                   description: "City name")], required: ["city"])
    }
    func run(arguments: [String: JSONValue]) async throws -> String {
        // call a weather API, return a string the model reads next turn
    }
}
```

Register it in `RelayApp.swift` and the model can use it immediately. No engine,
view, or view-model changes.
