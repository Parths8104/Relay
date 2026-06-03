import SwiftUI

/// Settings: enter the API key (stored in Keychain) and read a short note about
/// the on-device alternative. Kept intentionally minimal.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var saved = false

    private let keyStore = KeychainStore(service: "ai.relay.apikey")

    var body: some View {
        NavigationStack {
            Form {
                Section("Anthropic API Key") {
                    SecureField("sk-ant-…", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Save") {
                        keyStore.save(apiKey.trimmingCharacters(in: .whitespaces))
                        saved = true
                    }
                    if saved {
                        Label("Saved to Keychain", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.footnote)
                    }
                }

                Section("On-device model") {
                    Text("""
                        Relay is built against a provider protocol. To run fully \
                        on-device with Apple Intelligence, build with the \
                        FoundationModels SDK and switch the provider in RelayApp.swift. \
                        No key required in that mode.
                        """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { apiKey = keyStore.read() ?? "" }
        }
    }
}
