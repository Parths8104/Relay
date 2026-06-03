import SwiftUI

/// Renders one message. Assistant messages can show inline tool-call cards so
/// the user watches the agent's reasoning unfold step by step — a small but
/// important transparency choice for human-AI interaction.
struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                ForEach(message.toolCalls) { call in
                    ToolCallView(call: call)
                }

                if !message.text.isEmpty || message.isStreaming {
                    Text(message.text.isEmpty && message.isStreaming ? "…" : message.text)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(bubbleColor, in: .rect(cornerRadius: 18))
                        .foregroundStyle(message.role == .user ? .white : .primary)
                }
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var bubbleColor: Color {
        message.role == .user ? .accentColor : Color(.secondarySystemBackground)
    }
}

/// A compact card showing a tool invocation and its result.
struct ToolCallView: View {
    let call: ToolCallRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: call.result == nil ? "wrench.and.screwdriver" : "checkmark.seal")
                    .font(.caption)
                Text(call.name)
                    .font(.caption.weight(.semibold))
                if call.result == nil {
                    ProgressView().controlSize(.mini)
                }
            }
            .foregroundStyle(.secondary)

            if let result = call.result {
                Text(result)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemBackground), in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        )
    }
}
