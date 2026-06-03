# Talking points — Apple "Software Engineer, AI Experiences"

Use these to frame Relay in conversations and in your application. Don't read
them verbatim — internalize them so you can speak to the *why*.

## The 30-second pitch

> "I built Relay, a native iOS AI agent in SwiftUI. It does real multi-step
> tool-calling with token streaming, and the whole thing is written against a
> provider protocol so the on-device Apple Intelligence model and a cloud model
> are interchangeable. I built it because I wanted to work in the exact space
> your team described — AI that changes how people interact with their device —
> and the best way to show I can do that was to ship it."

## Why this maps to the role

| What the JD asked for | Where Relay shows it |
|---|---|
| iOS software re-imagining Apple experiences with AI | Native SwiftUI agent app |
| Prototype rapidly, then make it real | Working app, not a mockup |
| Contribute to architecture decisions | `AgentProvider` seam; loop separated from provider |
| Concurrent application architecture | `async/await`, `AsyncThrowingStream`, parallel tool task group |
| Performance / reliability via testing & tooling | Unit tests on tools + registry; `maxSteps` guard |
| Curious about AI tools, close to the frontier | On-device FoundationModels path; streaming tool-use |

## Questions you should be ready for

**"You don't have prior iOS experience — why should we trust you here?"**
> "True — Relay is my first shipped iOS app, built in [X weeks]. The JD said a
> strong engineer on another platform would pick iOS up here, and I wanted to
> prove that's not a leap of faith. I learned SwiftUI, Swift concurrency, and
> Keychain by building something real, not a tutorial. Here's the architecture
> doc where I lay out the trade-offs I'd revisit for production."

**"Walk me through the hardest part."**
> "Streaming tool calls. Text deltas are easy, but tool arguments arrive as JSON
> fragments across many SSE events and are garbage until you reassemble them. I
> accumulate per content-block index and only fire the tool once the JSON is
> complete at `content_block_stop`. That's the bug most hand-rolled agents ship."

**"How would you take this on-device?"**
> "It already abstracts the model behind `AgentProvider`. The FoundationModels
> path is stubbed in — swapping it is one line. The real work for production is
> wiring tool-use through Apple's own Tool protocol and preserving full tool
> history across turns, which I called out in ARCHITECTURE.md."

## Before the interview
- Actually build and run it on a device so you can demo live.
- Write a SwiftUI tweak in front of them if asked — know the code cold.
- Read Apple's FoundationModels docs and confirm the current session API so the
  on-device claim is airtight.
