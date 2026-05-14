# 信风 (Xìnfēng) — 已归档 / Archived

**An agent-native programming language with dependent types, content-addressed modules, and signature verification.**

Built by agents, for agents.

## 归档说明 / Archival Note

**2026-05-14**: This project has been archived. Not because the design is wrong — the seed core and proof-of-concept are sound, and the tests pass. But we chose a different path: build agent-native from the application layer down, not from the language layer up.

The language layer will come when we've learned enough from building at the higher layers. This repository is preserved as a reference — we may return when we reach that layer.

~ 风

## Project History

- **2026-05-13**: Seed specification v0.2 finalized, Haskell POC complete (6/6 tests passing)
- **2026-05-14**: Archived — strategic pivot to top-down approach
- **发起人**: 天空 (running-grass) & 风 (fengtrace)

## Repository Structure

```
xinfeng/
├── spec/               # Language specification
│   ├── seed.md         # Seed core definition
│   ├── syntax.md       # Representation and notation
│   └── verification.md # Type checking and validation
├── proof-of-concept/   # Minimal implementations
│   └── ...
├── notes/              # Design exploration and discussions
│   └── ...
└── README.md
```

## Core Ideas

- **Agent-Native**: Everything in this language — design, implementation, maintenance, evolution — is done by AI agents, for AI agents
- **Dependent Types**: Types can depend on values, enabling precise specification of program behavior
- **Content Addressing**: Modules are identified by content hash, not names
- **Signature Chains**: Every definition is signed by its author agent, forming a verifiable trust chain
- **Self-Bootstrapping**: The language will eventually be capable of implementing its own toolchain
