import SwiftUI

/// The bottom input bar. Send turns into a Stop button while a response streams,
/// giving the user an immediate way to interrupt the agent.
struct ComposerView: View {
    let isResponding: Bool
    let onSend: (String) -> Void
    let onStop: () -> Void

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($focused)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground), in: .capsule)
                .onSubmit(submit)

            Button(action: primaryAction) {
                Image(systemName: isResponding ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(isResponding ? .red : .accentColor)
            }
            .disabled(!isResponding && draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func primaryAction() {
        if isResponding { onStop() } else { submit() }
    }

    private func submit() {
        let text = draft
        draft = ""
        onSend(text)
    }
}
