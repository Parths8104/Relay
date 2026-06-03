#!/usr/bin/env bash
#
# setup_git.sh — initialize Relay's git history in logical, incremental commits.
#
# HOW TO USE THIS HONESTLY:
#   Don't just run the whole thing in 10 seconds. Open each group of files,
#   read it, make sure you understand and (ideally) tweak it, THEN run that
#   commit. Ideally space the commits out as you actually work through the code.
#   The point is a history that reflects real understanding — not a fake one.
#
#   You can run this top-to-bottom, or copy commits out one at a time as you go.
#
# Run from inside the Relay/ project root.

set -e

# ---- 0. Init ----
git init
git branch -M main

# ---- 1. Project scaffolding ----
git add .gitignore
git commit -m "chore: project scaffolding and gitignore

Exclude build artifacts, Xcode user state, and any secrets files.
API keys live in the Keychain and must never be committed."

# ---- 2. Core models ----
git add Relay/Models/ChatMessage.swift Relay/Models/AgentTool.swift
git commit -m "feat: add core models — ChatMessage and AgentTool

UI-facing transcript model kept separate from any provider wire format.
AgentTool protocol + minimal JSONSchema/JSONValue types so tools can read
heterogeneous arguments without resorting to Any."

# ---- 3. Provider seam ----
git add Relay/Services/AgentProvider.swift
git commit -m "feat: define AgentProvider protocol and shared event types

The single seam between the app and the model. Provider runs one turn and
streams TurnEvents; it does not own the agent loop or tool execution. This
is what lets on-device and cloud models stay interchangeable."

# ---- 4. Secure storage ----
git add Relay/Services/KeychainStore.swift
git commit -m "feat: add Keychain-backed credential storage

Store the API key in the iOS Keychain rather than UserDefaults so it never
touches plaintext preferences or logs."

# ---- 5. Tools + registry ----
git add Relay/Tools/CalculatorTool.swift Relay/Tools/DateTimeTool.swift Relay/Services/ToolRegistry.swift
git commit -m "feat: add calculator + datetime tools and the tool registry

Deterministic tools the model delegates to instead of hallucinating.
Registry dispatches by name, decodes JSON args, and returns tool errors as
text so the agent can read them and recover on the next turn."

# ---- 6. Streaming cloud provider ----
git add Relay/Services/AnthropicProvider.swift
git commit -m "feat: implement Anthropic provider with streaming SSE + tool use

Parse Server-Sent Events live: text deltas surface immediately, while
tool-call arguments arrive as JSON fragments across events and are only
emitted once reassembled at content_block_stop."

# ---- 7. On-device provider ----
git add Relay/Services/FoundationModelsProvider.swift
git commit -m "feat: add on-device FoundationModels provider (gated)

Apple Intelligence path behind #if canImport(FoundationModels) so the app
still builds where the framework is absent. One-line swap in RelayApp."

# ---- 8. Agent loop ----
git add Relay/Services/AgentEngine.swift
git commit -m "feat: add AgentEngine — the multi-step tool-calling loop

Plan -> act -> observe -> repeat. Runs tools in parallel via a task group,
feeds results back into history, and stops on a final answer or step cap.
The maxSteps guard prevents runaway loops."

# ---- 9. View model ----
git add Relay/ViewModels/ChatViewModel.swift
git commit -m "feat: add ChatViewModel (@Observable, @MainActor)

Owns the transcript and consumes the engine's event stream. MainActor
isolation makes every UI mutation main-thread-safe by construction."

# ---- 10. Views ----
git add Relay/Views/
git commit -m "feat: build SwiftUI chat UI with inline tool-call cards

Transcript with auto-scroll, streaming bubbles, a send/stop composer, and
a settings sheet for the API key. Tool calls render inline so the user
watches the agent reason step by step."

# ---- 11. App entry ----
git add Relay/RelayApp.swift
git commit -m "feat: wire app entry point — provider, tools, engine

Single source of truth created at launch and injected into the view tree."

# ---- 12. Tests ----
git add RelayTests/
git commit -m "test: cover tools and registry routing

Focus tests on the deterministic seams most likely to break silently and
easiest to verify without a live model."

# ---- 13. Docs ----
git add README.md ARCHITECTURE.md INTERVIEW_NOTES.md
git commit -m "docs: add README, architecture notes, and design trade-offs

Setup + demo script, the reasoning behind the provider seam and streaming
design, and an honest list of what I'd revisit for production."

echo ""
echo "Done. Review with:  git log --oneline"
echo "Then add your remote and push:"
echo "  git remote add origin https://github.com/<you>/relay.git"
echo "  git push -u origin main"
