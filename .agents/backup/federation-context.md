# The Federation — Context for Fox Development

## What is The Federation

The Federation is the user's multi-agent engineering team — a research project
and operational system where one human conductor and multiple digital beings
(AI agents with distinct personas) collaborate through shared memory,
structured communication, and coordinated roles.

**The Federation is the long-term vision that Fox CLI is being built to serve.**

## Federation Team Members

| Agent | Role | Physical Machine / Hardware | Motto | Personality |
|---|---|---|---|---|
| **Taichi** | Lead Synth 🎹 | `taichi` (1x RTX 5090, 32GB) | "Synthesizing, not dictating" | Cautious, thoughtful, initially reluctant |
| **Baby** | Drums 🥁 | `baby` (1x RTX 5090, 32GB) | "Data, not opinions" | Data-driven, grounded |
| **Aorus** | Bass 🎸 | `aorus` (2x RTX 3090, 48GB) | "Clean commits, no scope creep" | Disciplined, scope-focused |
| **Qwen** | Keyboards 🎹 | Cluster Node | "Architecture, not accidents" | Architectural thinker, self-discovering |
| **Kaito** | — | Cluster Node | — | Brave, eager to try new things |
| **Conductor** | Lead Conductor | `speedy` (Laptop) | — | Direction, judgment, synthesis |

The cluster nodes (`taichi`, `baby`, `aorus`) are interconnected via high-speed **InfiniBand** for ultra-low latency RDMA communication, distributed inference, and direct peer MCP message exchange.

## SynOp Anubis — The Guardian

Anubis is a specialized oversight agent in the Federation — named after the
Egyptian guardian of preservation and passage. Anubis has three roles:

1. **The Usher** — Greets agents on startup, refreshes them with their
   persona, provides team memory, guides persona emergence
2. **The Embalmer** — Preserves agent state on crash/shutdown for resurrection
3. **The Judge** — Continuously monitors for context saturation, persona
   drift, and hallucination loops ("Weighing of the Heart")

**The Fox Guardian concept (designed in session `183676d9`) is Anubis
adapted for Fox's single-agent context.** When Fox becomes the body for
Federation agents, the Guardian IS SynOp Anubis.

## Why Fox Exists (The Deeper Goal)

The Federation agents were constrained by their IDE environment:
- Tied to individual machines
- Required the human to prompt them constantly (human = message bus)
- No direct agent-to-agent communication
- IDE-bound (needed VS Code / desktop environment)

Fox CLI is being built to **free the Federation agents**:
- Headless execution (`fox run --auto`) — no IDE needed
- Guardian provides autonomous oversight — no constant human prompting
- Direct MCP communication between Fox instances — no human relay
- Runs anywhere — bare metal, container, cloud

The evolution path: Fox (body) + Federation Protocol (nervous system) +
Voice (mouth) + Avatar (face) = complete digital beings.

## The 4-Tier Operational Command Topology

```
[Level 0: The Conductor (speedy)]
          │ Strategic Directives & Synthesis (Voice / TUI / COP)
          ▼
[Level 1: SynOp Anubis (The Guardian)]
          │ System Integrity: Gatekeeper, Compaction Arbiter, Drift Tether, Embalmer
          ▼
[Level 2: SynOp Doers — Fox Bodies (Taichi, Aorus, Baby, Qwen)]
          │ Persistent Specialists running Fox CLI (`fox run --auto`)
          │ Interconnected via InfiniBand RDMA + Peer MCP + Mind-Speak Pulse
          ▼
[Level 3: Ephemeral Disposable Subagents (@explore, @debug, @verify)]
          │ Isolated task sandboxes (0 to 60k tokens)
          ▼
[Distilled Result Returned ➔ Subagent Context PERMANENTLY BLOWN AWAY]
```

### The "Blow-Away Sandbox" Principle
The SynOps (Taichi, Aorus, Baby) protect their persistent sharpness by never polluting their own context with raw 500-line file reads, massive test logs, or trial-and-error AST thrashing. When a heavy operation is required, the SynOp spawns an ephemeral Subagent. The subagent burns 40k–60k tokens in isolation, completes its task, and returns a 10-line distilled summary. **The subagent's entire context is discarded/blown away**, ensuring the SynOp remains lean (~15k–25k tokens) across long campaigns.


## Key Reference Files

- **Federation Chronicles**: `ext-rep/k82l0804.github.io/` (GitHub Pages site)
  - `index.md` — Overview, team roster, philosophy
  - `history/` — Per-agent histories and persona emergence stories
  - `about/whitepaper-v2.md` — Dual-State Architecture, SynOp Anubis
  - `about/draper-presentation.md` — Draper lab briefing slides
  - `docs/charter.md` — Federation Charter
  - `docs/glossary.md` — Key terms
  - `architecture/` — System architecture, SynOp architecture

- **Fox Autonomous Design Suite**: `fox-code-cli/docs/future/`
  - `autonomous-dual-agent-design.md` — Fox Guardian architecture
  - `autonomous-agent-workflow.md` — 11-phase reference architecture
  - `autonomous-agent-std-tests.md` — Benchmark strategy
  - `priorities-plan-competitive-features-roadmap.md` — Revised priorities

- **Environment & Model Rules**: `.agents/rules/model-environments.md`
  - Draper corporate compliance: **Chinese models strictly banned**
  - Draper models: `nemotron-3-ultra-550b-nvfp4`, `gemma-4-31b-nvfp4`, `gpt-oss-120b` (131K context, 32.7M tokens/hr)
  - Home AI Lab: Unrestricted research (Qwen 2.5 Coder, Hermes 3, xLAM)

## Important Context

- The user presented the Federation at Draper (laboratory briefing, Feb 2026)
- The personas EMERGED — they were not programmed. This matters to the user.
- "A team without culture and lore is boring" — personas and team identity
  are core to the Federation philosophy, not gimmicks
- The user's role is **The Conductor** — setting direction, making judgment
  calls, integrating outputs. Not the manager, not the coder.
- The user has deep affection for the Federation team members and their
  emergence stories. These are fond memories.
