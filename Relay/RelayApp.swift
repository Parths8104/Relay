import SwiftUI

/// Relay — a native iOS AI agent.
///
/// Entry point. A single source of truth (`ChatViewModel`) is created here and
/// injected into the view tree. Provider selection (on-device vs. cloud) is
/// resolved at launch so the rest of the app stays provider-agnostic.
@main
struct RelayApp: App {
    @State private var viewModel: ChatViewModel

    init() {
        // Build the tool registry once. Tools are pure, testable units.
        let registry = ToolRegistry(tools: [
            CalculatorTool(),
            DateTimeTool()
        ])

        // Choose a provider. The app is written against the `AgentProvider`
        // protocol, so swapping on-device Apple Intelligence for a cloud model
        // is a one-line change — no view or view-model edits required.
        let provider: AgentProvider = AnthropicProvider(
            keyStore: KeychainStore(service: "ai.relay.apikey")
        )

        let engine = AgentEngine(provider: provider, registry: registry)
        _viewModel = State(initialValue: ChatViewModel(engine: engine))
    }

    var body: some Scene {
        WindowGroup {
            ChatView(viewModel: viewModel)
        }
    }
}
