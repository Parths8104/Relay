import SwiftUI

/// The main screen: a scrolling transcript with a composer pinned to the bottom.
/// Auto-scrolls as tokens stream in, mirroring a native Messages-style feel.
struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                transcript
                Divider()
                ComposerView(
                    isResponding: viewModel.isResponding,
                    onSend: viewModel.send,
                    onStop: viewModel.cancel
                )
            }
            .navigationTitle("Relay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .alert(
                "Something went wrong",
                isPresented: .constant(viewModel.errorMessage != nil)
            ) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if viewModel.messages.isEmpty {
                        EmptyStateView()
                            .padding(.top, 80)
                    }
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.last?.text) {
                if let lastID = viewModel.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Ask anything")
                .font(.title2.weight(.semibold))
            Text("Try: \"What's 18% of 240, and what's today's date?\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
